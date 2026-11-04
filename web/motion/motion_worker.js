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

// Điểm mốc khuôn mặt gửi sang Dart (x, y, z): 2 khoé mắt ngoài, môi trong trên/dưới, đỉnh trán, cằm
const FACE_POINTS = [33, 263, 13, 14, 10, 152];
const FACE_DATA_LENGTH = FACE_POINTS.length * 3 + 2; // điểm + tâm mặt

let fileset = null;
const landmarkers = { hand: null, face: null };
const loading = { hand: null, face: null };
// Bộ xử lý ưu tiên, do motion_bridge.js gửi sang (GPU mặc định, lỗi thì tự về CPU)
let preferredDelegate = 'GPU';
// Kết quả kiểm tra GPU đã lưu từ lần trước (true / false / null = chưa biết) & bài kiểm tra đang chạy
let knownGpuOk = null;
let gpuCheck = null;

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
  // Không bật outputFacialTransformationMatrixes: khi nhận nhầm 1 "khuôn mặt" méo (VD: camera nhìn trần nhà)
  // bước tính ma trận 3D báo lỗi "Design matrix norm is too small" và làm hỏng hẳn graph MediaPipe.
  // Góc ngẩng/quay mặt được tính từ toạ độ z của điểm mốc ở phía Dart.
  return FaceLandmarker.createFromOptions(fileset, {
    baseOptions,
    runningMode: 'VIDEO',
    numFaces: 1,
  });
}

/**
 * GPU của một số máy cho kết quả sai (đo trên Adreno 830 + Chrome 156, cả MediaPipe 0.10.x lẫn 1.x, cả luồng
 * chính lẫn worker): "thấy" mặt trên ảnh xám trơn, rồi trả NaN làm hỏng hẳn graph => không nhận diện được gì.
 * Kiểm tra 1 lần bằng vài khung ảnh xám: GPU đúng thì giữ luôn model mặt vừa tạo, sai thì cả phiên dùng CPU.
 */
function checkGpu() {
  if (knownGpuOk !== null) gpuCheck ??= Promise.resolve(knownGpuOk);
  gpuCheck ??= (async () => {
    let lm = null;
    let ok = true;
    try {
      lm = await createLandmarker('face', 'GPU');
      const canvas = new OffscreenCanvas(320, 240);
      const g = canvas.getContext('2d');
      for (let i = 0; i < 5; i++) {
        const v = 110 + i * 15;
        g.fillStyle = `rgb(${v},${v},${v})`;
        g.fillRect(0, 0, canvas.width, canvas.height);
        const bitmap = canvas.transferToImageBitmap();
        try {
          if (lm.detectForVideo(bitmap, i * 33 + 1).faceLandmarks.length) ok = false;
        } catch (_) {
          ok = false;
        } finally {
          bitmap.close();
        }
      }
    } catch (e) {
      console.warn('[motion] GPU check failed', e);
      ok = false;
    }
    if (ok) {
      landmarkers.face = lm; // dùng lại, khỏi nạp lần 2
      self.postMessage({ type: 'delegate', kind: 'face', delegate: 'GPU' });
    } else {
      try {
        lm?.close();
      } catch (_) {}
    }
    self.postMessage({ type: 'gpu-check', ok });
    return ok;
  })();
  return gpuCheck.then((ok) => {
    if (!ok) preferredDelegate = 'CPU';
    return ok;
  });
}

/** Nạp model khi cần (theo bộ xử lý ưu tiên, GPU lỗi thì về CPU); chỉ nạp 1 lần */
function ensureLandmarker(kind) {
  if (landmarkers[kind]) return Promise.resolve(landmarkers[kind]);
  loading[kind] ??= (async () => {
    if (preferredDelegate === 'GPU') await checkGpu();
    if (landmarkers[kind]) return landmarkers[kind]; // model mặt GPU giữ lại từ bài kiểm tra
    let delegate = preferredDelegate;
    let lm;
    try {
      lm = await createLandmarker(kind, delegate);
    } catch (e) {
      if (delegate === 'CPU') throw e;
      console.warn(`[motion] ${kind} GPU delegate failed, using CPU`, e);
      delegate = 'CPU';
      lm = await createLandmarker(kind, delegate);
    }
    self.postMessage({ type: 'delegate', kind, delegate });
    return (landmarkers[kind] = lm);
  })().catch((e) => {
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

/** Mặt: [6 điểm mốc (x,y,z), tâm khung bao (x,y)] */
function packFace(result) {
  const face = result.faceLandmarks?.[0];
  if (!face) return { data: null, count: 0 };
  const data = new Float32Array(FACE_DATA_LENGTH);
  FACE_POINTS.forEach((idx, k) => {
    data[k * 3] = face[idx].x;
    data[k * 3 + 1] = face[idx].y;
    data[k * 3 + 2] = face[idx].z;
  });
  let minX = 1, minY = 1, maxX = 0, maxY = 0;
  for (const p of face) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  const c = FACE_POINTS.length * 3;
  data[c] = (minX + maxX) / 2;
  data[c + 1] = (minY + maxY) / 2;
  return { data, count: 1 };
}

self.onmessage = (event) => {
  const msg = event.data;
  if (msg.type === 'prepare') {
    preferredDelegate = msg.delegate ?? preferredDelegate;
    if (typeof msg.gpuOk === 'boolean') knownGpuOk = msg.gpuOk;
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
    // Graph MediaPipe lỗi 1 lần là hỏng luôn; tạo lại model trong cùng worker cũng không được (ngữ cảnh
    // GPU đã hỏng: model mới chạy nhưng luôn trả rỗng) => báo luồng chính dựng worker mới hoàn toàn
    console.error('[motion] detect error, worker needs restart', e);
    self.postMessage({ type: 'fatal', kind: mode, message: `detect: ${e}` });
  } finally {
    bitmap.close();
  }
  const transfer = packed.data ? [packed.data.buffer] : [];
  self.postMessage({ type: 'result', mode, data: packed.data, count: packed.count, width, height, cost }, transfer);
};
