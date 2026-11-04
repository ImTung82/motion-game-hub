# Ghi chú cho Claude

Ứng dụng Flutter: game học tiếng Anh cho trẻ, điều khiển bằng khuôn mặt / bàn tay qua camera.
Chạy trên Android (ML Kit + MediaPipe native) và Web (MediaPipe JS trong `web/motion/`). Xem README.md.

## Lưu ý khi làm việc (từ người dùng)

- **Hiệu năng / FPS:** đừng mất thời gian đo FPS chi tiết. Kết quả phụ thuộc camera, phần cứng, máy đang chạy gì...
  Chỉ cần áp dụng best practice để mọi loại thiết bị (laptop, PC, Android TV, điện thoại, tablet) đều chạy ổn.
- **Deploy:** đã có CI/CD (`.github/workflows/deploy-web.yml`). Push lên `main` là tự build & deploy lên
  Firebase Hosting; PR có bản xem trước. Không cần deploy tay trừ khi được yêu cầu.
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
  - `web/index.html` giới hạn vẽ ~72 FPS trên màn 120/144Hz để GPU còn sức cho MediaPipe.
- Layout phải ổn cả màn điện thoại lẫn màn rộng (1920px, TV): đừng chặn cứng kích thước theo px.
