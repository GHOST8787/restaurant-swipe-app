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

    const results = resResponse.data.results || [];
    const transitResults = transitResponse.data.results || [];

    // 找最近的一個捷運站
    const bestTransit = transitResults.length > 0 ? transitResults[0] : null;

    return results.map(place => {
      const placeLat = place.geometry?.location?.lat;
      const placeLng = place.geometry?.location?.lng;

      // 過濾雜亂類別
      const genericTypes = ['point_of_interest', 'establishment', 'food', 'restaurant', 'store'];
      const specificTypes = (place.types || []).filter(t => !genericTypes.includes(t));
      const displayType = specificTypes.length > 0 ? specificTypes[0] : 'restaurant';

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
        address: place.vicinity || place.formatted_address || "地址不詳", // ★ 新增地址欄位
        rating: place.rating || 0,
        types: displayType, 
        price_level: place.price_level || 0,
        distance: dist,
        station_info: stationInfo,
        photo_url: getPhotoUrl(photoRef), 
      };
    });
  } catch (error) {
    console.error("API Error:", error);
    throw new admin.functions.https.HttpsError('internal', '無法取得資料', error.message);
  }
});

// --- 新增收藏 ---
exports.addFavorite = onCall(async (request) => {
  // 移除強制登入檢查，允許匿名使用者收藏 (或者前端控制)
  // 但為了安全，最好還是檢查 request.auth，只是前端我們會讓訪客也能拿到 auth
  if (!request.auth) throw new admin.functions.https.HttpsError('unauthenticated', '請先登入');
  
  const uid = request.auth.uid;
  const restaurantData = request.data.restaurantData;

  return db.collection("users").doc(uid).collection("favorites").add({
    restaurantData: restaurantData,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});