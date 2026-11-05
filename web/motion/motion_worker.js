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

// Tự chọn GPU hay CPU bằng cách đo NGAY TRÊN MÁY ĐANG CHẠY, lúc game đang vẽ (GPU yếu bị Flutter tranh,
// có máy CPU lại nhanh hơn; có máy ngược lại) — không đoán theo một loại thiết bị nào.
// GPU đủ nhanh (trung vị <= BENCH_FAST_MS) thì giữ luôn, khỏi thử CPU.
// Chỉ đổi sang CPU khi CPU nhanh hơn rõ (< 80% thời gian GPU), vì CPU tốn pin & nóng máy hơn.
const BENCH_WARMUP = 8; // bỏ vài khung đầu (shader / bộ nhớ đệm còn đang khởi động)
const BENCH_SAMPLES = 30;
const BENCH_FAST_MS = 30;
const BENCH_CPU_WIN_RATIO = 0.8;

let fileset = null;
const landmarkers = { hand: null, face: null }; // model đang dùng để nhận diện
const activeDelegate = { hand: null, face: null };
const loading = { hand: null, face: null };
// Bộ xử lý ưu tiên, do motion_bridge.js gửi sang (GPU mặc định, lỗi thì tự về CPU)
let preferredDelegate = 'GPU';
// Lựa chọn GPU/CPU đã đo ở lần trước (lưu trong localStorage ở luồng chính): { hand: 'CPU', ... }
let decidedDelegate = {};
let autoBench = true;
// Kết quả kiểm tra GPU đã lưu từ lần trước (true / false / null = chưa biết) & bài kiểm tra đang chạy
let knownGpuOk = null;
let gpuCheck = null;
// Số tay tối đa: game 1 tay để 1. MediaPipe chỉ chạy bước TÌM bàn tay (palm detection, tốn nhất) khi số tay
// đang bám < numHands => để 2 mà chỉ giơ 1 tay thì khung nào cũng phải tìm lại => chậm gấp ~2 lần.
let numHands = 2;
const reconfiguring = { hand: null, face: null }; // Promise setOptions đang chạy (không được detect lúc này)

// Trạng thái đo GPU/CPU theo từng loại model
const bench = { hand: null, face: null };

async function createLandmarker(kind, delegate) {
  fileset ??= await FilesetResolver.forVisionTasks(WASM_PATH);
  const baseOptions = { modelAssetPath: MODEL_URLS[kind], delegate };
  if (kind === 'hand') {
    const n = numHands;
    const lm = await HandLandmarker.createFromOptions(fileset, {
      baseOptions,
      runningMode: 'VIDEO',
      numHands: n,
      minHandDetectionConfidence: 0.5,
    });
    lm.motionNumHands = n; // numHands có thể đổi trong lúc nạp => so lại trước khi nhận diện (syncNumHands)
    return lm;
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

function closeQuietly(lm) {
  try {
    lm?.close();
  } catch (_) {}
}

function setActive(kind, lm, delegate) {
  landmarkers[kind] = lm;
  activeDelegate[kind] = delegate;
  self.postMessage({ type: 'delegate', kind, delegate });
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
    if (ok && !landmarkers.face && delegateFor('face') === 'GPU') {
      setActive('face', lm, 'GPU'); // dùng lại, khỏi nạp lần 2
    } else {
      closeQuietly(lm);
    }
    self.postMessage({ type: 'gpu-check', ok });
    return ok;
  })();
  return gpuCheck.then((ok) => {
    if (!ok) preferredDelegate = 'CPU';
    return ok;
  });
}

/** Bộ xử lý sẽ dùng cho model [kind]: GPU hỏng => CPU; đã đo ở lần trước => theo kết quả đo */
function delegateFor(kind) {
  if (preferredDelegate === 'CPU') return 'CPU';
  return decidedDelegate[kind] ?? 'GPU';
}

