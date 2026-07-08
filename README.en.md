[繁體中文](./README.md) | **English**

# Restaurant Swipe App — 美食刷刷卡

> 📅 Project started: 2026-01

A food-discovery application built on **Flutter + Firebase**. The core feature lets users browse nearby restaurants by **swiping cards left and right**, with support for login, saving restaurants, and viewing details.

---

## ✨ Features

- 🗺️ Fetch nearby restaurants centered on your current geographic location
- 💘 Tinder-style left/right swipe to quickly decide "want to eat / skip"
- 🔐 Google account login, syncing preferences across devices
- ⭐ Saved list and restaurant detail information
- 🏷️ Filter by tags, price, and business hours

---

## 🧱 Tech stack

| Item | Details |
|---|---|
| Frontend | Flutter (multi-platform: iOS / Android / Web / Windows / macOS / Linux) |
| Backend | Firebase Cloud Functions |
| Database | Firestore |
| Login | Google Sign-In |
| Restaurant data | Google Places API |

---

## 📂 Project structure

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

## 🚀 Local startup

```bash
cd my_tinder_app
flutter pub get
flutter run
```

You'll need to complete the Firebase project setup first (`firebase.json`, `google-services.json` / `GoogleService-Info.plist`) and enable the Places API.

---

## 📝 To-do

See `my_tinder_app/update.md`.

---

## 📄 License

Personal project, not yet publicly released.
