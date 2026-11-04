// Cầu nối camera + MediaPipe Tasks Vision cho bản Web.
// Flutter (lib/motion/backend/motion_backend_web.dart) gọi window.motionBridge qua dart:js_interop.
import { FilesetResolver, HandLandmarker, FaceLandmarker } from './mediapipe/vision_bundle_esm.js';

const base = new URL('.', import.meta.url);
const WASM_PATH = new URL('mediapipe/wasm', base).href;
const MODEL_URLS = {
  hand: new URL('models/hand_landmarker.task', base).href,
  face: new URL('models/face_landmarker.task', base).href,
};

// ~30 FPS; máy chậm (1 lần nhận diện > 40ms) tự hạ xuống ~15 FPS để không ì cả game
const FAST_INTERVAL_MS = 33;
const SLOW_INTERVAL_MS = 66;
const SLOW_DETECT_MS = 40;

// Điểm mốc khuôn mặt gửi sang Dart: 2 khoé mắt ngoài, môi trong trên/dưới, đỉnh trán, cằm
const FACE_POINTS = [33, 263, 13, 14, 10, 152];
const FACE_DATA_LENGTH = FACE_POINTS.length * 2 + 2 + 16; // điểm + tâm mặt + ma trận 4x4

let fileset = null;
const landmarkers = { hand: null, face: null };
const loading = { hand: null, face: null };

let stream = null;
let video = null; // <video> ẩn dùng để nhận diện
const previews = new Set(); // các <video> xem trước đang hiển thị trong Flutter
let mode = 'face';
let running = false;
let lastRun = 0;
let interval = FAST_INTERVAL_MS;

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

/** Nạp model khi cần (GPU trước, lỗi thì CPU); chỉ nạp 1 lần */
function ensureLandmarker(kind) {
  if (landmarkers[kind]) return Promise.resolve(landmarkers[kind]);
  loading[kind] ??= createLandmarker(kind, 'GPU')
    .catch((e) => {
      console.warn(`[motion] ${kind} GPU delegate failed, using CPU`, e);
      return createLandmarker(kind, 'CPU');
    })
    .then((lm) => (landmarkers[kind] = lm))
    .catch((e) => {
      console.error(`[motion] cannot load ${kind} model`, e);
      loading[kind] = null; // cho phép thử lại lần sau
      throw e;
    });
  return loading[kind];
}

function setupVideo(el) {
  el.muted = true;
  el.autoplay = true;
  el.playsInline = true;
  el.setAttribute('playsinline', ''); // Safari iOS
  if (stream) {
    el.srcObject = stream;
    el.play().catch(() => {});
  }
  return el;
}

async function start(options = {}) {
  if (running) return { width: video.videoWidth, height: video.videoHeight };
  mode = options.mode || mode;
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('Camera API not available (page must be served over HTTPS)');
  }

  const source = options.deviceId ? { deviceId: { exact: options.deviceId } } : { facingMode: 'user' };
  stream = await navigator.mediaDevices.getUserMedia({
    audio: false,
    video: { ...source, width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 30, max: 30 } },
  });

  video = setupVideo(document.createElement('video'));
  // Phải nằm trong DOM để trình duyệt (nhất là Safari) giải mã khung hình liên tục
  Object.assign(video.style, {
    position: 'fixed', left: '0', top: '0', width: '1px', height: '1px', opacity: '0', pointerEvents: 'none',
  });
  document.body.appendChild(video);
  await video.play();
  if (!video.videoWidth) {
    await new Promise((resolve) => video.addEventListener('loadedmetadata', resolve, { once: true }));
  }

  for (const el of previews) setupVideo(el);

  // Camera hiện ngay; model nạp nền, có model thì bắt đầu nhận diện
  ensureLandmarker(mode).catch(() => {});
  running = true;
  scheduleNextFrame();
  return { width: video.videoWidth, height: video.videoHeight };
}

function stop() {
  running = false;
  stream?.getTracks().forEach((t) => t.stop());
  stream = null;
  video?.remove();
  video = null;
}

function setMode(newMode) {
  if (newMode === mode) return;
  mode = newMode;
  interval = FAST_INTERVAL_MS;
  ensureLandmarker(mode).catch(() => {});
}

/** <video> xem trước cho HtmlElementView (lật gương như camera trước trên điện thoại) */
function createPreview() {
  const el = document.createElement('video');
  Object.assign(el.style, {
    width: '100%', height: '100%', objectFit: 'fill', transform: 'scaleX(-1)', display: 'block', pointerEvents: 'none',
  });
  // Bỏ các preview đã bị Flutter gỡ khỏi trang
  for (const old of previews) if (!old.isConnected) previews.delete(old);
  previews.add(el);
  return setupVideo(el);
}

async function listCameras() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  return devices.filter((d) => d.kind === 'videoinput').map((d) => ({ deviceId: d.deviceId, label: d.label }));
}

function scheduleNextFrame() {
  if (!running || !video) return;
  if ('requestVideoFrameCallback' in video) {
    video.requestVideoFrameCallback(onFrame);
  } else {
    requestAnimationFrame(onFrame);
  }
}

function onFrame() {
  try {
    detect();
  } catch (e) {
    console.error('[motion] detect error', e);
  }
  scheduleNextFrame();
}

function detect() {
  if (document.hidden || video.readyState < 2) return; // tab ẩn: không tốn CPU/pin
  const now = performance.now();
  if (now - lastRun < interval) return;
  const landmarker = landmarkers[mode];
  if (!landmarker) return; // model đang nạp
  lastRun = now;

  const result = landmarker.detectForVideo(video, now);
  const cost = performance.now() - now;
  interval = cost > SLOW_DETECT_MS ? SLOW_INTERVAL_MS : FAST_INTERVAL_MS;

  if (mode === 'hand') {
    emitHands(result, cost);
  } else {
    emitFace(result, cost);
  }
}

/** Gửi tay: mảng phẳng [x0,y0,...,x20,y20] cho từng tay (toạ độ chuẩn hoá theo khung hình gốc) */
function emitHands(result, cost) {
  const hands = result.landmarks ?? [];
  const data = new Float32Array(hands.length * 42);
  hands.forEach((hand, i) => {
    for (let j = 0; j < 21; j++) {
      data[i * 42 + j * 2] = hand[j].x;
      data[i * 42 + j * 2 + 1] = hand[j].y;
    }
  });
  bridge.onHands?.(data, hands.length, video.videoWidth, video.videoHeight, cost);
}

/** Gửi mặt: [6 điểm mốc (x,y), tâm khung bao (x,y), ma trận biến đổi 4x4 (NaN nếu không có)] */
function emitFace(result, cost) {
  const face = result.faceLandmarks?.[0];
  if (!face) {
    bridge.onFace?.(null, video.videoWidth, video.videoHeight, cost);
    return;
  }
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
  bridge.onFace?.(data, video.videoWidth, video.videoHeight, cost);
}

const bridge = {
  start,
  stop,
  setMode,
  createPreview,
  listCameras,
  onHands: null, // (Float32Array data, int count, width, height, costMs)
  onFace: null, // (Float32Array | null data, width, height, costMs)
};
window.motionBridge = bridge;
