// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

import 'firebase_options.dart'; // 記得保留這個檔案
import 'login_page.dart';
import 'swipe_page.dart';
import 'favorites_page.dart';

// --- 全域輔助函式：讓其他檔案也能呼叫 ---
String getDisplayImageUrl(String? url) {
  if (url == null || url.isEmpty) return "";
  if (kIsWeb) {
    return "https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}";
  }
  return url;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await GoogleSignIn.instance.initialize(
    serverClientId:
        "360527594852-3hf9ug9mf4mnd22qn2h1ahasnpcofll7.apps.googleusercontent.com",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '今天吃什麼？',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
          secondary: Colors.deepOrangeAccent,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF7F0),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const MyHomePage(title: '🔥 今天想吃什麼？'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  User? currentUser;
  List<Map<String, dynamic>> restaurants = [];
  List<Map<String, dynamic>> _allRestaurants = [];
  bool isLoading = true;
  String? errorMessage;
  StreamSubscription<Position>? _positionStreamSubscription;
  int _filterPriceLevel = -1; // -1: 不限, 1: $, 2: $$, 3: $$$, 4: $$$$
  bool _filterOpenNow = false; // false: 顯示全部, true: 只顯示營業中

  // 初始化
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // --- 邏輯區 ---

  Future<void> _checkLoginStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => currentUser = user);
      _fetchRealRestaurants();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchRealRestaurants() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception("需要定位權限");
      }
      if (permission == LocationPermission.deniedForever)
        throw Exception("定位權限被永久拒絕");

      Position pos = await Geolocator.getCurrentPosition();
      print("準備傳送座標 -> lat: ${pos.latitude}, lng: ${pos.longitude}");
      final result = await FirebaseFunctions.instance
          .httpsCallable('getRestaurants')
          .call({"lat": pos.latitude, "lng": pos.longitude});

      final List<dynamic> fetchedData = result.data;

      if (mounted) {
        setState(() {
          _allRestaurants = fetchedData.map((item) {
            final station = item['station_info'] ?? {};
            bool isOpen = false;
            if (item['opening_hours'] != null && item['opening_hours'] is Map) {
              isOpen = item['opening_hours']['open_now'] ?? false;
            }
            return {
              "id": item['place_id']?.toString() ?? '',
              "name": item['name']?.toString() ?? '未知餐廳',
              "address": item['address']?.toString() ?? '地址載入中...',
              "dist": "${item['distance'] ?? 0}",
              "rate": "${item['rating'] ?? 0.0}",
              "rating_count": "${item['rating_count'] ?? 0}",
              "price_level": item['price_level'] is int
                  ? item['price_level']
                  : int.tryParse(item['price_level']?.toString() ?? '0') ?? 0,
              "types": item['types']?.toString() ?? 'restaurant',
              "photo_url": item['photo_url']?.toString() ?? "",
              "station_name": station['name']?.toString() ?? '無捷運',
              "station_dist": station['distance']?.toString() ?? '-1',
              "open_now": isOpen,
            };
          }).toList();
          _applyFilter();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("抓取失敗：$e");
      if (mounted)
        setState(() {
          isLoading = false;
          errorMessage = "發生錯誤或無權限";
        });
    }
  }

  void _applyFilter() {
    setState(() {
      restaurants = _allRestaurants.where((res) {
        // A. 價格篩選
        int price = res['price_level'] as int;
        bool priceMatch = _filterPriceLevel == -1 || price == _filterPriceLevel;

        // B. 營業時間篩選
        bool isOpen = res['open_now'] == true;
        bool openMatch = !_filterOpenNow || isOpen;

        return priceMatch && openMatch;
      }).toList();
    });
  }

  // --- 登入/登出/收藏 ---

  Future<void> _handleGuestSignIn() async {
    setState(() => isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      setState(() => currentUser = cred.user);
      _fetchRealRestaurants();
    } catch (e) {
      print("❌ 訪客登入失敗原因：$e");
      setState(() {
        isLoading = false;
        errorMessage = "登入失敗";
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);
    try {
      final GoogleSignInAccount user = await GoogleSignIn.instance
          .authenticate();
      final GoogleSignInAuthentication auth = await user.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: null,
        idToken: auth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      setState(() {
        currentUser = userCred.user;
        _fetchRealRestaurants();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "登入取消或失敗";
      });
    }
  }

  Future<void> _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    setState(() {
      currentUser = null;
      restaurants = [];
      _allRestaurants = [];
    });
  }

  Future<void> _saveToCloud(Map<String, dynamic> restaurant) async {
    if (currentUser == null) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('addFavorite').call({
        "restaurantData": restaurant,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("已收藏：${restaurant['name']}"),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.pinkAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("儲存失敗：$e");
    }
  }

  void _startLocationUpdates() {
    const s = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 500,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: s).listen((p) {
          if (currentUser != null) _fetchRealRestaurants();
        });
  }

  // --- UI 建構 ---

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            if (currentUser != null) ...[
              ListTile(
                leading: const Icon(Icons.person, color: Colors.orange),
                title: Text(currentUser!.displayName ?? "訪客"),
                subtitle: Text(currentUser!.email ?? "匿名"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("登出", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSignOut();
                },
              ),
            ] else ...[
              const Text(
                "尚未登入",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleGoogleSignIn();
                  },
                  icon: const Icon(Icons.login),
                  label: const Text("Google 登入"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleGuestSignIn();
                  },
                  child: const Text("訪客模式"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 篩選列 UI ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFFFF7F0), // 背景色配合你的主題
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右撐開
        children: [
          // === 左邊：價格下拉選單 ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.orange.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _filterPriceLevel,
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.deepOrange,
                ),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                items: const [
                  DropdownMenuItem(value: -1, child: Text("💰 價格不限")),
                  DropdownMenuItem(value: 1, child: Text("💰 便宜 (\$ )")),
                  DropdownMenuItem(value: 2, child: Text("💰 適中 (\$\$ )")),
                  DropdownMenuItem(value: 3, child: Text("💰 稍貴 (\$\$\$ )")),
                  DropdownMenuItem(value: 4, child: Text("💰 高級 (\$\$\$\$)")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _filterPriceLevel = val;
                      _applyFilter();
                    });
                  }
                },
              ),
            ),
          ),

          // === 右邊：營業中開關按鈕 (亮/暗模式) ===
          InkWell(
            onTap: () {
              setState(() {
                _filterOpenNow = !_filterOpenNow; // 切換狀態
                _applyFilter();
              });
            },
            borderRadius: BorderRadius.circular(30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                // 亮案形式：開啟變橘色，關閉變灰色
                color: _filterOpenNow ? Colors.orange : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  if (_filterOpenNow) // 只有亮起時才有陰影
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 18,
                    color: _filterOpenNow ? Colors.white : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _filterOpenNow ? "營業中" : "非營業時間",
                    style: TextStyle(
                      color: _filterOpenNow
                          ? Colors.white
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.grey),
          onPressed: _showSettingsPanel,
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_rounded, color: Colors.orange),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (currentUser != null) _buildFilterBar(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : currentUser == null
                // 檔案 2: 登入頁
                ? LoginPage(
                    onGoogleSignIn: _handleGoogleSignIn,
                    onGuestSignIn: _handleGuestSignIn,
                    errorMessage: errorMessage,
                  )
                // 檔案 3: 滑卡頁
                : SwipePage(
                    key: ValueKey(
                      "$_filterPriceLevel|$_filterOpenNow|${restaurants.length}",
                    ),
                    restaurants: restaurants,
                    onSwipeRight: _saveToCloud,
                    // ❌ 移除了 currentFilter 和 onFilterChanged
                  ),
          ),
        ],
      ),
    );
  }
}
