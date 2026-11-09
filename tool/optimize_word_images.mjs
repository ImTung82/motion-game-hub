// Chuẩn hoá ảnh minh hoạ của từ trong assets/words: PNG 256x256 (giữ tỉ lệ, phần thừa trong suốt).
// - Cắt bỏ viền trắng / trong suốt quanh hình (ảnh 16:9 con vật đứng giữa => con vật to kín khung), chừa lề MARGIN.
// - Ảnh .jpg / .jpeg / .webp / .png khác cỡ => chuyển thành <từ>.png rồi xoá file gốc. Ảnh đã chuẩn thì bỏ qua.
//   node tool/optimize_word_images.mjs
// Cần ffmpeg + ffprobe trong PATH. Chạy mỗi khi thêm ảnh mới, trước khi build.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readdirSync, renameSync, rmSync, statSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SIZE = 256; // = cỡ app giải mã (WordImages._decodeSize): lớn hơn chỉ làm bản web tải nặng thêm
const MARGIN = 0.04; // lề trong suốt mỗi bên (tỉ lệ theo SIZE) để hình không chạm mép huy hiệu
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const wordsDir = join(root, 'assets', 'words');
const imageExts = new Set(['.png', '.jpg', '.jpeg', '.webp']);

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* walk(p);
    else if (imageExts.has(extname(name).toLowerCase())) yield p;
  }
}

function probe(file) {
  const out = execFileSync('ffprobe', [
    '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height,pix_fmt', '-of', 'csv=p=0', file,
  ]).toString().trim();
  const [w, h, pixFmt] = out.split(',');
  return { w: Number(w), h: Number(h), pixFmt };
}

/// Khung chứa hình (bỏ viền trắng / trong suốt): dán ảnh lên nền trắng, đánh dấu pixel khác trắng rõ rệt
/// (lệch > 24/255, bỏ nhiễu nén JPG) rồi để cropdetect tìm khung. Không tìm được => null (giữ nguyên ảnh).
function contentBox(file) {
  // cropdetect in kết quả ra stderr => spawnSync (execFileSync chỉ trả stdout)
  const out = spawnSync('ffmpeg', [
    '-hide_banner', '-i', file, '-filter_complex',
    "color=white:s=16x16[bg];[bg][0]scale2ref[bg][fg];[bg][fg]overlay=format=auto,format=gray,negate," +
      "lut=y='if(gt(val,24),255,0)',cropdetect=limit=1:round=1:reset=0:skip=0",
    '-frames:v', '1', '-f', 'null', '-',
  ], { encoding: 'utf8' }).stderr ?? '';
  const m = [...out.matchAll(/crop=(\d+):(\d+):(\d+):(\d+)/g)].pop();
  if (!m) return null;
  const [w, h, x, y] = m.slice(1).map(Number);
  return w > 0 && h > 0 ? { w, h, x, y } : null;
}

const kb = (file) => Math.round(statSync(file).size / 1024);
let changed = 0;

for (const file of walk(wordsDir)) {
  const ext = extname(file);
  const base = file.slice(0, -ext.length);
  const target = `${base}.png`;
  if (!existsSync(`${base}.mp3`)) {
    console.warn(`CHÚ Ý ${file.slice(wordsDir.length + 1)}: không có file .mp3 cùng tên => game không biết ảnh này của từ nào (đặt tên trùng từ).`);
  }
  if (file !== target && existsSync(target)) {
    console.warn(`BỎ QUA ${file.slice(wordsDir.length + 1)}: đã có ${target.slice(wordsDir.length + 1)}, xoá 1 trong 2 file rồi chạy lại.`);
    continue;
  }
  const info = probe(file);
  if (ext === '.png' && info.w === SIZE && info.h === SIZE && info.pixFmt === 'rgba') continue;

  const tmp = `${base}.tmp.png`;
  const box = contentBox(file);
  const inner = Math.round(SIZE * (1 - MARGIN * 2));
  execFileSync('ffmpeg', [
    '-v', 'error', '-y', '-i', file,
    '-vf', [
      'format=rgba',
      ...(box ? [`crop=${box.w}:${box.h}:${box.x}:${box.y}`] : []),
      `scale=${inner}:${inner}:force_original_aspect_ratio=decrease:flags=lanczos`,
      `pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=0x00000000`,
    ].join(','),
    '-frames:v', '1', '-compression_level', '9', '-pred', 'mixed', tmp,
  ]);
  const before = kb(file);
  if (file !== target) rmSync(file);
  renameSync(tmp, target);
  changed++;
  console.log(`${file.slice(wordsDir.length + 1)} (${info.w}x${info.h}, ${before}KB) -> ${target.slice(wordsDir.length + 1)} (${SIZE}x${SIZE}, ${kb(target)}KB)`);
}

console.log(changed ? `Đã chuẩn hoá ${changed} ảnh.` : 'Mọi ảnh đã chuẩn, không đổi gì.');
