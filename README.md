# ðŸ•¹ï¸ Motion Game Arcade Hub (Dá»± Ã¡n Game Äá»™c Láº­p)

Dá»± Ã¡n Flutter Ä‘á»™c láº­p hoÃ n toÃ n, káº¿ thá»«a Ã½ tÆ°á»Ÿng tá»« **Motion Touch** Ä‘á»ƒ xÃ¢y dá»±ng **Trung tÃ¢m trÃ² chÆ¡i tÆ°Æ¡ng tÃ¡c báº±ng cá»­ chá»‰ khuÃ´n máº·t qua camera trÆ°á»›c Ä‘iá»‡n thoáº¡i**.

ÄÆ°á»ng dáº«n dá»± Ã¡n: `d:\flutter_workspace\motion_game_hub`

---

## ðŸŒŸ Äiá»ƒm ná»•i báº­t & Kiáº¿n trÃºc Arcade Hub

- **Menu Chá»n Game (Arcade Launcher)**: Giao diá»‡n Cyberpunk Neon sá»‘ng Ä‘á»™ng, cho phÃ©p chá»n nhiá»u tá»±a game khÃ¡c nhau, lÆ°u ká»· lá»¥c (High Score) riÃªng tá»«ng game.
- **Shared Motion Engine (Camera + ML Kit Face Detection)**:
  - Khá»Ÿi táº¡o camera trÆ°á»›c má»™t láº§n, chia sáº» dá»¯ liá»‡u nháº­n diá»‡n cho má»i game.
  - Bá»™ lá»c **EMA Smoothing** chá»‘ng rung giáº­t camera.
  - Thuáº­t toÃ¡n **Hysteresis & Baseline Calibration** (cÃ¢n báº±ng tÆ° tháº¿ máº·t ngÆ°á»i chÆ¡i).
- **Cá»­a sá»• Camera PiP gÃ³c mÃ n hÃ¬nh**: Hiá»ƒn thá»‹ camera thá»±c táº¿, khung nháº­n diá»‡n máº·t, thÆ°á»›c Ä‘o gÃ³c nghiÃªng (Â°), thÆ°á»›c Ä‘o Ä‘á»™ hÃ¡ miá»‡ng (%) vÃ  FPS.
- **Cháº¿ Ä‘á»™ phÃ­m áº£o dá»± phÃ²ng**: Cho phÃ©p chÆ¡i báº±ng cáº£m á»©ng/phÃ­m áº£o báº¥t cá»© lÃºc nÃ o.

---

## ðŸŽ® Danh sÃ¡ch Game trong Arcade Hub

### 1. ðŸš€ Sky Chomp Hero (Endless Sky Runner)
- **CÃ¡ch Ä‘iá»u khiá»ƒn**:
  - **NghiÃªng Ä‘áº§u TrÃ¡i / Pháº£i**: LÆ°á»£n phi thuyá»n nÃ© thiÃªn tháº¡ch vÃ  chÆ°á»›ng ngáº¡i váº­t laser.
  - **HÃ¡ miá»‡ng tháº­t to "CHOMP!"**: Äá»›p sao â­, pizza ðŸ•, donut ðŸ©, tÃ­ch lÅ©y Ä‘iá»ƒm Combo x2, x3 vÃ  kÃ­ch hoáº¡t **FEVER MODE** báº¥t tá»­ hÃºt má»i váº­t pháº©m!

### 2. ðŸ¥ Flappy Mouth (Flappy Bird báº±ng cá»­ chá»‰ miá»‡ng)
- **CÃ¡ch Ä‘iá»u khiá»ƒn**:
  - **HÃ¡ miá»‡ng to**: ChÃº chim Ä‘áº­p cÃ¡nh bay vá»t lÃªn! Ngáº­m miá»‡ng Ä‘á»ƒ chÃº chim lÆ°á»£n háº¡ dáº§n theo trá»ng lá»±c.
  - **NghiÃªng Ä‘áº§u**: HÃ£m tá»‘c Ä‘á»™ hoáº·c tÄƒng tá»‘c lÆ°á»›t qua cÃ¡c khe háº¹p giá»¯a cÃ¡c cá»™t neon.

### 3. ðŸ‰ Fruit Tilt Catcher (Khung sáºµn sÃ ng má»Ÿ rá»™ng)
- Há»©ng trÃ¡i cÃ¢y báº±ng cÃ¡ch nghiÃªng Ä‘áº§u cÃ¢n báº±ng Ä‘Ä©a há»©ng.

---

## ðŸš€ HÆ°á»›ng dáº«n cháº¡y dá»± Ã¡n

Má»Ÿ terminal táº¡i thÆ° má»¥c dá»± Ã¡n má»›i:

```powershell
cd d:\flutter_workspace\motion_game_hub
flutter run
```

CÃ³ thá»ƒ cháº¡y trá»±c tiáº¿p trÃªn:
- **Thiáº¿t bá»‹ Android tháº­t** (Ä‘Ã£ cáº¥p quyá»n camera trÆ°á»›c)
- **Windows Desktop / Web** (cháº¡y cháº¿ Ä‘á»™ phÃ­m áº£o / simulator)
