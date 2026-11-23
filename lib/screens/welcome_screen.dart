import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';
import 'service_agreement_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟2秒后检查用户状态
    Timer(const Duration(seconds: 2), _checkUserStatus);
  }

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final agreedToTerms = prefs.getBool('agreedToTerms') ?? false;

    if (!agreedToTerms) {
      // 显示协议确认弹窗
      _showTermsDialog();
    } else {
      // 检查用户是否已登录
      final isLoggedIn = prefs.getString('authToken') != null;
      if (isLoggedIn) {
        // 用户已登录，跳转到主页
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // 用户未登录，跳转到登录页
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 用户不能通过点击背景关闭弹窗
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('隐私协议提示'),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 16),
              children: [
                const TextSpan(text: '请查看'),
                TextSpan(
                  text: '《用户隐私协议》',
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                ),
                const TextSpan(text: '\\'),
                TextSpan(
                  text: '《用户服务协议》',
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ServiceAgreementScreen(),
                        ),
                      );
                    },
                ),
                const TextSpan(text: '\n请阅读同意后方可使用本软件。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 用户不同意协议，退出应用
                Navigator.of(context).pop();
                // 在实际应用中，可以调用SystemNavigator.pop()退出应用
              },
              child: const Text('不同意'),
            ),
            TextButton(
              onPressed: () async {
                // 用户同意协议，保存状态并继续
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('agreedToTerms', true);
                Navigator.of(context).pop();
                _checkUserStatus();
              },
              child: const Text('同意'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).primaryColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo占位符（实际项目中应该使用真实的Logo图片）
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 50),
            const Text(
              '约吗，让生活更有趣',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
