// Chạy thử bản web đã build (build/web) trên localhost, giống Firebase Hosting:
// gửi header COOP/COEP... lấy từ firebase.json (Firebase emulator không áp các header này).
//   flutter build web --wasm
//   node tool/serve_web.mjs            # http://localhost:8080
//   node tool/serve_web.mjs 9000       # đổi cổng
// Camera chỉ mở được trên localhost / HTTPS. Mã ?v=__MOTION_VERSION__ để nguyên (không stamp) vẫn chạy bình thường.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const publicDir = join(root, 'build', 'web');
const port = Number(process.argv[2] ?? 8080);

const firebase = JSON.parse(await readFile(join(root, 'firebase.json'), 'utf8'));
// Chỉ áp các header chung cho mọi file ("source": "**"); không cache để luôn thấy bản vừa build.
const globalHeaders = Object.fromEntries(
  (firebase.hosting.headers ?? [])
    .filter((h) => h.source === '**')
    .flatMap((h) => h.headers.map(({ key, value }) => [key, value])),
);

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.task': 'application/octet-stream',
  '.tflite': 'application/octet-stream',
  '.bin': 'application/octet-stream',
};

async function resolveFile(urlPath) {
  const rel = normalize(decodeURIComponent(urlPath)).replace(/^([/\\])+/, '');
  const file = join(publicDir, rel);
  if (!file.startsWith(publicDir)) return null;
  try {
    const s = await stat(file);
    if (s.isDirectory()) return resolveFile(join(rel, 'index.html'));
    return file;
  } catch {
    return null;
  }
}

createServer(async (req, res) => {
  const urlPath = new URL(req.url, 'http://localhost').pathname;
  // Như Firebase: đường dẫn không có file thì trả index.html (SPA).
  const file = (await resolveFile(urlPath)) ?? join(publicDir, 'index.html');
  try {
    const body = await readFile(file);
    res.writeHead(200, {
      ...globalHeaders,
      'Content-Type': types[extname(file).toLowerCase()] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  } catch {
    res.writeHead(404).end('Not found (đã chạy flutter build web --wasm chưa?)');
  }
}).listen(port, () => console.log(`Serving build/web at http://localhost:${port}`));
