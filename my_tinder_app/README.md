# my_tinder_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


這個專案是一個基於 Flutter 和 Firebase 的美食探索應用程式，它的核心功能是讓使用者透過左右滑動卡片的方式來瀏覽附近的餐廳，並支援登入、收藏餐廳、以及查看餐廳詳情。

以下是這個專案中每個檔案的主要功能與它們之間的關聯：

1. **`main.dart`**：
* 這是整個應用程式的入口點（Entry Point）。
* 負責初始化 Firebase 和 Google 登入服務。
* 管理應用程式的全域主題（Theme）和導航。
* **核心功能**：它包含了主畫面 (`MyHomePage`) 的邏輯，負責處理使用者登入狀態、獲取地理位置、呼叫後端 API (`getRestaurants`) 來抓取餐廳資料，以及處理篩選器（價格、營業時間）的邏輯。
* 它會根據使用者的登入狀態，決定顯示「登入頁面」(`LoginPage`) 還是「滑動卡片頁面」(`SwipePage`)。


2. **`login_page.dart`**：
* 這是一個單純的 UI 頁面，負責顯示登入介面。
* 提供「Google 帳號登入」和「訪客模式」兩個按鈕。
* 當使用者點擊按鈕時，它會呼叫 `main.dart` 傳進來的回呼函式（Callback）來執行實際的登入動作。


3. **`swipe_page.dart`**：
* 這是使用者登入後的主要互動介面。
* 它使用 `flutter_card_swiper` 套件來展示餐廳卡片。
* **卡片設計**：定義了 `_RestaurantCard`，負責將單筆餐廳資料轉換成漂亮的卡片，顯示圖片、名稱、價格等級、評分、距離以及是否營業中。
* **互動邏輯**：處理使用者的滑動手勢（左滑略過、右滑收藏）。當使用者右滑時，它會觸發收藏功能。


4. **`restaurant_detail_page.dart`**：
* 這是餐廳的詳細資訊頁面。
* 當使用者點擊卡片或收藏列表中的項目時，會跳轉到這一頁。
* 它顯示更完整的資訊，包括大張圖片、詳細評分（包含評論數）、地址、以及捷運站資訊。
* **特色功能**：提供一個可點擊的地址按鈕，點擊後會呼叫 `url_launcher` 開啟外部的 Google Maps 應用程式進行導航。


5. **`favorites_page.dart`**：
* 這是使用者的「我的最愛」列表頁面。
* 它從 Firebase Firestore 資料庫即時讀取使用者收藏的餐廳資料。
* **篩選功能**：這個頁面也實作了與主畫面相同的篩選器（價格、營業時間），讓使用者可以過濾自己的收藏清單。
* 支援滑動刪除（Dismissible）功能，讓使用者可以移除收藏。


6. **`index.js` (Firebase Cloud Functions)**：
* 這是後端的程式碼，運行在 Google 的伺服器上。
* **API 串接**：它負責接收前端傳來的經緯度，然後呼叫 Google Maps Platform 的 Nearby Search API 來尋找附近的餐廳。
* **快取機制 (Cache)**：這是這個檔案最重要的地方。為了節省 Google API 的呼叫費用，它實作了一個快取機制。當使用者查詢某個地點時，它會先檢查 Firestore 資料庫有沒有「附近且未過期」的舊資料。如果有就直接回傳（免費）；如果沒有，才真的去呼叫 Google API（付費），並將結果存入資料庫以供下次使用。
* **資料清洗**：它會把 Google 回傳的複雜資料整理成前端需要的簡單格式（只保留名稱、評分、照片網址等），減少傳輸量。



**總結來說：**
使用者打開 App (`main.dart`) -> 登入 (`login_page.dart`) -> App 取得定位並呼叫後端 (`index.js`) -> 後端檢查快取或抓取 Google 資料並回傳 -> 前端顯示卡片 (`swipe_page.dart`) -> 使用者右滑收藏 -> 資料存入 Firestore -> 使用者可在收藏頁查看 (`favorites_page.dart`) -> 點擊查看詳情並導航 (`restaurant_detail_page.dart`)。