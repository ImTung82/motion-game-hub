# 🕹️ Motion Game Hub (Enspire Arcade)

Bộ game học tiếng Anh cho trẻ mẫu giáo của **Enspire Digital**, điều khiển bằng **cử chỉ khuôn mặt và bàn tay** qua camera. Bé nghe từ vựng, rồi nghiêng đầu, đưa tay, nắm tay hoặc chụm hai tay để chọn đúng hình. Không có camera thì chơi bằng chạm / chuột.

Ứng dụng viết bằng Flutter, chạy trên **Android** và **Web**:

- **Android:** nhận diện khuôn mặt bằng **Google ML Kit**, bàn tay bằng **MediaPipe Hand Landmarker** (native).
- **Web:** **MediaPipe Tasks Vision** (JS + WASM, tự host trong `web/motion/`) chạy trong Web Worker để không làm giật game.

🌐 Bản web: **https://motion-game-hub-web.web.app**

---

## 🎛️ Chế độ điều khiển

| Chế độ | Cử chỉ | Game |
|---|---|---|
| ✋ **Hand** (mặc định) | Đưa bàn tay xòe để di chuyển, nắm tay để kích hoạt | Fruits Kick, Egg Smasher |
| 🙂 **Face** | Nghiêng đầu trái/phải để di chuyển, gật đầu hoặc há miệng để kích hoạt | Fruits Kick, Egg Smasher |
| 👐 **2-Hands** | Hai tay điều khiển độc lập nửa trái/phải khung thành, nắm tay hoặc chụm hai tay để bắt | Goalkeeper Hero |
| 👆 **Chạm / chuột** | Tự bật khi không có camera (hoặc bật nút cảm ứng trong Camera Setup) | Cả 3 game |

Chọn **FACE / HAND** ngay trên menu chính (**ENSPIRE ARCADE**); chế độ 2 tay có sảnh riêng (**2-HANDS HUB**).

---

## 🎮 Danh sách game

### ⚽ Fruits Kick
Nghe một từ, rồi sút bóng vào ô khung thành có hình đúng từ đó.

- **Hand:** đưa bàn tay xòe để ngắm, nắm tay để sút.
- **Face:** nghiêng đầu để ngắm, gật đầu hoặc há miệng để sút.
- **Chạm:** chạm vào hình đúng để sút.

### 🥚 Egg Smasher
Nghe một từ, rồi đập vỡ quả trứng có hình đúng từ đó để nở ra một bạn nhỏ.

- **Hand:** đưa bàn tay xòe để chọn trứng, nắm tay để đập.
- **Face:** nghiêng đầu để chọn trứng, gật đầu để đập.
- **Chạm:** chạm vào quả trứng đúng.

### 🧤 Goalkeeper Hero (2-Hands)
Làm thủ môn, dùng cả hai tay chặn bóng và học từ vựng.

- **Cử chỉ:** mỗi tay giữ một nửa khung thành, nắm tay hoặc chụm hai tay để bắt bóng. Không có camera thì kéo găng tay tới bóng.
- **Mức độ:** 🐢 Easy, 🐰 Medium, 🚀 Hard (từ vựng lấy từ mọi nhóm).

---

## 📚 Kho từ vựng

Cả 3 game dùng chung một kho từ (`WordBank`, `lib/services/word_bank.dart`), tự dò mọi file `.mp3` trong `assets/words/`:

| Nhóm | Số từ | Nhóm | Số từ |
|---|---|---|---|
| 🍎 fruits | 16 | 🔢 numbers | 11 |
| 📦 things | 18 | 🌙 nature | 4 |
| 🐶 animals | 9 | 🏷️ describing | 4 |
| 🎨 colors | 8 | 🏃 actions, 🖐️ body | 2 + 2 |

Mỗi từ gồm `<từ>.mp3` (giọng đọc) + `<từ>.png` (ảnh 256x256 nền trong suốt) cùng thư mục, tên chữ thường. **Thêm từ mới chỉ cần thêm 2 file, không sửa code**; từ chưa có ảnh sẽ vẽ bằng emoji dự phòng. Thêm nhóm mới thì khai báo thư mục trong `pubspec.yaml`.

Chuẩn hoá ảnh mới (cắt viền, thu về PNG 256x256):

```bash
node tool/optimize_word_images.mjs
```

---

## ✨ Tính năng chung

- **Bước chuẩn bị đầu ván:** chờ camera thấy mặt / tay thật sự, đếm ngược 3-2-1 rồi mới bắt đầu và đọc đề.
- **Camera Setup (hiệu chỉnh):** xem trực tiếp camera, thước đo nghiêng / há miệng / nắm tay, chỉnh độ nhạy, cân bằng tư thế gốc, xoay camera, bật nút cảm ứng trong game.
- **Camera PiP trong game:** khung camera nhỏ ở góc màn hình (bật / tắt từ HUD).
- **Nhạc nền riêng cho sảnh và từng game**, tự hạ nhỏ khi đọc từ; hiệu ứng âm thanh, giọng đọc từ vựng, nút tắt tiếng chung.
- **Linh vật thỏ**, cảnh nền chuyển động, lưu kỷ lục (high score) riêng cho từng game.
- **Bộ lọc One Euro & vùng chết** giúp điều khiển mượt, ổn định cho trẻ nhỏ, không phụ thuộc tốc độ máy.
- **Giao diện co giãn** từ điện thoại tới màn rộng (laptop, TV 1920px).

