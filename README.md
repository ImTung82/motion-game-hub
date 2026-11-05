# 🕹️ Motion Game Hub

Bộ game học tiếng Anh cho trẻ mẫu giáo của **Enspire Digital**, điều khiển hoàn toàn bằng **cử chỉ khuôn mặt và bàn tay** qua camera trước. Bé nghe từ vựng, rồi nghiêng đầu, lướt tay, nắm tay hoặc vỗ tay để chọn đúng hình.

Ứng dụng viết bằng Flutter. Nhận diện khuôn mặt dùng **Google ML Kit**, nhận diện bàn tay dùng **MediaPipe Hand Landmarker**.

---

## 🎛️ Chế độ điều khiển

| Chế độ | Cử chỉ | Game |
|---|---|---|
| 🙂 **Face** | Nghiêng đầu trái/phải để di chuyển, gật đầu hoặc há miệng để kích hoạt | Fruits Kick, Egg Smasher |
| ✋ **1-Hand** | Lướt hoặc nghiêng bàn tay để di chuyển, nắm tay để kích hoạt | Fruits Kick, Egg Smasher |
| 👐 **2-Hands** | Hai tay điều khiển độc lập trái/phải, nắm tay hoặc chụm 2 tay để bắt | Goalkeeper Hero |

Chọn chế độ Face / Hand ngay trên menu chính; chế độ 2 tay có sảnh riêng (**2-HANDS HUB**).

---

## 🎮 Danh sách game

### ⚽ Fruits Kick
Nghe tên một loại quả, rồi sút bóng vào ô khung thành có hình đúng quả đó.

- **Face:** nghiêng đầu để ngắm, gật đầu hoặc há miệng để sút.
- **1-Hand:** đưa bàn tay xòe để ngắm, nắm tay để sút.

### 🥚 Egg Smasher
Nghe một từ, rồi đập vỡ quả trứng có hình đúng từ đó để nở ra một bạn nhỏ.

- **Face:** nghiêng đầu để chọn trứng, gật đầu để đập.
- **1-Hand:** đưa bàn tay xòe để chọn trứng, nắm tay để đập.

### 🧤 Goalkeeper Hero (2-Hands)
Làm thủ môn, dùng cả hai tay chặn bóng và học từ vựng theo chủ đề.

- **Cử chỉ:** di chuyển hai tay để che khung thành, nắm tay hoặc chụm hai tay để bắt bóng.
- **Mức độ:** 🐢 Easy, 🐰 Medium, 🚀 Hard.
- **Chủ đề từ vựng:** 🍎 Fruits, 🐶 Animals, 📦 Things, 🎲 Mixed.

---

## ✨ Tính năng chung

- **Bước chuẩn bị đầu ván:** mỗi ván chờ camera thấy mặt / tay, đếm ngược 3-2-1 rồi mới bắt đầu và đọc đề.
- **Camera Setup (hiệu chỉnh):** xem trực tiếp camera, thước đo nghiêng / há miệng / nắm tay / vỗ tay, chỉnh độ nhạy, cân bằng tư thế gốc, xoay camera.
- **Camera PiP trong game:** khung camera nhỏ ở góc màn hình (bật / tắt từ HUD).
- **Nút cảm ứng dự phòng:** bật trong Camera Setup để chơi bằng chạm khi không dùng cử chỉ.
- **Linh vật thỏ, âm thanh và giọng đọc từ vựng**, lưu kỷ lục (high score) riêng cho từng game.
- **Bộ lọc chống rung & vùng chết** giúp điều khiển mượt và ổn định cho trẻ nhỏ.

---

## 📱 Nền tảng

| Nền tảng | Trạng thái |
|---|---|
| Android (máy thật, camera trước) | ✅ Hỗ trợ đầy đủ |
| Web (TV, laptop, PC có webcam, tablet / điện thoại) | 🚧 Đang phát triển |

---

## 🚀 Chạy dự án

**Yêu cầu:** Flutter 3.44+ (Dart 3.12+), thiết bị Android 7.0+ (minSdk 24) có camera trước.

```bash
flutter pub get
flutter run            # chạy trên thiết bị Android đang kết nối
flutter build apk      # build bản cài đặt APK
```

