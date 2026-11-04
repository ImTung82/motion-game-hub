// Cầu nối camera + MediaPipe cho bản Web.
// Flutter (lib/motion/backend/motion_backend_web.dart) gọi window.motionBridge qua dart:js_interop.
// Luồng chính chỉ lo camera & gửi khung hình; AI chạy trong motion_worker.js (luồng riêng)
// để Flutter có trọn luồng chính mà vẽ game mượt.

// ~30 FPS; máy chậm (1 lần nhận diện > 40ms) tự hạ xuống ~15 FPS.
// Khung camera 30 FPS cách nhau ~33,3ms và hay lệch vài ms => chừa 8ms dung sai, nếu không sẽ bỏ sót
// gần một nửa số khung (thực tế chỉ còn ~15 FPS).
const FAST_INTERVAL_MS = 33;
const SLOW_INTERVAL_MS = 66;
const SLOW_DETECT_MS = 40;
const FRAME_JITTER_MS = 8;
// Worker không trả lời quá lâu (VD: đang nạp model GPU) thì cho gửi khung mới
const RESULT_TIMEOUT_MS = 1000;
// Bộ xử lý AI: GPU (đo trên điện thoại: ~22ms/lần, game vẫn 60 FPS vì AI chạy trong worker);
// CPU chậm gấp ~3 lần. Dò lỗi trên máy lạ (VD: TV GPU yếu) bằng ?delegate=CPU trên URL.
const DELEGATE = new URLSearchParams(location.search).get('delegate')?.toUpperCase() === 'CPU' ? 'CPU' : 'GPU';

let worker = null;
let stream = null;
let video = null; // <video> ẩn dùng để lấy khung hình nhận diện
const previews = new Set(); // các <video> xem trước đang hiển thị trong Flutter
let mode = 'face';
let running = false;
let inFlight = false; // đang chờ worker trả kết quả khung trước (chống dồn hàng)
let lastSent = 0;
let interval = FAST_INTERVAL_MS;

// Số liệu đo hiệu năng (xem trong DevTools: motionBridge.stats)
const stats = { detectFps: 0, avgCostMs: 0, intervalMs: FAST_INTERVAL_MS, delegate: {}, video: '', error: '' };
let statFrames = 0;
let statCost = 0;
let statStart = 0;

function ensureWorker() {
  if (worker) return worker;
  worker = new Worker(new URL('motion_worker.js', import.meta.url));
  worker.onmessage = onWorkerMessage;
  worker.onerror = (e) => {
    console.error('[motion] worker error', e.message);
    stats.error = e.message;
    inFlight = false;
  };
  return worker;
}

function onWorkerMessage(event) {
  const msg = event.data;
  switch (msg.type) {
    case 'delegate':
      stats.delegate[msg.kind] = msg.delegate;
      return;
    case 'error':
      stats.error = msg.message;
      return;
    case 'skip':
      inFlight = false;
      return;
    case 'result':
      inFlight = false;
      onResult(msg);
  }
}

function onResult({ mode: resultMode, data, count, width, height, cost }) {
  interval = cost > SLOW_DETECT_MS ? SLOW_INTERVAL_MS : FAST_INTERVAL_MS;

  const now = performance.now();
  statFrames++;
  statCost += cost;
  if (now - statStart >= 1000) {
    stats.detectFps = Math.round((statFrames * 1000) / (now - statStart));
    stats.avgCostMs = Math.round(statCost / statFrames);
    stats.intervalMs = interval;
    stats.video = `${width}x${height}`;
    statFrames = 0;
    statCost = 0;
    statStart = now;
  }

  if (resultMode !== mode) return; // kết quả của chế độ cũ (vừa đổi chế độ)
  if (resultMode === 'hand') {
    bridge.onHands?.(data ?? new Float32Array(0), count, width, height, cost);
  } else {
    bridge.onFace?.(data, width, height, cost);
  }
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

  // Camera hiện ngay; model nạp nền trong worker, có model thì bắt đầu nhận diện
  ensureWorker().postMessage({ type: 'prepare', mode, delegate: DELEGATE });
  running = true;
  scheduleNextFrame();
  return { width: video.videoWidth, height: video.videoHeight };
}

function stop() {
  running = false;
  inFlight = false;
  stream?.getTracks().forEach((t) => t.stop());
  stream = null;
  video?.remove();
  video = null;
}

function setMode(newMode) {
  if (newMode === mode) return;
  mode = newMode;
  interval = FAST_INTERVAL_MS;
  worker?.postMessage({ type: 'prepare', mode, delegate: DELEGATE });
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
  sendFrame();
  scheduleNextFrame();
}

/** Gửi khung hình hiện tại sang worker (mỗi lần chỉ 1 khung đang xử lý) */
function sendFrame() {
  if (document.hidden || !video || video.readyState < 2) return; // tab ẩn: không tốn CPU/pin
  const now = performance.now();
  if (inFlight && now - lastSent < RESULT_TIMEOUT_MS) return;
  if (now - lastSent < interval - FRAME_JITTER_MS) return;
  inFlight = true;
  lastSent = now;
  const frameMode = mode;
  createImageBitmap(video)
    .then((bitmap) => {
      worker.postMessage({ type: 'detect', mode: frameMode, bitmap, timestamp: now }, [bitmap]);
    })
    .catch((e) => {
      console.error('[motion] cannot grab frame', e);
      inFlight = false;
    });
}

const bridge = {
  start,
  stop,
  setMode,
  createPreview,
  listCameras,
  stats,
  onHands: null, // (Float32Array data, int count, width, height, costMs)
  onFace: null, // (Float32Array | null data, width, height, costMs)
};
window.motionBridge = bridge;
