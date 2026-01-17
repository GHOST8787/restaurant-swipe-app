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

  // ★★★ 初始化 Google Sign In (Android 需要 serverClientId) ★★★
  // 請填入你的 Web Client ID
  // await GoogleSignIn.instance.initialize(serverClientId: "YOUR_WEB_CLIENT_ID");

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
  String _selectedFilter = 'all';

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
      final result = await FirebaseFunctions.instance
          .httpsCallable('getRestaurants')
          .call({"lat": pos.latitude, "lng": pos.longitude});

      final List<dynamic> fetchedData = result.data;

      if (mounted) {
        setState(() {
          _allRestaurants = fetchedData.map((item) {
            // 資料整理邏輯保持不變
            final station = item['station_info'] ?? {};
            return {
              "id": item['place_id']?.toString() ?? '',
              "name": item['name']?.toString() ?? '未知餐廳',
              "address": item['address']?.toString() ?? '地址載入中...',
              "dist": "${item['distance'] ?? 0}",
              "rate": "${item['rating'] ?? 0.0}",
              "rating_count": "${item['rating_count'] ?? 0}",
              "price_level": "${item['price_level'] ?? 0}",
              "types": item['types']?.toString() ?? 'restaurant',
              "photo_url": item['photo_url']?.toString() ?? "",
              "station_name": station['name']?.toString() ?? '無捷運',
              "station_dist": station['distance']?.toString() ?? '-1',
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
    if (_selectedFilter == 'all') {
      restaurants = List.from(_allRestaurants);
    } else {
      restaurants = _allRestaurants
          .where((res) => res['types'] == _selectedFilter)
          .toList();
    }
  }

  // --- 登入/登出/收藏 ---

  Future<void> _handleGuestSignIn() async {
    setState(() => isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      setState(() => currentUser = cred.user);
      _fetchRealRestaurants();
    } catch (e) {
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
                    restaurants: restaurants,
                    onSwipeRight: _saveToCloud,
                    currentFilter: _selectedFilter,
                    onFilterChanged: (val) {
                      setState(() {
                        _selectedFilter = val;
                        _applyFilter();
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
