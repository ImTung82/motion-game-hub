# web/motion: camera + AI cho bản Web

Thư mục này được copy nguyên vào bản build web.

- `motion_bridge.js` (luồng chính): mở webcam, gửi khung hình sang worker, chuyển kết quả cho Flutter (`lib/motion/backend/motion_backend_web.dart`) qua `window.motionBridge`.
- `motion_worker.js` (Web Worker): chạy MediaPipe Tasks Vision trên luồng riêng để không làm giật game.

Xem hiệu năng trong DevTools: `motionBridge.stats`.

## Giảm trễ nhận diện (áp dụng cho mọi thiết bị)

- **Số tay theo game:** game 1 tay chỉ tìm 1 tay (`numHands: 1`), hub/game 2 tay mới tìm 2
  (`FaceMotionController.holdTwoHands()` / `releaseTwoHands()`). MediaPipe chỉ chạy bước tìm bàn tay (tốn nhất)
  khi số tay đang bám < `numHands`, nên để 2 mà chỉ giơ 1 tay thì chậm gấp ~2 lần.
- **Tự chọn GPU / CPU:** worker đo thời gian nhận diện trên GPU ngay lúc đang chơi; GPU chậm (> 30ms) thì thử
  CPU, giữ bên nhanh hơn rõ rệt và nhớ theo GPU + phiên bản Chrome (`stats.choice`, `stats.bench`).
  Ép cố định: `?delegate=GPU` / `?delegate=CPU`. Đo lại: `motionBridge.debug.resetDelegateChoice()` rồi tải lại trang.
- **Lọc tín hiệu theo thời gian** (`lib/motion/signal_filters.dart`): máy nhận diện chậm không bị trễ hơn
  máy nhanh; vị trí tay & góc đầu dùng bộ lọc One Euro (đứng yên hết rung, vung nhanh hết trễ).

## Thư viện & model (tự host, không phụ thuộc CDN)

| File | Nguồn |
|---|---|
| `mediapipe/vision_bundle_iife.js` | `@mediapipe/tasks-vision@1.1.1` → `vision_bundle.js` (bản IIFE, nạp bằng `importScripts` trong worker) |
| `mediapipe/wasm/vision_wasm_internal.{js,wasm}` | `@mediapipe/tasks-vision@1.1.1` → `wasm/` (bản SIMD) |
| `mediapipe/wasm/vision_wasm_nosimd_internal.{js,wasm}` | `@mediapipe/tasks-vision@1.1.1` → `wasm/` (dự phòng cho trình duyệt cũ, VD trên TV) |
| `models/hand_landmarker.task` | `https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task` |
| `models/face_landmarker.task` | `https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task` |

Giấy phép: Apache-2.0 (MediaPipe).

## Nâng cấp

```bash
npm pack @mediapipe/tasks-vision@<phiên bản>
```

Giải nén, chép `vision_bundle.js` thành `mediapipe/vision_bundle_iife.js` và 4 file `vision_wasm_internal.*`, `vision_wasm_nosimd_internal.*` vào `mediapipe/wasm/`, rồi cập nhật bảng trên.
