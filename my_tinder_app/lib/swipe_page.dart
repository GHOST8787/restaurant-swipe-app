// lib/swipe_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'main.dart'; // 為了使用 getDisplayImageUrl
import 'restaurant_detail_page.dart'; // 為了點擊卡片跳轉

class SwipePage extends StatelessWidget {
  final List<Map<String, dynamic>> restaurants;
  final Function(Map<String, dynamic>) onSwipeRight;
  final String currentFilter;
  final Function(String) onFilterChanged;

  SwipePage({
    super.key,
    required this.restaurants,
    required this.onSwipeRight,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  final CardSwiperController controller = CardSwiperController();

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
    double cardWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : MediaQuery.of(context).size.width * 0.9;
    double cardHeight = MediaQuery.of(context).size.height * 0.7;

    return Column(
      children: [
        // 篩選器
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: categoryOptions.containsKey(currentFilter)
                  ? currentFilter
                  : 'all',
              isExpanded: true,
              icon: const Icon(Icons.filter_list_rounded, color: Colors.orange),
              items: categoryOptions.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: currentFilter == e.key
                              ? Colors.orange.shade800
                              : Colors.black87,
                          fontWeight: currentFilter == e.key
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) onFilterChanged(val);
              },
            ),
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: restaurants.isEmpty
              ? const Center(child: Text("附近找不到符合的餐廳 T_T"))
              : Center(
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
                        if (dir == CardSwiperDirection.right) {
                          onSwipeRight(restaurants[prev]);
                        }
                        return true;
                      },
                      cardBuilder: (context, index, _, __) =>
                          _RestaurantCard(data: restaurants[index]),
                    ),
                  ),
                ),
        ),

        // 底部按鈕
        if (restaurants.isNotEmpty)
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
    final String imageUrl = getDisplayImageUrl(
      data['photo_url'],
    ); // 呼叫 main.dart 的函式
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
    String category =
        typeTrans[types.isNotEmpty ? types[0] : 'restaurant'] ?? '餐廳';

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailPage(resData: data),
          ),
        ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Divider(color: Colors.grey.shade200),
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
                        if (data['station_dist'] != '-1') ...[
                          const Spacer(),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