/** Nạp model khi cần (theo bộ xử lý ưu tiên, GPU lỗi thì về CPU); chỉ nạp 1 lần */
function ensureLandmarker(kind) {
  if (landmarkers[kind]) return Promise.resolve(landmarkers[kind]);
  loading[kind] ??= (async () => {
    if (preferredDelegate === 'GPU') await checkGpu();
    if (landmarkers[kind]) return landmarkers[kind]; // model mặt GPU giữ lại từ bài kiểm tra
    let delegate = delegateFor(kind);
    let lm;
    try {
      lm = await createLandmarker(kind, delegate);
    } catch (e) {
      if (delegate === 'CPU') throw e;
      console.warn(`[motion] ${kind} GPU delegate failed, using CPU`, e);
      delegate = 'CPU';
      lm = await createLandmarker(kind, delegate);
    }
    setActive(kind, lm, delegate);
    return lm;
  })().catch((e) => {
    console.error(`[motion] cannot load ${kind} model`, e);
    self.postMessage({ type: 'error', kind, message: String(e) });
    loading[kind] = null; // cho phép thử lại lần sau
    throw e;
  });
  return loading[kind];
}

/** Model tay đang dùng chưa đúng numHands (vừa đổi / nạp từ trước khi đổi) => setOptions; true = đang đổi */
function syncNumHands() {
  if (reconfiguring.hand) return true;
  const lm = landmarkers.hand;
  if (!lm || lm.motionNumHands === numHands) return false;
  const n = numHands;
  const job = lm
    .setOptions({ numHands: n })
    .then(() => {
      lm.motionNumHands = n;
    })
    .catch((e) => {
      console.error('[motion] cannot change numHands', e);
      self.postMessage({ type: 'fatal', kind: 'hand', message: `numHands: ${e}` });
    })
    .finally(() => {
      if (reconfiguring.hand === job) reconfiguring.hand = null;
    });
  reconfiguring.hand = job;
  return true;
}

/** Đổi số tay tối đa (áp vào model ở khung nhận diện kế tiếp, xem syncNumHands) */
function applyNumHands(n) {
  if (n === numHands) return;
  numHands = n;
  // Số tay đổi => thời gian nhận diện đổi: bỏ phép đo GPU/CPU đang dở, đo lại từ đầu với GPU
  const b = bench.hand;
  if (b && !b.done) {
    if (b.phase === 'cpu') {
      landmarkers.hand = b.gpu;
      activeDelegate.hand = 'GPU';
      closeQuietly(b.candidate);
    }
    bench.hand = null; // đang nạp model CPU: model đó sẽ tự bị đóng khi nạp xong
  }
  syncNumHands();
}

// ---------------------------------------------------------------------------------------------------------
// Đo GPU/CPU ngay trong lúc chơi
// ---------------------------------------------------------------------------------------------------------

function median(values) {
  const s = [...values].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)];
}

function decide(kind, delegate, gpuMs, cpuMs) {
  const b = bench[kind];
  bench[kind] = { done: true };
  decidedDelegate[kind] = delegate;
  if (b?.candidate && landmarkers[kind] !== b.candidate) closeQuietly(b.candidate);
  if (b?.gpu && landmarkers[kind] !== b.gpu) closeQuietly(b.gpu);
  self.postMessage({ type: 'delegate-choice', kind, delegate, gpuMs, cpuMs });
}

