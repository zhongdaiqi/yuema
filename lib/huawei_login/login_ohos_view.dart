import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginView extends StatefulWidget {
  final Function(String authCode)? onLoginSuccess;
  final Function(String? error)? onLoginError;
  final Function(String? profile)? onUserProfile;

  const LoginView({
    Key? key,
    this.onLoginSuccess,
    this.onLoginError,
    this.onUserProfile,
  }) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  static const MethodChannel _channel = MethodChannel(
    'com.zuime.yuema/loginView',
    StandardMethodCodec(),
  );

  @override
  Widget build(BuildContext context) {
    // 在HarmonyOS上使用平台视图，由于Flutter中没有harmonyOS平台，我们使用默认按钮
    return Container(
      alignment: Alignment.center,
      child: ElevatedButton(
        onPressed: _performHuaweiLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 20),
            SizedBox(width: 8),
            Text('华为账号登录'),
          ],
        ),
      ),
    );
  }

  Future<void> _performHuaweiLogin() async {
    try {
      // 调用HarmonyOS端的华为登录方法
      final result = await _channel.invokeMethod('getAuthCode');
      
      if (result != null && result is String && result.isNotEmpty) {
        // 登录成功，返回授权码
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!(result);
        }
      } else {
        // 登录失败
        if (widget.onLoginError != null) {
          widget.onLoginError!('获取华为授权码失败');
        }
      }
    } on PlatformException catch (e) {
      // 处理平台异常
      print('华为登录平台异常: ${e.message}');
      if (widget.onLoginError != null) {
        widget.onLoginError!(e.message);
      }
    } catch (e) {
      // 处理其他异常
      print('华为登录异常: $e');
      if (widget.onLoginError != null) {
        widget.onLoginError!(e.toString());
      }
    }
  }
}