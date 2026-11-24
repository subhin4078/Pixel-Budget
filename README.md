# 像素記帳 / Pixel Budget

An offline-first Flutter Android personal ledger and travel bill-splitting app crafted around bespoke pixel-art scenes, layered glassmorphic cards, pastel SVG iconography, and custom micro-interactions.

Flutter Android 本機離線記帳 App，結合像素插畫場景、分層玻璃卡片、粉彩 SVG 圖示與雙環圖表，提供個人帳本、分類統計與多幣別旅遊分帳。

---

## Download

Grab the latest signed Android APK from [**GitHub Releases**](https://github.com/subhin4078/Pixel-Budget/releases/latest).

---

## Design & Visual Highlights

- **Layered Pixel-Art Scenes (`ScenePage` + `CardBackdropHost`)**: Six custom-illustrated scenes (`assets/backgrounds/` & `assets/foregrounds/`) with a custom `RenderBox` compositing pipeline (`lib/shared/widgets/card_backdrop.dart`) so card glass tints render *behind* the character cutout while card typography and controls float *above* it.
- **Cohesive Dark-Lavender & Pastel Palette**: Built around deep twilight purple (`#29253F`), soft sakura pink (`#FF9EC6`), mint income accents (`#8ADBC8`), and lavender balance highlights (`#D9CBFF`), paired with **Fredoka** numerals and **jf open 粉圓** CJK typography.
- **100 Custom Pastel SVG Icons & 15 Animal Avatars**: Hand-crafted 24×24 vector icons (`assets/icons/`) across 10 themed groups, plus custom-drawn animal badges for trip members.
- **Dual-Ring Spending Chart (`CategoryRing`)**: Custom `CustomPainter` rendering an outer ring for spending purpose (*Self / For Others*) and an inner ring for categories with distinct collision-free colors.
- **Custom Amount Keypad & Gestures**: Dedicated tactile keypad (`AmountKeypad`), drag-and-drop category reordering within purpose groups, and swipe-to-delete with undo snacks.

---

## Features / 功能特色

- **Personal Ledger / 個人帳本**: Home dashboard showing monthly balance, today's spending, daily average, all-time net worth, total spending, recent activity log, and active trip shortcut.
- **Flexible Categories / 分類管理**: Add, edit, hide, or drag-reorder categories within *Self* / *For Others*; remembers separate last-used categories for expense and income.
- **Records & Statistics / 詳細與統計**: Daily grouped ledger list with filter switches and monthly dual-ring / single-ring visual breakdowns.
- **Multi-Currency Travel Splitting / 多幣別旅遊分帳**: Built-in `HKD`, `JPY`, `EUR`, `CNY`, `TWD`, `USD` plus custom currencies & symbols, per-trip default rates, per-entry rate overrides, fixed + equal split apportionment, and greedy integer-cent settlement suggestions.
- **Android Notification Shortcuts & CSV Backup / 通知快捷與 CSV 備份**: Persistent quick-entry notification bar (`Home`, `Income`, `Expense`) and streaming UTF-8 CSV export/import with duplicate detection and preview.

---

## Project Structure

| Path | Purpose |
|---|---|
| `lib/app` | App bootstrap, bottom navigation shell, SQLite schema/migrations, activity log, CSV backup & Android channels |
| `lib/ledger` | Personal ledger models, calculations, validation, repository & `ChangeNotifier` controller |
| `lib/travel` | Travel splitting models, integer-cent apportionment & settlement engine, validation & controller |
| `lib/features` | Home, Records, Entry Sheet & Category Editor, Statistics, Settings & Travel pages |
| `lib/shared` | Design tokens (`app_theme.dart`), layered scene renderer, `CardBackdropHost`, charts & keypad |
| `assets` | Scene backgrounds, character foregrounds, 150+ SVGs, bundled fonts & app icon master |
| `android` | Kotlin `MainActivity`, Storage Access Framework `CsvDocuments`, `NotificationShortcuts` & launcher resources |

---

## Build from Source

Requirements: **Flutter 3.x** (built & verified with Flutter `3.47.7` / Dart `3.13.5`, SDK `>=3.7.0 <4.0.0`) and **Android SDK**.

```bash
flutter pub get
flutter analyze
flutter run
flutter build apk --release
```

### Release Signing

To sign release builds with your own keystore, copy `android/key.properties.example` to `android/key.properties` (gitignored) and fill in your keystore credentials. If `android/key.properties` is absent, local `flutter build apk --release` falls back to Android debug signing for development convenience.

---

## Data & License

- **Local-First Privacy**: All data stays on-device in `pixel_budget.db` with `INTERNET` omitted from the release manifest and Android cloud backup / device-to-device transfer disabled (`allowBackup="false"` & `dataExtractionRules`). Export a UTF-8 CSV backup from Settings before uninstalling.
- **Copyright — Personal Use Only (`LICENSE`)**: Copyright (c) 2026 subhin. All Rights Reserved. Publicly shared as a design & engineering portfolio showcase for viewing and strictly private, non-commercial personal use only. **No commercial use, sale, copying, modification, reuse, or redistribution of any code, artwork, icons, or assets in any format is permitted.**
- **Third-Party Fonts**:
  - **jf open 粉圓**: SIL Open Font License 1.1 (`assets/fonts/JfOpenHuninn-OFL.txt`; Hanzi glyphs derived from Motoya Kosugi Maru under Apache License 2.0).
  - **Fredoka**: SIL Open Font License 1.1 (`assets/fonts/Fredoka-OFL.txt`).