---

## 📱 Nền tảng

| Nền tảng | Trạng thái |
|---|---|
| Android 7.0+ (camera trước) | ✅ Hỗ trợ đầy đủ |
| Web: laptop, PC có webcam, điện thoại, tablet, TV | ✅ Hỗ trợ (Chrome / Edge / Safari mới; trình duyệt cũ tự chạy bản JS) |
| Nhúng vào website khác (iframe / oEmbed) | ✅ Hỗ trợ |

---

## 🚀 Chạy dự án

**Yêu cầu:** Flutter 3.44+ (Dart 3.12+). Android: thiết bị 7.0+ (minSdk 24) có camera trước.

```bash
flutter pub get
flutter run            # chạy trên thiết bị Android đang kết nối
flutter build apk      # build bản cài đặt APK
flutter test           # chạy unit test
```

### Web

Camera chỉ chạy trên `localhost` hoặc HTTPS. Luôn build với `--wasm` (mượt gấp ~2 lần bản JS); trình duyệt không hỗ trợ WasmGC tự chạy bản JS đi kèm.

```bash
flutter build web --wasm         # build ra build/web
node tool/serve_web.mjs          # chạy thử tại http://localhost:8080
```

`tool/serve_web.mjs` gửi đủ 2 header để Flutter vẽ trên luồng riêng (thiếu thì vẫn chạy nhưng chậm hơn); Firebase emulator không gửi các header này nên đừng dùng để chạy thử:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

### Deploy

Firebase Hosting, project `motion-game-hub-web` (header & cache cấu hình trong `firebase.json`). Bước predeploy tự chạy `tool/stamp_web_version.mjs` để gắn mã phiên bản cho JS trong `web/motion/`, tránh trình duyệt giữ bản cũ.

```bash
flutter build web --wasm
firebase deploy --only hosting   # -> https://motion-game-hub-web.web.app
```

### Nhúng vào website khác

Trang hỗ trợ oEmbed chỉ cần dán link `https://motion-game-hub-web.web.app/` (khai báo trong `web/oembed.json`). Nhúng tay thì bắt buộc có `allow="camera"`, thiếu thì game báo và mời mở tab mới:

```html
<iframe src="https://motion-game-hub-web.web.app/" width="960" height="540" style="border:0"
        allow="camera; fullscreen; autoplay; gamepad" allowfullscreen></iframe>
```

Trong iframe, website mẹ thường không gửi COEP nên Flutter vẽ đơn luồng (vẫn chạy, chậm hơn một chút trên máy yếu).

### Lưu ý khi chơi

Lần đầu mở app cần **cấp quyền camera**. Nên chơi ở nơi đủ sáng, đặt máy ngang và đứng cách camera khoảng 0,5-1 m (chế độ 2 tay: 1-1,5 m).

Tạo lại icon ứng dụng từ logo:

```bash
dart run flutter_launcher_icons
```

---

## 🗂️ Cấu trúc thư mục

```
lib/
├── main.dart
├── core/            # Hằng số dùng chung
├── motion/          # Camera + AI và xử lý cử chỉ, bộ lọc tín hiệu
│   └── backend/     # native (ML Kit, MediaPipe) / web (cầu nối sang web/motion)
├── services/        # Âm thanh, nhạc nền, kho từ vựng (WordBank), ảnh từ
├── games/
│   ├── penalty_kick/     # Fruits Kick
│   ├── egg_smasher/      # Egg Smasher
│   └── goalkeeper_hero/  # Goalkeeper Hero (2 tay)
└── ui/
    ├── screens/     # Splash, menu chính, sảnh 2 tay
    └── widgets/     # UI phong cách trẻ em, Camera Setup, PiP, linh vật...
assets/
├── audio/           # Hiệu ứng âm thanh, music/ (nhạc nền)
├── words/           # Từ vựng theo nhóm: <từ>.mp3 + <từ>.png
├── images/          # Logo, ảnh nền, linh vật
└── animations/      # Lottie splash
web/
├── motion/          # MediaPipe JS + model tự host, motion_bridge.js, motion_worker.js
└── oembed.json      # Khai báo nhúng oEmbed
tool/                # serve_web.mjs, stamp_web_version.mjs, optimize_word_images.mjs
test/                # Unit test
docs/                # Tài liệu thiết kế (kế hoạch game 2 tay)
```

> `lib/games/flappy_mouth` và `lib/games/sky_chomp` là game cũ, không có trên menu.
