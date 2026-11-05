// Chạy tự động trước `firebase deploy` (predeploy trong firebase.json).
// Thay __MOTION_VERSION__ trong build/web/index.html bằng mã băm của web/motion/*.js:
// mỗi lần bridge / worker đổi thì link đổi => điện thoại không dùng bản JS cũ trong bộ nhớ đệm
// (bản Dart mới gọi hàm mà JS cũ chưa có => camera lỗi, VD: "setMaxHands is not a function").
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

const root = new URL('../build/web/', import.meta.url);
const indexUrl = new URL('index.html', root);
const files = ['motion/motion_bridge.js', 'motion/motion_worker.js', 'motion/mediapipe/vision_bundle_iife.js'];

const hash = createHash('sha256');
for (const file of files) hash.update(readFileSync(new URL(file, root)));
const version = hash.digest('hex').slice(0, 12);

const html = readFileSync(indexUrl, 'utf8');
if (!html.includes('__MOTION_VERSION__')) {
  if (/motion_bridge\.js\?v=[0-9a-f]{12}/.test(html)) {
    console.log('index.html already stamped');
    process.exit(0);
  }
  console.error('build/web/index.html: missing __MOTION_VERSION__ (run `flutter build web --wasm` first)');
  process.exit(1);
}
writeFileSync(indexUrl, html.replaceAll('__MOTION_VERSION__', version));
console.log(`motion scripts version ${version}`);
