// 引入 V2 版本的 onCall
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// === 設定區 ===
const CACHE_RADIUS_KM = 0.5; // 500公尺內的快取
const CACHE_DURATION_MS = 7 * 24 * 60 * 60 * 1000; // 7天過期

// ★★★ 請填入你那組正確的、沒有 BLabL 的 API Key ★★★
const GOOGLE_API_KEY = "AIzaSyBLBlabLgVT8jx-G-4tQ3fGzKvTELmoP1c"; 

// === 輔助函式：計算距離 ===
function getDistanceFromLatLonInKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // 地球半徑 (公里)
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    // ★★★ 數學公式修正：確保距離計算準確 ★★★
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function deg2rad(deg) { return deg * (Math.PI / 180); }

// === 主程式 ===
exports.getRestaurants = onCall(async (request) => {
  // 1. 接收手機傳來的座標 (V2 格式)
  const data = request.data;
  
  if (!data) {
      throw new HttpsError('invalid-argument', "收到空資料");
  }

  const userLat = data.lat;
  const userLng = data.lng;

  console.log(`📡 [V2] 收到請求: Lat ${userLat}, Lng ${userLng}`);

  if (!userLat || !userLng) {
    throw new HttpsError('invalid-argument', `缺少座標。Lat: ${userLat}, Lng: ${userLng}`);
  }

  const db = admin.firestore();
  const cacheRef = db.collection('places_cache');

  try {
    // --------------------------------------------------
    // 步驟 1：先檢查資料庫有沒有快取 (省錢策略)
    // --------------------------------------------------
    const latMin = userLat - 0.01;
    const latMax = userLat + 0.01;
    
    const snapshot = await cacheRef
      .where('lat', '>=', latMin)
      .where('lat', '<=', latMax)
      .get();

    let validCache = null;

    snapshot.forEach(doc => {
      const cacheData = doc.data();
      const now = Date.now();
      
      // 檢查是否過期
      if (now - cacheData.timestamp.toMillis() < CACHE_DURATION_MS) {
        const dist = getDistanceFromLatLonInKm(userLat, userLng, cacheData.lat, cacheData.lng);
        // 檢查距離是否夠近
        if (dist <= CACHE_RADIUS_KM) {
           if (cacheData.results && cacheData.results.length >= 10) {
             validCache = cacheData.results;
           }
        }
      }
    });

    if (validCache) {
      console.log(`✅ 命中快取！回傳 ${validCache.length} 筆資料`);
      return validCache; // 如果有快取，直接回傳，不扣 API 次數
    }

    // --------------------------------------------------
    // 步驟 2：沒快取，向 Google 查詢餐廳與捷運站
    // --------------------------------------------------
    console.log("🚀 快取未命中，呼叫 Google API...");
    
    const resUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${userLat},${userLng}&radius=1500&type=restaurant&language=zh-TW&key=${GOOGLE_API_KEY}`;
    const transitUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${userLat},${userLng}&radius=2000&type=subway_station&language=zh-TW&key=${GOOGLE_API_KEY}`;

    // 同時發送請求，加快速度
    const [resResponse, transitResponse] = await Promise.all([
       axios.get(resUrl),
       axios.get(transitUrl)
    ]);

    const allRawRestaurants = resResponse.data.results || [];
    const nearbyStations = transitResponse.data.results || [];

    // --------------------------------------------------
    // 步驟 3：整理資料 (計算捷運距離)
    // --------------------------------------------------
    // 這一大段就是你要的「先整理好資料」
    const finalResults = allRawRestaurants.map(place => {
       const photoUrl = (place.photos && place.photos.length > 0) 
        ? `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${place.photos[0].photo_reference}&key=${GOOGLE_API_KEY}`
        : "";

       // ★ 找出這間餐廳離哪個捷運站最近 ★
       let bestStation = { name: "無鄰近捷運", distance: -1 };
       let minStationDist = 999999;
       
       if (nearbyStations.length > 0) {
          const pLat = place.geometry.location.lat;
          const pLng = place.geometry.location.lng;
          nearbyStations.forEach(station => {
             // 算出餐廳與捷運站的距離
             const sDist = Math.round(getDistanceFromLatLonInKm(pLat, pLng, station.geometry.location.lat, station.geometry.location.lng) * 1000);
             if (sDist < minStationDist) {
                minStationDist = sDist;
                bestStation = { name: station.name, distance: sDist };
             }
          });
       }
       
       // 算出餐廳與使用者的距離
       const userDist = Math.round(getDistanceFromLatLonInKm(userLat, userLng, place.geometry.location.lat, place.geometry.location.lng) * 1000);

       // 回傳整理好的物件
       return {
        place_id: place.place_id,
        name: place.name,
        address: place.vicinity || place.formatted_address || "地址不詳",
        lat: place.geometry.location.lat,
        lng: place.geometry.location.lng,
        rating: place.rating || 0.0,
        rating_count: place.user_ratings_total || 0,
        price_level: place.price_level || 1,
        photo_url: photoUrl,
        open_now: place.opening_hours ? place.opening_hours.open_now : false,
        types: place.types || [],
        distance: userDist,
        station_info: bestStation // ★ 這裡包含了捷運站距離，等一下會一起存
       };
    });

    // --------------------------------------------------
    // 步驟 4：存入資料庫 (這步會很快，必須 await 以免資料遺失)
    // --------------------------------------------------
    if (finalResults.length > 0) {
      await cacheRef.add({
        lat: userLat,
        lng: userLng,
        timestamp: admin.firestore.Timestamp.now(),
        results: finalResults // 這份資料裡已經包含 station_info 了
      });
      console.log(`💾 寫入快取完成: ${finalResults.length} 筆`);
    }

    // --------------------------------------------------
    // 步驟 5：回傳資料給手機
    // --------------------------------------------------
    return finalResults;

  } catch (error) {
    // 安全的錯誤處理，避免後端崩潰
    if (error.response) {
        console.error("🔥 Google API 拒絕連線:", JSON.stringify(error.response.data));
    } else {
        console.error("🔥 系統錯誤:", error.message);
    }
    throw new HttpsError('internal', `後端錯誤: ${error.message}`);
  }
});