**Web** (camera chỉ chạy trên `localhost` hoặc HTTPS):

```bash
flutter run -d chrome --wasm     # chạy thử trên Chrome
flutter build web --wasm         # build ra build/web
```

Luôn build với `--wasm`: game mượt gấp ~2 lần bản JS (đo trên laptop: ~120 so với ~60 FPS). Trình duyệt không hỗ trợ WasmGC (VD: Chrome đời cũ trên TV) tự chạy bản JS đi kèm. Máy chủ web cần gửi 2 header sau để Flutter vẽ trên luồng riêng (thiếu thì vẫn chạy nhưng chậm hơn):

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Deploy lên Firebase Hosting (project `motion-game-hub-web`, header & cache đã cấu hình trong `firebase.json`):

```bash
flutter build web --wasm
firebase deploy --only hosting   # -> https://motion-game-hub-web.web.app
```

**Nhúng vào website khác** (giống YouTube): trang hỗ trợ oEmbed chỉ cần dán link `https://motion-game-hub-web.web.app/`
(trang khai báo `web/oembed.json`). Nhúng tay thì bắt buộc có `allow="camera"`, thiếu thì game báo và mời mở tab mới:

```html
<iframe src="https://motion-game-hub-web.web.app/" width="960" height="540" style="border:0"
        allow="camera; fullscreen; autoplay; gamepad" allowfullscreen></iframe>
```

Trong iframe, website mẹ thường không gửi COEP nên Flutter vẽ đơn luồng (vẫn chạy, chậm hơn một chút trên máy yếu).

**Iframe chuẩn PhET** (LMS, Moodle, Canvas, Google Sites... nơi nào nhúng được mô phỏng PhET): lấy mã ở
https://motion-game-hub-web.web.app/embed (`web/embed.html`: chọn game, khung 800×600 / 960×540 / co giãn, bật tắt camera).
Mỗi game có link riêng như từng mô phỏng PhET:

| Game | Link |
| --- | --- |
| Cả bộ (hub) | `https://motion-game-hub-web.web.app/` |
| Fruits Kick | `https://motion-game-hub-web.web.app/?game=fruits-kick` |
| Egg Smasher | `https://motion-game-hub-web.web.app/?game=egg-smasher` |
| Goalkeeper Hero | `https://motion-game-hub-web.web.app/?game=goalkeeper-hero` |

```html
<iframe src="https://motion-game-hub-web.web.app/?game=fruits-kick" width="800" height="600" scrolling="no"
        title="Fruits Kick - Enspire Arcade" allow="camera; fullscreen; autoplay; gamepad" allowfullscreen></iframe>
```

- Link có `?game=`: hết splash hiện nút PLAY (cú chạm đầu tiên mở khoá âm thanh trên trình duyệt) rồi vào thẳng game;
  nút Back trong game vẫn về hub như thường (`lib/core/launch_game.dart`).
- Iframe PhET gốc không có `allow="camera"` => game tự chuyển chơi chạm / chuột và hiện nút "Mở tab mới" để chơi bằng camera.
- Có `allowfullscreen` thì hub hiện nút toàn màn hình (`lib/ui/widgets/fullscreen_button.dart`).

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
├── motion/          # Camera + AI (ML Kit, MediaPipe) và xử lý cử chỉ
├── services/        # Âm thanh (SoundService)
├── games/
│   ├── penalty_kick/     # Fruits Kick
│   ├── egg_smasher/      # Egg Smasher
│   └── goalkeeper_hero/  # Goalkeeper Hero (2 tay)
└── ui/
    ├── screens/     # Splash, menu chính, sảnh 2 tay
    └── widgets/     # UI phong cách trẻ em, Camera Setup, PiP, linh vật...
assets/
├── audio/           # Hiệu ứng âm thanh
├── words/           # Giọng đọc từ vựng (.mp3)
├── images/          # Logo, ảnh nền, linh vật
└── animations/      # Lottie splash
docs/                # Tài liệu thiết kế (kế hoạch game 2 tay)
```

> `lib/games/flappy_mouth` và `lib/games/sky_chomp` là game cũ, chưa có trên menu.
