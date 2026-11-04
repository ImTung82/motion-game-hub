// Web Worker chạy MediaPipe Tasks Vision trên luồng riêng để không tranh luồng chính với Flutter
// (chạy chung luồng: mỗi lần nhận diện ~20ms x 25 lần/giây => game chỉ còn ~36 FPS).
// motion_bridge.js gửi từng khung hình (ImageBitmap) sang, worker trả kết quả dạng Float32Array.
importScripts('mediapipe/vision_bundle_iife.js'); // định nghĩa self.Vision
const { FilesetResolver, HandLandmarker, FaceLandmarker } = self.Vision;

const base = new URL('.', self.location.href);
const WASM_PATH = new URL('mediapipe/wasm', base).href;
const MODEL_URLS = {
  hand: new URL('models/hand_landmarker.task', base).href,
  face: new URL('models/face_landmarker.task', base).href,
};

// Điểm mốc khuôn mặt gửi sang Dart: 2 khoé mắt ngoài, môi trong trên/dưới, đỉnh trán, cằm
const FACE_POINTS = [33, 263, 13, 14, 10, 152];
const FACE_DATA_LENGTH = FACE_POINTS.length * 2 + 2 + 16; // điểm + tâm mặt + ma trận 4x4

let fileset = null;
const landmarkers = { hand: null, face: null };
const loading = { hand: null, face: null };
// Bộ xử lý ưu tiên, do motion_bridge.js gửi sang (GPU mặc định, lỗi thì tự về CPU)
let preferredDelegate = 'GPU';

async function createLandmarker(kind, delegate) {
  fileset ??= await FilesetResolver.forVisionTasks(WASM_PATH);
  const baseOptions = { modelAssetPath: MODEL_URLS[kind], delegate };
  if (kind === 'hand') {
    return HandLandmarker.createFromOptions(fileset, {
      baseOptions,
      runningMode: 'VIDEO',
      numHands: 2,
      minHandDetectionConfidence: 0.5,
    });
  }
  return FaceLandmarker.createFromOptions(fileset, {
    baseOptions,
    runningMode: 'VIDEO',
    numFaces: 1,
    outputFacialTransformationMatrixes: true,
  });
}

/** Nạp model khi cần (theo bộ xử lý ưu tiên, GPU lỗi thì về CPU); chỉ nạp 1 lần */
function ensureLandmarker(kind) {
  if (landmarkers[kind]) return Promise.resolve(landmarkers[kind]);
  const delegate = preferredDelegate;
  loading[kind] ??= createLandmarker(kind, delegate)
    .then((lm) => {
      self.postMessage({ type: 'delegate', kind, delegate });
      return lm;
    })
    .catch((e) => {
      if (delegate === 'CPU') throw e;
      console.warn(`[motion] ${kind} GPU delegate failed, using CPU`, e);
      self.postMessage({ type: 'delegate', kind, delegate: 'CPU' });
      return createLandmarker(kind, 'CPU');
    })
    .then((lm) => (landmarkers[kind] = lm))
    .catch((e) => {
      console.error(`[motion] cannot load ${kind} model`, e);
      self.postMessage({ type: 'error', kind, message: String(e) });
      loading[kind] = null; // cho phép thử lại lần sau
      throw e;
    });
  return loading[kind];
}

/** Tay: mảng phẳng [x0,y0,...,x20,y20] cho từng tay (toạ độ chuẩn hoá theo khung hình gốc) */
function packHands(result) {
  const hands = result.landmarks ?? [];
  const data = new Float32Array(hands.length * 42);
  hands.forEach((hand, i) => {
    for (let j = 0; j < 21; j++) {
      data[i * 42 + j * 2] = hand[j].x;
      data[i * 42 + j * 2 + 1] = hand[j].y;
    }
  });
  return { data, count: hands.length };
}

/** Mặt: [6 điểm mốc (x,y), tâm khung bao (x,y), ma trận biến đổi 4x4 (NaN nếu không có)] */
function packFace(result) {
  const face = result.faceLandmarks?.[0];
  if (!face) return { data: null, count: 0 };
  const data = new Float32Array(FACE_DATA_LENGTH);
  FACE_POINTS.forEach((idx, k) => {
    data[k * 2] = face[idx].x;
    data[k * 2 + 1] = face[idx].y;
  });
  let minX = 1, minY = 1, maxX = 0, maxY = 0;
  for (const p of face) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  const c = FACE_POINTS.length * 2;
  data[c] = (minX + maxX) / 2;
  data[c + 1] = (minY + maxY) / 2;
  const matrix = result.facialTransformationMatrixes?.[0]?.data;
  for (let i = 0; i < 16; i++) data[c + 2 + i] = matrix ? matrix[i] : NaN;
  return { data, count: 1 };
}

self.onmessage = (event) => {
  const msg = event.data;
  if (msg.type === 'prepare') {
    preferredDelegate = msg.delegate ?? preferredDelegate;
    ensureLandmarker(msg.mode).catch(() => {});
    return;
  }
  if (msg.type !== 'detect') return;

  const { mode, bitmap, timestamp } = msg;
  const width = bitmap.width;
  const height = bitmap.height;
  const landmarker = landmarkers[mode];
  if (!landmarker) {
    bitmap.close();
    ensureLandmarker(mode).catch(() => {});
    self.postMessage({ type: 'skip' }); // model đang nạp
    return;
  }

  let packed = { data: null, count: 0 };
  let cost = 0;
  try {
    const t0 = performance.now();
    const result = landmarker.detectForVideo(bitmap, timestamp);
    cost = performance.now() - t0;
    packed = mode === 'hand' ? packHands(result) : packFace(result);
  } catch (e) {
    console.error('[motion] detect error', e);
  } finally {
    bitmap.close();
  }
  const transfer = packed.data ? [packed.data.buffer] : [];
  self.postMessage({ type: 'result', mode, data: packed.data, count: packed.count, width, height, cost }, transfer);
};
