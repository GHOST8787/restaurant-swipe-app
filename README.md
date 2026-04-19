# Restaurant Swipe App — 美食刷刷卡

> 📅 專案開始：2026-01

基於 **Flutter + Firebase** 的美食探索應用程式。核心功能是讓使用者透過**左右滑動卡片**的方式瀏覽附近的餐廳，並支援登入、收藏餐廳、查看詳情。

---

## ✨ 功能

- 🗺️ 以目前地理位置為中心，抓取附近餐廳
- 💘 Tinder 式左右滑卡，快速決定「想吃／跳過」
- 🔐 Google 帳號登入，跨裝置同步喜好
- ⭐ 收藏清單與餐廳詳細資訊
- 🏷️ 依標籤、價格、營業時間進行篩選

---

## 🧱 技術棧

| 項目 | 說明 |
|---|---|
| 前端 | Flutter（多平台：iOS / Android / Web / Windows / macOS / Linux） |
| 後端 | Firebase Cloud Functions |
| 資料庫 | Firestore |
| 登入 | Google Sign-In |
| 餐廳資料 | Google Places API |

---

## 📂 專案結構

```
restaurant-swipe-app/
└── my_tinder_app/          ← Flutter 主專案（名稱沿用初始模板）
    ├── lib/
    │   └── main.dart       ← 入口：初始化 Firebase、管理登入、主畫面
    ├── functions/          ← Firebase Cloud Functions
    ├── android/ / ios/ / web/ / linux/ / macos/ / windows/
    ├── pubspec.yaml
    └── firebase.json
```

---

## 🚀 本地啟動

```bash
cd my_tinder_app
flutter pub get
flutter run
```

需要先完成 Firebase 專案設定（`firebase.json`、`google-services.json` / `GoogleService-Info.plist`）並啟用 Places API。

---

## 📝 待辦事項

見 `my_tinder_app/update.md`。

---

## 📄 授權

個人專案，目前未對外發佈。
