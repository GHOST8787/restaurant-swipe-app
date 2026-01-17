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
          // 頂部篩選
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
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
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
                  return Center(child: Text("沒有此類型的收藏"));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    final res = data['restaurantData'] ?? {};
                    final imageUrl = getDisplayImageUrl(
                      res['photo_url'],
                    ); // 呼叫 main.dart 的函式

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
