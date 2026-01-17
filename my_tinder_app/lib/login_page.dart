// lib/login_page.dart
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGuestSignIn;
  final String? errorMessage;

  const LoginPage({
    super.key,
    required this.onGoogleSignIn,
    required this.onGuestSignIn,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
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

          // Google 按鈕
          SizedBox(
            width: 250,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onGoogleSignIn,
              icon: const Icon(Icons.login),
              label: const Text("Google 帳號登入"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 訪客按鈕
          SizedBox(
            width: 250,
            height: 50,
            child: OutlinedButton(
              onPressed: onGuestSignIn,
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
}
