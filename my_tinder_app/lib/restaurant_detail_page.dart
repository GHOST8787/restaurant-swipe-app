// lib/restaurant_detail_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart'; // 為了使用 getDisplayImageUrl

class RestaurantDetailPage extends StatelessWidget {
  final Map<String, dynamic> resData;
  const RestaurantDetailPage({super.key, required this.resData});

  Future<void> _openMap() async {
    final String address = resData['address'];
    final String name = resData['name'];
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("$name $address")}',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('無法打開地圖: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = getDisplayImageUrl(
      resData['photo_url'],
    ); // 呼叫 main.dart 的函式

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
                  Row(
                    children: [
                      Text(
                        "評分：${resData['rate']} ★",
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "(${resData['rating_count']})",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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
                    ),
                    title: Text(
                      resData['address'],
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.blue,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: _openMap,
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
