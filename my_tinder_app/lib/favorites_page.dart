// lib/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // 為了使用 getDisplayImageUrl
import 'restaurant_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // 1. 變數改成跟主畫面一樣的價格與營業時間篩選
  int _filterPriceLevel = -1; // -1: 不限
  bool _filterOpenNow = false; // false: 全部

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("收藏清單")),
        body: const Center(child: Text("請先登入")),
      );
    }

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
          // 2. 移植主畫面的篩選介面
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左邊：價格下拉選單
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white, // 背景白
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _filterPriceLevel,
                      icon: const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.deepOrange,
                      ),
                      // ★★★ 修正 1：強制設定選單文字樣式為黑色 ★★★
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: -1, child: Text("💰 價格不限")),
                        DropdownMenuItem(value: 1, child: Text("💰 便宜 (\$ )")),
                        DropdownMenuItem(
                          value: 2,
                          child: Text("💰 適中 (\$\$ )"),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text("💰 稍貴 (\$\$\$ )"),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text("💰 高級 (\$\$\$\$)"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _filterPriceLevel = val);
                      },
                    ),
                  ),
                ),

                // 右邊：營業中按鈕
                InkWell(
                  onTap: () => setState(() => _filterOpenNow = !_filterOpenNow),
                  borderRadius: BorderRadius.circular(30),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _filterOpenNow
                          ? Colors.orange
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 18,
                          color: _filterOpenNow
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _filterOpenNow ? "營業中" : "非營業時間",
                          style: TextStyle(
                            color: _filterOpenNow
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
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

                // 3. 修改篩選邏輯：依據價格與營業狀態
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final res = data['restaurantData'] ?? {};

                  // 處理價格 (轉為 int)
                  int price = 0;
                  if (res['price_level'] != null) {
                    price = int.tryParse(res['price_level'].toString()) ?? 0;
                  }

                  // 處理營業狀態 (注意：這是收藏當下的狀態)
                  bool isOpen = res['open_now'] == true;

                  bool priceMatch =
                      _filterPriceLevel == -1 || price == _filterPriceLevel;
                  bool openMatch = !_filterOpenNow || isOpen;

                  return priceMatch && openMatch;
                }).toList();

                if (filteredDocs.isEmpty)
                  return const Center(child: Text("沒有符合條件的收藏"));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    final res = data['restaurantData'] ?? {};
                    final imageUrl = getDisplayImageUrl(res['photo_url']);

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
                        // 4. 副標題改成顯示地址
                        subtitle: Text(
                          "${res['rate']} ★ · ${res['address'] ?? '未知地址'}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
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
