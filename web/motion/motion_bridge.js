// Cầu nối camera + MediaPipe cho bản Web.
// Flutter (lib/motion/backend/motion_backend_web.dart) gọi window.motionBridge qua dart:js_interop.
// Luồng chính chỉ lo camera & gửi khung hình; AI chạy trong motion_worker.js (luồng riêng)
// để Flutter có trọn luồng chính mà vẽ game mượt.

// ~30 FPS; máy rất chậm (1 lần nhận diện > 60ms) tự hạ xuống ~15 FPS cho đỡ tốn pin. AI chạy trong worker nên
// không cần hạ sớm hơn: VD CPU điện thoại ~41ms/lần vẫn chạy ~24 lần/giây.
// Khung camera 30 FPS cách nhau ~33,3ms và hay lệch vài ms => chừa 8ms dung sai, nếu không sẽ bỏ sót
// gần một nửa số khung (thực tế chỉ còn ~15 FPS).
const FAST_INTERVAL_MS = 33;
const SLOW_INTERVAL_MS = 66;
const SLOW_DETECT_MS = 60;
const FRAME_JITTER_MS = 8;
// Worker không trả lời quá lâu (VD: đang nạp model GPU) thì cho gửi khung mới
const RESULT_TIMEOUT_MS = 1000;
// Bộ xử lý AI: GPU mặc định; worker tự đo GPU vs CPU ngay trên máy đang chạy (lúc game đang vẽ) và chọn bên
// nhanh hơn, nhớ kết quả theo GPU + phiên bản Chrome (xem benchStep trong motion_worker.js).
// Ép cố định để dò lỗi trên máy lạ: ?delegate=CPU hoặc ?delegate=GPU trên URL (tắt tự đo).
const forcedDelegate = (() => {
  const v = new URLSearchParams(location.search).get('delegate')?.toUpperCase();
  return v === 'CPU' || v === 'GPU' ? v : null;
})();
let delegate = forcedDelegate === 'CPU' ? 'CPU' : 'GPU';
// MediaPipe lỗi (VD: GPU vài máy trả NaN) => dựng lại worker, tối đa 1 lần / 3s.
// GPU lỗi 3 lần trong 1 phút thì chuyển hẳn sang CPU cho phiên này.
const RESTART_MIN_GAP_MS = 3000;
const GPU_FAILURES_BEFORE_CPU = 3;
let lastRestart = -Infinity;
let gpuFailures = [];

// Kết quả kiểm tra GPU (xem checkGpu trong motion_worker.js) lưu theo GPU + phiên bản Chrome:
// lần sau mở trang khỏi kiểm tra lại; cập nhật Chrome / driver thì tự kiểm tra lại.
const GPU_KEY = (() => {
  let renderer = 'unknown';
  try {
    const gl = new OffscreenCanvas(1, 1).getContext('webgl2');
    const info = gl?.getExtension('WEBGL_debug_renderer_info');
    renderer = (info && gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) || gl?.getParameter(gl.RENDERER) || renderer;
  } catch (_) {}
  const chrome = navigator.userAgent.match(/Chrome\/(\d+)/)?.[1] ?? 'other';
  return `motion.gpuOk:${renderer}:${chrome}`;
})();

function loadGpuOk() {
  try {
    const v = localStorage.getItem(GPU_KEY);
    return v === null ? null : v === 'true';
  } catch (_) {
    return null;
  }
}

function saveGpuOk(ok) {
  try {
    localStorage.setItem(GPU_KEY, String(ok));
  } catch (_) {}
}

// Kết quả đo GPU vs CPU của từng model (hand / face), cùng khoá máy với GPU_KEY
const choiceKey = (kind) => GPU_KEY.replace('motion.gpuOk:', `motion.delegate.${kind}:`);

function loadChoices() {
  const out = {};
  for (const kind of ['hand', 'face']) {
    try {
      const v = localStorage.getItem(choiceKey(kind));
      if (v === 'CPU' || v === 'GPU') out[kind] = v;
    } catch (_) {}
  }
  return out;
}

function saveChoice(kind, value) {
  try {
    localStorage.setItem(choiceKey(kind), value);
  } catch (_) {}
}

const initialGpuOk = loadGpuOk();
if (initialGpuOk === false && !forcedDelegate) delegate = 'CPU'; // máy đã biết GPU hỏng: dùng CPU ngay

