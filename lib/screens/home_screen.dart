import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'note_publish_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('约吗'),
        actions: [
          TextButton(
            onPressed: () {
              // 退出登录操作
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              '退出',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 原有内容
            const SizedBox(height: 30),
            const Center(
              child: Text(
                '欢迎使用约吗活动社交App！',
                style: TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotePublishScreen(),
                    ),
                  );
                },
                child: const Text('发布笔记'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
