const { onCall } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
const admin = require("firebase-admin");
const axios = require("axios");

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = getFirestore();

// API Key (請確認此 Key 在 Google Cloud Console 有開啟 Places API 權限)
const GOOGLE_API_KEY = "AIzaSyBLBlabLgVT8jx-G-4tQ3fGzKvTELmoP1c";

// ★★★ 0. 定義統一白名單 (根據官方文件 Table 1 & 2) ★★★
// 只有這 7 個字是我們承認的「餐廳相關」類型，其他的都會被過濾掉
const UNIFIED_WHITELIST = [
  'restaurant',
  'cafe',
  'bakery',
  'bar',
  'meal_delivery',
  'meal_takeaway',
  'food'
];

// --- 距離計算 ---
function calculateDistance(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return 0;
  const R = 6371e3; 
  const p1 = lat1 * Math.PI / 180;
  const p2 = lat2 * Math.PI / 180;
  const dp = (lat2 - lat1) * Math.PI / 180;
  const dl = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dp / 2) * Math.sin(dp / 2) +
            Math.cos(p1) * Math.cos(p2) *
            Math.sin(dl / 2) * Math.sin(dl / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

// --- 圖片網址 ---
function getPhotoUrl(photoReference) {
  if (!photoReference) return "";
  return `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photoReference}&key=${GOOGLE_API_KEY}`;
}

// --- 主要功能：抓取餐廳 ---
exports.getRestaurants = onCall(async (request) => {
  if (!request.data || !request.data.lat || !request.data.lng) {
    throw new admin.functions.https.HttpsError('invalid-argument', "缺少座標參數");
  }

  const lat = Number(request.data.lat);
  const lng = Number(request.data.lng);

  // 1. 抓取餐廳
  const restaurantUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lng}&radius=1500&type=restaurant&key=${GOOGLE_API_KEY}&language=zh-TW`;
  
  // 2. 抓取捷運站
  const transitUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lng}&rankby=distance&type=subway_station&key=${GOOGLE_API_KEY}&language=zh-TW`;

  try {
    const [resResponse, transitResponse] = await Promise.all([
      axios.get(restaurantUrl),
      axios.get(transitUrl)
    ]);

    const rawResults = resResponse.data.results || [];
    const transitResults = transitResponse.data.results || [];
    const bestTransit = transitResults.length > 0 ? transitResults[0] : null;

    // ★★★ 白名單過濾邏輯 ★★★
    const processedResults = rawResults.map(place => {
      // (選擇性) 排除暫時關閉或永久停業的地點
      if (place.business_status !== 'OPERATIONAL') return null;

      const placeLat = place.geometry?.location?.lat;
      const placeLng = place.geometry?.location?.lng;
      const rawTypes = place.types || [];

      // 過濾邏輯：只留下白名單內的字
      // 例如：place 有 ['restaurant', 'point_of_interest'] -> 留下來 ['restaurant']
      const validTypes = rawTypes.filter(t => UNIFIED_WHITELIST.includes(t));

      // 檢查：如果過濾完是空的 (代表這家店完全不在我們的餐飲白名單內)，直接丟棄
      // 例如：牙醫診所只會有 ['dentist', 'health']，過濾完會變成 []，這裡就會 return null
      if (validTypes.length === 0) return null;

      // 計算距離
      let dist = calculateDistance(lat, lng, placeLat, placeLng);

      // 計算捷運距離
      let stationInfo = { name: "無鄰近捷運", distance: -1 };
      if (placeLat && placeLng && bestTransit) {
        const sDist = calculateDistance(
          placeLat, placeLng, 
          bestTransit.geometry.location.lat, 
          bestTransit.geometry.location.lng
        );
        stationInfo = { name: bestTransit.name, distance: sDist };
      }

      // 圖片處理
      const photoRef = (place.photos && place.photos.length > 0) ? place.photos[0].photo_reference : "";
      
      return {
        place_id: place.place_id,
        name: place.name,
        address: place.vicinity || place.formatted_address || "地址不詳",
        rating: place.rating || 0,
        rating_count: place.user_ratings_total || 0,
        types: validTypes, // ★ 這裡現在回傳的是乾淨的陣列，給前端自己判斷
        price_level: place.price_level || 0,
        distance: dist,
        station_info: stationInfo,
        photo_url: getPhotoUrl(photoRef), 
      };
    })
    .filter(item => item !== null); // ★ 移除所有 null (不合格) 的資料

    return processedResults;

  } catch (error) {
    console.error("API Error:", error);
    throw new admin.functions.https.HttpsError('internal', '無法取得資料', error.message);
  }
});

// --- 新增收藏 ---
exports.addFavorite = onCall(async (request) => {
  if (!request.auth) throw new admin.functions.https.HttpsError('unauthenticated', '請先登入');
  
  const uid = request.auth.uid;
  const restaurantData = request.data.restaurantData;

  return db.collection("users").doc(uid).collection("favorites").add({
    restaurantData: restaurantData,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});