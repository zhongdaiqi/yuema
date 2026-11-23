import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  File? _avatarImage;
  XFile? _avatarXFile; // 用于Web平台
  bool _agreedToPolicy = false;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 调整图片质量
      );

      if (pickedFile != null) {
        print('Picked file path: ${pickedFile.path}');
        print('Picked file name: ${pickedFile.name}');
        setState(() {
          if (kIsWeb) {
            _avatarXFile = pickedFile;
            _avatarImage = null;
            print('Selected image for web platform');
          } else {
            _avatarImage = File(pickedFile.path);
            _avatarXFile = null;
            print('Selected image for native platform');
          }
        });
      } else {
        print('No file picked');
      }
    } catch (e, stackTrace) {
      print('Pick image error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择图片失败')),
        );
      }
    }
  }

  Future<String?> _uploadAvatar() async {
    try {
      if (_avatarImage != null) {
        // 原生平台
        print('Uploading avatar from native platform');
        final fileBytes = await _avatarImage!.readAsBytes();
        print('File bytes length: ${fileBytes.length}');
        final result = await ApiService.uploadAvatar(
          fileBytes: fileBytes,
          fileName: _avatarImage!.path.split('/').last,
        );

        if (result != null) {
          print('Upload result: $result');
          if (result.containsKey('success') &&
              result['success'] == true &&
              result.containsKey('url')) {
            return result['url'];
          } else if (result.containsKey('message')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('头像上传失败: ${result['message']}')),
              );
            }
            // 返回一个特殊的值表示上传失败
            return 'UPLOAD_FAILED';
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('头像上传失败，未知错误')),
              );
            }
            // 返回一个特殊的值表示上传失败
            return 'UPLOAD_FAILED';
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('头像上传失败，服务器无响应')),
            );
          }
          // 返回一个特殊的值表示上传失败
          return 'UPLOAD_FAILED';
        }
      } else if (_avatarXFile != null) {
        // Web平台
        print('Uploading avatar from web platform');
        print('File name: ${_avatarXFile!.name}');
        // 使用不同的方法读取文件
        final bytes = await _avatarXFile!.readAsBytes();
        print('File bytes length: ${bytes.lengthInBytes}');
        if (bytes.isNotEmpty) {
          final result = await ApiService.uploadAvatar(
            fileBytes: bytes,
            fileName: _avatarXFile!.name,
          );

          if (result != null) {
            print('Upload result: $result');
            if (result.containsKey('success') &&
                result['success'] == true &&
                result.containsKey('url')) {
              return result['url'];
            } else if (result.containsKey('message')) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('头像上传失败: ${result['message']}')),
                );
              }
              // 返回一个特殊的值表示上传失败
              return 'UPLOAD_FAILED';
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('头像上传失败，未知错误')),
                );
              }
              // 返回一个特殊的值表示上传失败
              return 'UPLOAD_FAILED';
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('头像上传失败，服务器无响应')),
              );
            }
            // 返回一个特殊的值表示上传失败
            return 'UPLOAD_FAILED';
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('头像文件为空')),
            );
          }
          // 返回一个特殊的值表示上传失败
          return 'UPLOAD_FAILED';
        }
      }
    } catch (e, stackTrace) {
      // 上传失败，但不应阻止注册流程
      print('Upload exception: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传异常: $e，将继续注册流程')),
        );
      }
      // 返回一个特殊的值表示上传失败
      return 'UPLOAD_FAILED';
    }
    return null;
  }

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
      // 如果有选择头像，则先上传头像
      String? avatarUrl;
      if (_avatarImage != null || _avatarXFile != null) {
        final uploadResult = await _uploadAvatar();

        // 检查上传是否失败
        if (uploadResult == 'UPLOAD_FAILED') {
          // 上传失败，中断注册流程
          return;
        }

        avatarUrl = uploadResult;
      }

      Map<String, dynamic> result;
      if (avatarUrl != null) {
        result = await ApiService.registerUser(
          username: _usernameController.text,
          password: _passwordController.text,
          nickname: _nicknameController.text,
          avatar: avatarUrl,
        );
      } else {
        result = await ApiService.registerUser(
          username: _usernameController.text,
          password: _passwordController.text,
          nickname: _nicknameController.text,
        );
      }

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
              // 头像选择区域
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _avatarImage != null
                        ? FileImage(_avatarImage!)
                        : (_avatarXFile != null
                            ? NetworkImage(_avatarXFile!.path) as ImageProvider
                            : null),
                    child: (_avatarImage == null && _avatarXFile == null)
                        ? const Icon(Icons.camera_alt, size: 50)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 30),

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
