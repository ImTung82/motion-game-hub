# Ghi chú cho Claude

Ứng dụng Flutter: game học tiếng Anh cho trẻ, điều khiển bằng khuôn mặt / bàn tay qua camera.
Chạy trên Android (ML Kit + MediaPipe native) và Web (MediaPipe JS trong `web/motion/`). Xem README.md.

## Lưu ý khi làm việc (từ người dùng)

- **Hiệu năng / FPS:** đừng mất thời gian đo FPS chi tiết. Kết quả phụ thuộc camera, phần cứng, máy đang chạy gì...
  Chỉ cần áp dụng best practice để mọi loại thiết bị (laptop, PC, Android TV, điện thoại, tablet) đều chạy ổn.
- **Chạy thử rồi mới deploy:** không dùng CI/CD. Mỗi khi code xong một việc:
  1. Tự chạy localhost cho người dùng xem thử: `flutter build web --wasm` rồi `node tool/serve_web.mjs`
     (chạy nền, mở http://localhost:8080, gửi đủ header COOP/COEP như `firebase.json`; Firebase emulator
     không gửi các header này nên không dùng). Gửi link và báo cần xem gì.
  2. **Chờ người dùng xác nhận.** Chưa xác nhận thì KHÔNG commit, push hay deploy.
  3. Người dùng xác nhận xong mới làm, không cần hỏi lại: commit + push lên GitHub (nhánh đang làm), rồi
     `firebase deploy --only hosting` (dùng bản `build/web` vừa thử; project trong `.firebaserc`).
     Báo lỗi đăng nhập thì nhờ người dùng chạy `firebase login`.
- **Chỉ sửa game có trong hub:** game không hiện ở màn hub thì không sửa. Hiện các hub chỉ mở:
  Fruits Kick (`penalty_kick`), Egg Smasher (`egg_smasher`), Goalkeeper Hero (`goalkeeper_hero`).
  `flappy_mouth`, `sky_chomp` không được dùng.

## Web

- Luôn build `flutter build web --wasm`; máy chủ phải gửi header COOP `same-origin` + COEP `require-corp`
  (đã cấu hình trong `firebase.json`).
- Hosting: Firebase project `motion-game-hub-web` -> https://motion-game-hub-web.web.app
- Best practice đã áp dụng, giữ khi viết code mới:
  - Engine game `notifyListeners()` mỗi khung để canvas vẽ lại => HUD nghe engine dùng `ListenableSelector`
    (chỉ build lại khi giá trị đổi), không dùng `ListenableBuilder`.
  - Canvas game bọc `RepaintBoundary`; chữ / emoji trong `CustomPainter` lấy qua `TextPainterCache`.
  - Tránh hàng trăm lệnh vẽ nhỏ mỗi khung (VD: dùng `drawAtlas` như khán đài Fruits Kick).
  - `web/index.html` nạp `motion/motion_bridge.js?v=__MOTION_VERSION__`; `firebase deploy` tự chạy
    `tool/stamp_web_version.mjs` (predeploy) thay bằng mã băm => điện thoại không giữ JS cũ lệch với bản Dart mới.
    Bridge chuyền `?v=` sang worker / MediaPipe; file JS mới trong `web/motion/` cũng nạp theo kiểu đó.
  - `web/index.html` giới hạn vẽ ~72 FPS trên màn 120/144Hz để GPU còn sức cho MediaPipe.
- Layout phải ổn cả màn điện thoại lẫn màn rộng (1920px, TV): đừng chặn cứng kích thước theo px.
