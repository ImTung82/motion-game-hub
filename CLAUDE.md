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

## Học liệu từ vựng (`assets/words`)

- Chia thư mục theo nhóm (`animals/`, `fruits/`, `colors/`...). Mỗi từ: `<từ>.mp3` (đọc) + `<từ>.png` (ảnh), cùng thư mục,
  tên chữ thường trùng từ trong game (VD `animals/cat.mp3`, `animals/cat.png`). Thêm nhóm mới => khai báo thư mục trong `pubspec.yaml`.
- Code tra file theo tên qua AssetManifest (`SoundService.playWord`, `WordImages`) => thêm ảnh tới đâu game dùng tới đó,
  từ chưa có ảnh thì tạm vẽ emoji. Khi đủ ảnh cho mọi từ thì bỏ hẳn emoji của từ (và bỏ `WordImages.testImagesOnly`).
- Chạy thử (web localhost / bản debug): game chỉ ra từ ĐÃ CÓ ẢNH, thiếu thì bù từ emoji cho đủ số ô
  (`WordImages.shuffledPreferImages`). Bản thật (Firebase) dùng mọi từ.
- Giải mã ảnh cho canvas dùng `ui.instantiateImageCodecWithSize`; KHÔNG dùng `ui.ImageDescriptor` (web không hỗ trợ
  => lặng lẽ hiện emoji).

### Quy trình khi người dùng báo đã thêm / sửa ảnh

1. Xem thư mục nào có ảnh mới (`git status`, so cỡ bằng `ffprobe`: ảnh đã chuẩn là PNG 256x256 rgba).
2. Sao lưu ảnh gốc mới vào scratchpad (`word_images_original/...`) trước khi script ghi đè / xoá.
3. Xem từng ảnh (thu nhỏ bằng ffmpeg rồi Read) và báo người dùng nếu: tên không khớp từ nào (script cũng cảnh báo khi
   không có `.mp3` cùng tên), nền caro "giả" in sẵn vào ảnh, watermark, hình không đúng nghĩa từ trong game
   (VD `bat` trong game là con dơi).
4. `node tool/optimize_word_images.mjs`: cắt bỏ viền trắng / trong suốt quanh hình, thu về PNG 256x256 (lề 4%,
   phần thừa trong suốt), xoá file gốc khác đuôi; ảnh đã chuẩn thì bỏ qua (chạy lại không đổi gì).
5. Ghép ảnh kết quả thành 1 tấm (ffmpeg `xstack`) rồi Read để kiểm tra hình không bị cắt lẹm / quá nhỏ.
6. `flutter build web --wasm` + chạy localhost (mục "Chạy thử rồi mới deploy"), báo game / chủ đề nào có từ vừa thêm ảnh.
7. Chờ người dùng xác nhận rồi mới commit + push + deploy.

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