let worker = null;
let stream = null;
let video = null; // <video> ẩn dùng để lấy khung hình nhận diện
const previews = new Set(); // các <video> xem trước đang hiển thị trong Flutter
let mode = 'face';
let running = false;
let inFlight = false; // đang chờ worker trả kết quả khung trước (chống dồn hàng)
let frameWaiting = false; // có khung mới tới trong lúc worker bận => gửi ngay khi worker xong
let lastSent = 0;
let interval = FAST_INTERVAL_MS;
// Số tay tối đa cần nhận diện (game 1 tay = 1, game 2 tay = 2) — Flutter báo qua setMaxHands
let maxHands = 1;

// Số liệu đo hiệu năng (xem trong DevTools: motionBridge.stats)
const stats = {
  detectFps: 0, avgCostMs: 0, intervalMs: FAST_INTERVAL_MS, maxHands, delegate: {}, choice: loadChoices(), bench: {},
  gpuOk: null, video: '', error: '', restarts: 0,
};
let statFrames = 0;
let statCost = 0;
let statStart = 0;
const debugLog = []; // 20 tin nhắn gần nhất từ worker (dò lỗi)

function ensureWorker() {
  if (worker) return worker;
  // Giữ ?v=... của bridge cho worker: đổi bản là tải worker mới, không lấy bản cũ trong bộ nhớ đệm
  worker = new Worker(new URL(`motion_worker.js${new URL(import.meta.url).search}`, import.meta.url));
  worker.onmessage = onWorkerMessage;
  worker.onerror = (e) => {
    console.error('[motion] worker error', e.message);
    stats.error = e.message;
    inFlight = false;
  };
  worker.postMessage({
    type: 'prepare',
    mode,
    delegate,
    gpuOk: forcedDelegate === 'GPU' ? true : loadGpuOk(),
    decided: forcedDelegate ? {} : loadChoices(),
    autoBench: !forcedDelegate,
    numHands: maxHands,
  });
  return worker;
}

/** Graph MediaPipe hỏng thì không cứu được trong cùng worker => bỏ worker, dựng worker mới (nạp lại wasm + GPU) */
function restartWorker(reason) {
  const now = performance.now();
  if (now - lastRestart < RESTART_MIN_GAP_MS) return;
  lastRestart = now;
  stats.restarts++;
  stats.error = reason;
  if (delegate === 'GPU') {
    gpuFailures = gpuFailures.filter((t) => now - t < 60000);
    gpuFailures.push(now);
    if (gpuFailures.length >= GPU_FAILURES_BEFORE_CPU && forcedDelegate !== 'GPU') {
      console.warn('[motion] GPU keeps failing on this device, switching to CPU');
      delegate = 'CPU';
      saveGpuOk(false);
    }
  }
  worker?.terminate();
  worker = null;
  inFlight = false;
  if (running) ensureWorker();
}

function onWorkerMessage(event) {
  const msg = event.data;
  debugLog.push({ type: msg.type, mode: msg.mode, count: msg.count, cost: msg.cost && Math.round(msg.cost), t: Math.round(performance.now()) });
  if (debugLog.length > 20) debugLog.shift();
  switch (msg.type) {
    case 'delegate':
      stats.delegate[msg.kind] = msg.delegate;
      return;
    case 'delegate-choice':
      // Kết quả đo GPU vs CPU của model này trên máy này: lưu lại, lần sau khỏi đo
      stats.choice[msg.kind] = msg.delegate;
      stats.bench[msg.kind] = { gpuMs: msg.gpuMs && Math.round(msg.gpuMs), cpuMs: msg.cpuMs && Math.round(msg.cpuMs) };
      saveChoice(msg.kind, msg.delegate);
      console.info(`[motion] ${msg.kind}: ${msg.delegate} (GPU ${stats.bench[msg.kind].gpuMs}ms, CPU ${stats.bench[msg.kind].cpuMs ?? '-'}ms)`);
      return;
    case 'gpu-check':
      stats.gpuOk = msg.ok;
      saveGpuOk(msg.ok);
      if (!msg.ok) delegate = 'CPU';
      return;
    case 'error':
      stats.error = msg.message;
      return;
    case 'fatal':
      inFlight = false;
      restartWorker(msg.message);
      return;
    case 'skip':
      inFlight = false;
      return;
    case 'result':
      inFlight = false;
      onResult(msg);
      if (frameWaiting) sendFrame(); // nhận diện lâu hơn 1 khung (VD 40ms > 33ms): không chờ thêm khung sau
  }
}

