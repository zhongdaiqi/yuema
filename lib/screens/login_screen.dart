import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart'; // 添加设备信息插件导入
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/cloud_log_service.dart'; // 添加云日志服务导入
import '../services/device_id_service.dart'; // 添加设备ID服务导入
import 'huawei_login_page.dart'; // 更新导入路径
import '../services/apple_login_service.dart'; // Apple 登录（仅 iOS）
import 'register_screen.dart';
import 'privacy_policy_screen.dart';
import 'service_agreement_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _agreedToPolicy = false;
  bool _rememberMe = false; // 添加记住账号密码选项
  bool _isLoading = false;
  String _deviceId = ''; // 存储设备ID

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _loadDeviceId(); // 加载设备ID

    // 记录页面访问日志
    final cloudLog = CloudLogService();
    cloudLog.logPageView('login_screen');
  }

  // 加载设备ID
  Future<void> _loadDeviceId() async {
    try {
      String deviceId = await DeviceIdService.instance.getDeviceId();
      setState(() {
        _deviceId = deviceId;
      });
    } catch (e) {
      print('获取设备ID时出错: $e');
      // 出错时生成一个随机ID
      String randomId = 'random_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceId = randomId;
      });
      // 也保存到本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_id', randomId);
    }
  }

  // 加载保存的账号信息
  Future<void> _loadSavedCredentials() async {
    final session = await SessionService.getInstance();

    // 检查是否保存了记住账号密码的标志
    final prefs = await SharedPreferences.getInstance();
    final shouldRemember = prefs.getBool('remember_me') ?? false;

    if (shouldRemember && session.username != null) {
      setState(() {
        _usernameController.text = session.username ?? '';
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先同意隐私协议和服务协议')),
      );
      return;
    }

    // 记录登录开始
    final cloudLog = CloudLogService();
    await cloudLog.logLoginStart(_usernameController.text);

    setState(() {
      _isLoading = true;
    });

    try {
      // 记录登录请求发送
      await cloudLog.logLoginRequestSent(_usernameController.text);

      final result = await ApiService.loginUser(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      // 记录登录响应接收
      await cloudLog.logLoginResponseReceived(
          _usernameController.text, result['success'] == true);

      if (result['success'] == true) {
        // 记录登录成功
        final userId = result['data']?['id'] as int? ?? 0;
        await cloudLog.logLoginSuccess(userId, _usernameController.text);

        // 保存账号信息（如果选择了记住账号密码）
        if (_rememberMe) {
          final session = await SessionService.getInstance();
          await session.setUsername(_usernameController.text);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('remember_me', true);
        } else {
          // 如果没有选择记住账号密码，则清除之前保存的信息
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('remember_me', false);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录成功')),
          );

          // 跳转到主页面
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainScreen(),
            ),
          );
        }
      } else {
        // 记录登录失败
        await cloudLog.logLoginFailure(
            _usernameController.text, result['message'] ?? 'Unknown error');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '登录失败')),
          );
        }
      }
    } catch (e) {
      // 记录异常错误
      await cloudLog.logError('login_exception', e.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络请求失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 华为账号登录方法 - 导航到华为登录页面
  Future<void> _huaweiLogin() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HuaweiLoginPage(),
      ),
    );
  }

  // Apple 登录（仅 iOS 原生 Sign in with Apple；其他平台不显示按钮）
  void _appleLogin() {
    AppleLoginService.signIn(context);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户登录'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 用户名输入框
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '请输入用户名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 密码输入框
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 记住账号密码复选框
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text('记住账号密码'),
                ],
              ),

              // 协议复选框
              Row(
                children: [
                  Checkbox(
                    value: _agreedToPolicy,
                    onChanged: (value) {
                      setState(() {
                        _agreedToPolicy = value ?? false;
                      });
                    },
                  ),
                  const Text('我已阅读并同意'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    child: const Text('《隐私协议》'),
                  ),
                  const Text('和'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ServiceAgreementScreen(),
                        ),
                      );
                    },
                    child: const Text('《服务协议》'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('登录'),
                ),
              ),

              const SizedBox(height: 16),

              // 注册按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('没有账号？立即注册'),
                ),
              ),

              const SizedBox(height: 16),

              // 华为登录按钮（仅 Android/鸿蒙显示；iOS 提供 Sign in with Apple）
              if (!AppleLoginService.isSupported) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _huaweiLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800], // 华为品牌颜色
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_android, size: 20),
                        const SizedBox(width: 8),
                        const Text('华为账号登录'),
                      ],
                    ),
                  ),
                ),
              ],

              // Apple 登录按钮（仅 iOS 显示原生 Sign in with Apple）
              if (AppleLoginService.isSupported) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _appleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.apple, size: 20),
                        const SizedBox(width: 8),
                        const Text('Apple 账号登录'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
