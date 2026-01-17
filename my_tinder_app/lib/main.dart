import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

String _getDisplayImageUrl(String? url) {
  if (url == null || url.isEmpty) return "";
  if (kIsWeb)
    return "https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}";
  return url;
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
  List<Map<String, dynamic>> _displayRestaurants = [];
  bool isLoading = true;
  String? errorMessage;
  StreamSubscription<Position>? _positionStreamSubscription;
  final CardSwiperController controller = CardSwiperController();
  String _selectedFilter = 'all';

  final Map<String, String> categoryOptions = {
    'all': '全部餐廳',
    'restaurant': '精選餐廳',
    'cafe': '咖啡廳',
    'bakery': '烘焙坊',
    'bar': '酒吧',
    'meal_takeaway': '外帶美食',
    'meal_delivery': '外送美食',
    'food': '一般美食',
  };

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 依內容高度調整
            children: [
              // 1. 頂部灰色橫條
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 2. 判斷登入狀態
              if (currentUser != null) ...[
                // =================================
                // 狀態 A：已登入 (顯示頭像 + 登出)
                // =================================
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: currentUser!.photoURL != null
                        ? NetworkImage(currentUser!.photoURL!)
                        : null,
                    backgroundColor: Colors.orange.shade100,
                    child: currentUser!.photoURL == null
                        ? const Icon(Icons.person, color: Colors.orange)
                        : null,
                  ),
                  title: Text(
                    currentUser!.displayName ?? "訪客使用者",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(currentUser!.email ?? "匿名登入"),
                ),
                const Divider(height: 30),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.red),
                  ),
                  title: const Text(
                    "登出帳號",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // 關閉選單
                    _handleSignOut(); // 執行登出
                  },
                ),
              ] else ...[
                // =================================
                // 狀態 B：未登入 (補回消失的按鈕！)
                // =================================
                // 1. Google 登入按鈕 (如果要用的話)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleGoogleSignIn();
                    },
                    icon: const Icon(Icons.login),
                    label: const Text("Google 帳號登入"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. ★★★ 訪客登入按鈕 (補在這裡！) ★★★
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // 點擊後先關閉選單
                      _handleGuestSignIn(); // 再執行登入
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text(
                      "先隨便逛逛 (訪客模式)",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. 建立 GoogleSignIn 實體
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      // 2. 觸發登入流程 (會跳出視窗)
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      // 3. 取得驗證資料 (Access Token & ID Token)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 4. 建立 Firebase 憑證
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );

      // 5. 正式登入 Firebase
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // 6. 更新狀態
      setState(() {
        currentUser = userCredential.user;
        // 登入成功後，立刻重新抓取一次資料 (因為可能有專屬推薦或權限)
        _fetchRealRestaurants();
      });
    } catch (e) {
      debugPrint("Google 登入失敗：$e");
      setState(() {
        isLoading = false;
        errorMessage = "登入失敗，請稍後再試";
      });
    }
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 500,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position? position) {
            if (position != null) {
              debugPrint("偵測到位置移動，重新抓取餐廳...");
              if (currentUser != null) _fetchRealRestaurants();
            }
          },
        );
  }

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

  Future<void> _initApp() async => await _checkLoginStatus();

  Future<void> _checkLoginStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => currentUser = user);
      _fetchRealRestaurants();
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      setState(() => currentUser = userCredential.user);
      await _fetchRealRestaurants();
    } catch (e) {
      debugPrint("訪客登入失敗：$e");
      setState(() {
        isLoading = false;
        errorMessage = "訪客登入失敗";
      });
    }
  }

  Future<void> _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      currentUser = null;
      restaurants = [];
      errorMessage = null;
    });
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
        if (permission == LocationPermission.denied)
          throw Exception("需要定位權限才能尋找附近餐廳");
      }
      if (permission == LocationPermission.deniedForever)
        throw Exception("定位權限被永久拒絕，請至設定開啟");

      Position pos = await Geolocator.getCurrentPosition();
      final result = await FirebaseFunctions.instance
          .httpsCallable('getRestaurants')
          .call({"lat": pos.latitude, "lng": pos.longitude});
      final List<dynamic> fetchedData = result.data;

      if (mounted) {
        setState(() {
          _allRestaurants = fetchedData.map((item) {
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
          errorMessage = "發生錯誤，請檢查網路或定位權限";
        });
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'all') {
      _displayRestaurants = List.from(_allRestaurants);
    } else {
      _displayRestaurants = _allRestaurants
          .where((res) => res['types'] == _selectedFilter)
          .toList();
    }
    restaurants = List.from(_displayRestaurants);
  }

  Widget _buildFilterDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: categoryOptions.containsKey(_selectedFilter)
              ? _selectedFilter
              : 'all',
          icon: const Icon(Icons.filter_list_rounded, color: Colors.orange),
          isExpanded: true,
          items: categoryOptions.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: TextStyle(
                  color: _selectedFilter == entry.key
                      ? Colors.orange.shade800
                      : Colors.black87,
                  fontWeight: _selectedFilter == entry.key
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null)
              setState(() {
                _selectedFilter = newValue;
                _applyFilter();
              });
          },
        ),
      ),
    );
  }

  Widget _buildBody(double cardWidth, double cardHeight) {
    if (isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ramen_dining, size: 100, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              "選擇困難症救星",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const Text(
              "不用想了，滑就對了！",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 50),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              height: 50,
              child: OutlinedButton(
                onPressed: _handleGuestSignIn,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                ),
                child: const Text(
                  "先隨便逛逛 (訪客模式)",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: CardSwiper(
          controller: controller,
          cardsCount: restaurants.length,
          numberOfCardsDisplayed: restaurants.length < 3
              ? restaurants.length
              : 3,
          backCardOffset: const Offset(0, 40),
          padding: EdgeInsets.zero,
          isLoop: false,
          onSwipe: (prev, curr, dir) {
            if (dir == CardSwiperDirection.right)
              _saveToCloud(restaurants[prev]);
            return true;
          },
          cardBuilder: (context, index, _, __) =>
              _RestaurantCard(data: restaurants[index]),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth > 600 ? 400 : screenWidth * 0.9;
    double cardHeight = MediaQuery.of(context).size.height * 0.7;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.settings_rounded,
            color: Colors.grey,
            size: 26,
          ),
          onPressed: _showSettingsPanel,
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bookmark_rounded,
              color: Colors.orange,
              size: 28,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (currentUser != null && !isLoading && _allRestaurants.isNotEmpty)
            _buildFilterDropdown(),
          const SizedBox(height: 10),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : restaurants.isEmpty
                ? const Center(child: Text("附近找不到符合的餐廳 T_T"))
                : Center(
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: CardSwiper(
                        controller: controller,
                        cardsCount: restaurants.length,
                        numberOfCardsDisplayed: (restaurants.length >= 3)
                            ? 3
                            : restaurants.length,
                        backCardOffset: const Offset(0, 40),
                        padding: EdgeInsets.zero,
                        onSwipe: (prev, curr, dir) {
                          if (dir == CardSwiperDirection.right)
                            _saveToCloud(restaurants[prev]);
                          return true;
                        },
                        cardBuilder: (context, index, _, __) =>
                            _RestaurantCard(data: restaurants[index]),
                      ),
                    ),
                  ),
          ),
          if (!isLoading &&
              currentUser != null &&
              _displayRestaurants.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(
                    Icons.close_rounded,
                    Colors.grey.shade400,
                    Colors.white,
                    () => controller.swipe(CardSwiperDirection.left),
                  ),
                  _actionButton(
                    Icons.favorite_rounded,
                    Colors.pinkAccent,
                    Colors.white,
                    () => controller.swipe(CardSwiperDirection.right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    Color iconColor,
    Color bgColor,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.large(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor: bgColor,
        elevation: 0,
        shape: const CircleBorder(),
        child: Icon(icon, color: iconColor, size: 40),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RestaurantCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final String imageUrl = _getDisplayImageUrl(data['photo_url']);
    final Map<String, String> typeTrans = {
      'restaurant': '精選餐廳',
      'cafe': '咖啡廳',
      'bakery': '烘焙甜點',
      'bar': '酒吧',
      'meal_takeaway': '外帶服務',
      'meal_delivery': '外送服務',
      'food': '美食',
    };
    List<String> types = [];
    if (data['types'] is List) {
      types = List<String>.from(data['types']);
    } else {
      types = [data['types']?.toString() ?? 'restaurant'];
    }
    String rawType = types.isNotEmpty ? types[0] : 'restaurant';
    String category = typeTrans[rawType] ?? '餐廳';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        loadingBuilder: (ctx, child, loadingProgress) =>
                            loadingProgress == null
                            ? child
                            : _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${data['dist']}m",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            "\$" * (int.tryParse(data['price_level']) ?? 1),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(color: Colors.grey.shade200, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 26,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${data['rate']}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (data['station_dist'] != '-1')
                        Row(
                          children: [
                            Icon(
                              Icons.directions_subway_rounded,
                              color: Colors.blue.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${data['station_name']} (${data['station_dist']}m)",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              "暫無圖片",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _selectedFilter = 'all';
  final Map<String, String> categoryOptions = {
    'all': '全部餐廳',
    'restaurant': '精選餐廳',
    'cafe': '咖啡廳',
    'bakery': '烘焙坊',
    'bar': '酒吧',
    'meal_takeaway': '外帶美食',
    'meal_delivery': '外送美食',
    'food': '一般美食',
  };

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return Scaffold(
        appBar: AppBar(title: const Text("收藏清單")),
        body: const Center(child: Text("請先登入")),
      );
    final favoritesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites');

    return Scaffold(
      appBar: AppBar(
        title: const Text("💖 我的最愛"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categoryOptions.containsKey(_selectedFilter)
                      ? _selectedFilter
                      : 'all',
                  isExpanded: true,
                  icon: const Icon(Icons.filter_list, color: Colors.grey),
                  items: categoryOptions.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => val != null
                      ? setState(() => _selectedFilter = val)
                      : null,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: favoritesRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("讀取錯誤"));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final allDocs = snapshot.data!.docs;
                if (allDocs.isEmpty)
                  return const Center(child: Text("還沒有收藏任何餐廳喔"));

                final filteredDocs = allDocs.where((doc) {
                  if (_selectedFilter == 'all') return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final res = data['restaurantData'] ?? {};
                  final type = res['types']?.toString() ?? 'restaurant';
                  return type == _selectedFilter;
                }).toList();

                if (filteredDocs.isEmpty)
                  return Center(
                    child: Text(
                      "沒有「${categoryOptions[_selectedFilter]}」類型的收藏",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    final res = data['restaurantData'] ?? {};
                    final imageUrl = _getDisplayImageUrl(res['photo_url']);
                    return Dismissible(
                      key: Key(filteredDocs[index].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      onDismissed: (_) =>
                          favoritesRef.doc(filteredDocs[index].id).delete(),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade100,
                            child: imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : const Icon(
                                    Icons.restaurant,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                        title: Text(
                          res['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${res['rate']} ★ · ${categoryOptions[res['types']] ?? res['types']}",
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RestaurantDetailPage(resData: res),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantDetailPage extends StatelessWidget {
  final Map<String, dynamic> resData;
  const RestaurantDetailPage({super.key, required this.resData});
  Future<void> _openMap() async {
    final String address = resData['address'];
    final String placeId = resData['id'];
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}&query_place_id=$placeId',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('無法打開地圖: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getDisplayImageUrl(resData['photo_url']);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(color: Colors.grey),
                  Container(color: Colors.black.withOpacity(0.3)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resData['name'],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "評分：${resData['rate']} ★",
                    style: const TextStyle(fontSize: 18, color: Colors.amber),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "(${resData['rating_count']})", // 顯示 (294)
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const Divider(height: 40),
                  Text(
                    "詳細資訊",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: Text(resData['types']),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Colors.redAccent,
                    ), // 用紅色地標比較顯眼
                    title: Text(
                      resData['address'],
                      style: const TextStyle(
                        decoration: TextDecoration.underline, // 加底線提示可點擊
                        color: Colors.blue,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: _openMap, // 點擊觸發開地圖
                  ),
                  ListTile(
                    leading: const Icon(Icons.map),
                    title: Text("距離 ${resData['dist']} 公尺"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_subway),
                    title: Text(resData['station_name']),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
