# web/motion: camera + AI cho bản Web

Thư mục này được copy nguyên vào bản build web. `motion_bridge.js` mở webcam, chạy MediaPipe Tasks Vision và gửi kết quả cho Flutter (`lib/motion/backend/motion_backend_web.dart`) qua `window.motionBridge`.

## Thư viện & model (tự host, không phụ thuộc CDN)

| File | Nguồn |
|---|---|
| `mediapipe/vision_bundle_esm.js` | `@mediapipe/tasks-vision@1.1.1` → `vision_bundle.mjs` (đổi đuôi sang `.js` để mọi hosting trả đúng MIME cho ES module) |
| `mediapipe/wasm/vision_wasm_internal.{js,wasm}` | `@mediapipe/tasks-vision@1.1.1` → `wasm/` (bản SIMD) |
| `mediapipe/wasm/vision_wasm_nosimd_internal.{js,wasm}` | `@mediapipe/tasks-vision@1.1.1` → `wasm/` (dự phòng cho trình duyệt cũ, VD trên TV) |
| `models/hand_landmarker.task` | `https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task` |
| `models/face_landmarker.task` | `https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task` |

Giấy phép: Apache-2.0 (MediaPipe).

## Nâng cấp

```bash
npm pack @mediapipe/tasks-vision@<phiên bản>
```

Giải nén, chép `vision_bundle.mjs` thành `mediapipe/vision_bundle_esm.js` và 4 file `vision_wasm_internal.*`, `vision_wasm_nosimd_internal.*` vào `mediapipe/wasm/`, rồi cập nhật bảng trên.