function onResult({ mode: resultMode, data, count, width, height, cost, delegate: used }) {
  if (used) stats.delegate[resultMode] = used;
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

const isEmbedded = (() => {
  try {
    return window.self !== window.top;
  } catch (_) {
    return true;
  }
})();
let embedHintShown = false;

/**
 * Đang nằm trong iframe của website khác mà không dùng được camera (trang mẹ thiếu allow="camera",
 * hoặc người dùng chặn quyền) => báo rõ và cho mở game ở tab riêng. Game vẫn chạy chế độ chạm bên dưới.
 */
function showEmbedCameraHint() {
  if (!isEmbedded || embedHintShown || !document.body) return;
  embedHintShown = true;
  const policyBlocked = (() => {
    try {
      const policy = document.permissionsPolicy || document.featurePolicy;
      return policy ? !policy.allowsFeature('camera') : false;
    } catch (_) {
      return false;
    }
  })();

  // Thanh mảnh sát mép trên, giữa màn hình: không che nút PLAY ở hub hay vùng chơi
  // (chỗ đó chỉ có hình trang trí / khoảng trống giữa các nút HUD)
  const box = document.createElement('div');
  box.setAttribute('role', 'alert');
  Object.assign(box.style, {
    position: 'fixed', left: '50%', top: 'max(6px, env(safe-area-inset-top))', transform: 'translateX(-50%)',
    zIndex: '2147483647', maxWidth: 'min(calc(100vw - 16px), 520px)', boxSizing: 'border-box',
    padding: '5px 6px 5px 14px', borderRadius: '18px', background: 'rgba(7, 8, 48, 0.88)', color: '#fff',
    font: '600 clamp(11px, 1.8vmin, 14px)/1.3 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
    boxShadow: '0 4px 16px rgba(0,0,0,0.35)', display: 'flex', alignItems: 'center', gap: '8px',
  });
  const text = document.createElement('span');
  Object.assign(text.style, { flex: '1 1 auto', minWidth: '0' });
  text.textContent = policyBlocked ? '📷 Trang này chưa cho dùng camera' : '📷 Chưa có quyền dùng camera';
  // Câu đầy đủ khi rê chuột / trình đọc màn hình
  box.title = policyBlocked
    ? 'Trang nhúng chưa cho phép game dùng camera. Mở game ở tab mới để chơi bằng khuôn mặt / bàn tay.'
    : 'Hãy cho phép camera, hoặc mở game ở tab mới để chơi bằng khuôn mặt / bàn tay.';

  const open = document.createElement('a');
  open.href = location.href;
  open.target = '_blank';
  open.rel = 'noopener';
  open.textContent = 'Mở tab mới';
  Object.assign(open.style, {
    padding: '5px 12px', borderRadius: '999px', background: '#ffb627', color: '#070830',
    fontWeight: '800', textDecoration: 'none', whiteSpace: 'nowrap', flex: 'none',
  });

  const close = document.createElement('button');
  close.type = 'button';
  close.textContent = '✕';
  close.setAttribute('aria-label', 'Đóng');
  Object.assign(close.style, {
    background: 'transparent', border: '0', color: '#fff', font: 'inherit', fontSize: '1.1em',
    cursor: 'pointer', padding: '2px 6px', flex: 'none',
  });
  close.addEventListener('click', () => box.remove());

  box.append(text, open, close);
  document.body.appendChild(box);
}

/**
 * Điện thoại / tablet chưa từng cấp quyền camera: chờ bé chạm màn hình rồi mới xin quyền.
 * Xin ngay lúc trang đang tải thì hộp thoại của Chrome Android hay bị cửa sổ khác đè lên
 * (toast, popup của máy, đồng hồ tốc độ mạng nổi...) => bấm "Cho phép" bị chặn:
 * "Trang web này không thể yêu cầu bạn cấp quyền. Đóng mọi cửa sổ chú giải hoặc lớp phủ...".
 * Xin sau một lần chạm cũng là cách trình duyệt khuyên dùng. Laptop / PC (chuột) giữ như cũ.
 */
let tapWait = null;
async function waitForTapIfNeeded() {
  if (!window.matchMedia?.('(pointer: coarse)').matches) return;
  if (navigator.userActivation?.isActive) return; // đang trong một lần chạm: xin luôn
  try {
    const policy = document.permissionsPolicy || document.featurePolicy;
    if (policy && !policy.allowsFeature('camera')) return; // trang nhúng chặn camera: hỏi cũng vô ích
  } catch (_) {}
  let state = 'prompt';
  try {
    state = (await navigator.permissions.query({ name: 'camera' })).state;
  } catch (_) {} // trình duyệt không hỗ trợ hỏi trạng thái quyền camera: coi như chưa cấp
  if (state !== 'prompt') return; // đã cho phép (vào lại) / đã chặn (hỏi cũng không hiện)

  tapWait ??= new Promise((resolve) => {
    const box = document.createElement('div');
    box.setAttribute('role', 'status');
    box.textContent = '📷 Chạm vào màn hình để bật camera';
    Object.assign(box.style, {
      position: 'fixed', left: '50%', top: 'max(6px, env(safe-area-inset-top))', transform: 'translateX(-50%)',
      zIndex: '2147483647', maxWidth: 'min(calc(100vw - 16px), 520px)', boxSizing: 'border-box',
      padding: '7px 16px', borderRadius: '18px', background: 'rgba(7, 8, 48, 0.88)', color: '#fff',
      font: '600 clamp(12px, 2vmin, 15px)/1.3 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
      boxShadow: '0 4px 16px rgba(0,0,0,0.35)', pointerEvents: 'none', whiteSpace: 'nowrap',
      overflow: 'hidden', textOverflow: 'ellipsis',
    });
    const show = () => document.body.appendChild(box);
    if (document.body) show();
    else document.addEventListener('DOMContentLoaded', show, { once: true });

    const events = ['pointerup', 'touchend', 'keydown'];
    const done = () => {
      for (const type of events) window.removeEventListener(type, done, true);
      box.remove();
      tapWait = null;
      resolve();
    };
    // capture: nhận được cả khi Flutter chặn sự kiện; lần chạm vẫn tới Flutter (VD: bấm PLAY)
    for (const type of events) window.addEventListener(type, done, true);
  });
  await tapWait;
}

async function start(options = {}) {
  if (running) return { width: video.videoWidth, height: video.videoHeight };
  mode = options.mode || mode;
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('Camera API not available (page must be served over HTTPS)');
  }
  await waitForTapIfNeeded();

  const source = options.deviceId ? { deviceId: { exact: options.deviceId } } : { facingMode: 'user' };
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: { ...source, width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 30, max: 30 } },
    });
  } catch (e) {
    if (e?.name === 'NotAllowedError' || e?.name === 'SecurityError') showEmbedCameraHint();
    throw e;
  }

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
  ensureWorker();
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
  worker?.postMessage({ type: 'prepare', mode, delegate });
}

