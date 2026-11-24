import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'service_agreement_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _agreedToPolicy = false;
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先同意隐私协议和服务协议')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> result = await ApiService.registerUser(
        username: _usernameController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      );

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('注册成功')),
          );

          // 跳转到登录页面
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '注册失败')),
          );
        }
      }
    } catch (e) {
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户注册'),
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
                  hintText: '请输入3-20个字符，仅英文字母、数字、下划线',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }

                  if (value.length < 3 || value.length > 20) {
                    return '用户名长度应在3-20个字符之间';
                  }

                  final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
                  if (!usernameRegex.hasMatch(value)) {
                    return '用户名只能包含英文字母、数字、下划线';
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
                  hintText: '请输入6-20个字符',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }

                  if (value.length < 6 || value.length > 20) {
                    return '密码长度应在6-20个字符之间';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 确认密码输入框
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认密码',
                  hintText: '请再次输入密码',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请确认密码';
                  }

                  if (value != _passwordController.text) {
                    return '两次输入的密码不一致';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 昵称输入框
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  hintText: '请输入3-20个字符，仅中文、英文字母、数字、下划线',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入昵称';
                  }

                  if (value.length < 3 || value.length > 20) {
                    return '昵称长度应在3-20个字符之间';
                  }

                  // 匹配中文、英文字母、数字、下划线
                  final nicknameRegex = RegExp(r'^[\u4e00-\u9fa5_a-zA-Z0-9]+$');
                  if (!nicknameRegex.hasMatch(value)) {
                    return '昵称只能包含中文、英文字母、数字、下划线';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

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

              // 注册按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('注册'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