/** Gọi sau mỗi lần nhận diện thành công: gom thời gian đo, tới lúc thì thử CPU / chọn bên nhanh hơn */
function benchStep(kind, cost) {
  if (!autoBench || decidedDelegate[kind] || preferredDelegate === 'CPU') return;
  let b = bench[kind];
  if (b?.done) return;
  if (!b) {
    if (activeDelegate[kind] !== 'GPU') return; // GPU tạo lỗi => đã ở CPU, không có gì để so
    b = bench[kind] = { phase: 'gpu', seen: 0, samples: [] };
  }
  if (b.phase === 'loading-cpu') return; // GPU vẫn chạy trong lúc nạp model CPU
  if (++b.seen <= BENCH_WARMUP) return;
  b.samples.push(cost);
  if (b.samples.length < BENCH_SAMPLES) return;

  if (b.phase === 'gpu') {
    b.gpuMs = median(b.samples);
    if (b.gpuMs <= BENCH_FAST_MS) {
      decide(kind, 'GPU', b.gpuMs, null);
      return;
    }
    // GPU chậm: nạp thêm model CPU trong nền, nạp xong thì đo CPU
    b.phase = 'loading-cpu';
    createLandmarker(kind, 'CPU')
      .then((cpu) => {
        if (bench[kind] !== b) return closeQuietly(cpu); // worker đã đổi trạng thái (VD: dựng lại)
        b.candidate = cpu;
        b.gpu = landmarkers[kind];
        b.phase = 'cpu';
        b.seen = 0;
        b.samples = [];
        landmarkers[kind] = cpu;
        activeDelegate[kind] = 'CPU';
      })
      .catch((e) => {
        console.warn(`[motion] ${kind} CPU model failed, keeping GPU`, e);
        decide(kind, 'GPU', b.gpuMs, null);
      });
    return;
  }

  // b.phase === 'cpu'
  const cpuMs = median(b.samples);
  if (cpuMs < b.gpuMs * BENCH_CPU_WIN_RATIO) {
    setActive(kind, b.candidate, 'CPU');
    decide(kind, 'CPU', b.gpuMs, cpuMs);
  } else {
    setActive(kind, b.gpu, 'GPU');
    decide(kind, 'GPU', b.gpuMs, cpuMs);
  }
}

// ---------------------------------------------------------------------------------------------------------

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

function applyConfig(msg) {
  if (msg.delegate) preferredDelegate = msg.delegate;
  if (typeof msg.gpuOk === 'boolean') knownGpuOk = msg.gpuOk;
  if (msg.decided) decidedDelegate = { ...msg.decided, ...decidedDelegate };
  if (typeof msg.autoBench === 'boolean') autoBench = msg.autoBench;
  if (msg.numHands) applyNumHands(msg.numHands);
}

self.onmessage = (event) => {
  const msg = event.data;
  if (msg.type === 'config') {
    applyConfig(msg);
    return;
  }
  if (msg.type === 'prepare') {
    applyConfig(msg);
    ensureLandmarker(msg.mode).catch(() => {});
    return;
  }
  if (msg.type !== 'detect') return;

  const { mode, bitmap, timestamp } = msg;
  const width = bitmap.width;
  const height = bitmap.height;
  const landmarker = landmarkers[mode];
  if (!landmarker || reconfiguring[mode] || (mode === 'hand' && syncNumHands())) {
    bitmap.close();
    if (!landmarker) ensureLandmarker(mode).catch(() => {});
    self.postMessage({ type: 'skip' }); // model đang nạp / đang đổi cấu hình
    return;
  }

  let packed = { data: null, count: 0 };
  let cost = 0;
  let ok = false;
  try {
    const t0 = performance.now();
    const result = landmarker.detectForVideo(bitmap, timestamp);
    cost = performance.now() - t0;
    packed = mode === 'hand' ? packHands(result) : packFace(result);
    ok = true;
  } catch (e) {
    // Graph MediaPipe lỗi 1 lần là hỏng luôn; tạo lại model trong cùng worker cũng không được (ngữ cảnh
    // GPU đã hỏng: model mới chạy nhưng luôn trả rỗng) => báo luồng chính dựng worker mới hoàn toàn
    console.error('[motion] detect error, worker needs restart', e);
    // Đang thử CPU mà hỏng => chốt GPU, worker mới khỏi thử lại
    if (bench[mode]?.phase === 'cpu') decide(mode, 'GPU', bench[mode].gpuMs, null);
    self.postMessage({ type: 'fatal', kind: mode, message: `detect: ${e}` });
  } finally {
    bitmap.close();
  }
  const transfer = packed.data ? [packed.data.buffer] : [];
  self.postMessage(
    { type: 'result', mode, data: packed.data, count: packed.count, width, height, cost, delegate: activeDelegate[mode] },
    transfer,
  );
  if (ok) benchStep(mode, cost);
};