/** Số tay tối đa cần nhận diện: 1 cho game 1 tay (nhanh gấp ~2 lần khi chỉ giơ 1 tay), 2 cho game 2 tay */
function setMaxHands(n) {
  n = n >= 2 ? 2 : 1;
  if (n === maxHands) return;
  maxHands = n;
  stats.maxHands = n;
  worker?.postMessage({ type: 'config', numHands: n });
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
  if (inFlight && now - lastSent < RESULT_TIMEOUT_MS) {
    frameWaiting = true;
    return;
  }
  if (now - lastSent < interval - FRAME_JITTER_MS) return;
  inFlight = true;
  frameWaiting = false;
  lastSent = now;
  const frameMode = mode;
  createImageBitmap(video)
    .then((bitmap) => {
      if (!worker) {
        bitmap.close(); // worker đang được dựng lại
        inFlight = false;
        return;
      }
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
  setMaxHands,
  createPreview,
  listCameras,
  stats,
  // Dò lỗi trong DevTools. resetDelegateChoice(): quên kết quả đo GPU/CPU, tải lại trang để đo lại
  debug: {
    log: () => debugLog,
    restartWorker: () => restartWorker('manual'),
    resetDelegateChoice: () => {
      for (const kind of ['hand', 'face']) {
        try {
          localStorage.removeItem(choiceKey(kind));
        } catch (_) {}
      }
    },
  },
  onHands: null, // (Float32Array data, int count, width, height, costMs)
  onFace: null, // (Float32Array | null data, width, height, costMs)
};
window.motionBridge = bridge;
