import 'package:flutter/material.dart';
import '../huawei_login/login_ohos_view.dart';
import '../services/huawei_login_service.dart';

class HuaweiLoginExample extends StatefulWidget {
  const HuaweiLoginExample({super.key});

  @override
  State<HuaweiLoginExample> createState() => _HuaweiLoginExampleState();
}

class _HuaweiLoginExampleState extends State<HuaweiLoginExample> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('华为登录'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '华为登录',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            LoginView(
              onLoginSuccess: (authCode) {
                // 华为登录成功，获取到授权码
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('华为登录成功，授权码：${authCode.substring(0, 10)}...')),
                );
              },
              onLoginError: (error) {
                // 华为登录失败
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('华为登录失败：$error')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}