/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights reserved.
 */

import 'dart:convert';
import 'dart:async'; // 添加异步编程导入
import 'package:flutter/gestures.dart'; // 添加手势识别导入
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 添加系统服务导入，包含Clipboard
import 'package:url_launcher/url_launcher.dart'; // 添加URL启动器导入
import '../screens/huawei_login_view.dart';
import '../services/cloud_log_service.dart';
import '../services/huawei_login_service.dart';
import '../services/api_service.dart';
import 'main_screen.dart'; // 导入主页
import 'privacy_policy_screen.dart'; // 导入隐私政策页面
import 'service_agreement_screen.dart'; // 导入服务协议页面
import 'huawei_auth_agreement_page.dart'; // 导入华为认证协议页面

String huaweiLoginButtonID = 'com.zuime.yuema/loginView';

class HuaweiLoginPage extends StatelessWidget {
  const HuaweiLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: HuaweiLoginExample(),
    );
  }
}

class HuaweiLoginExample extends StatefulWidget {
  const HuaweiLoginExample({super.key});

  @override
  State<HuaweiLoginExample> createState() => _HuaweiLoginExampleState();
}

class _HuaweiLoginExampleState extends State<HuaweiLoginExample> {
  String phoneNumber = '';
  bool agreement = false; // 标识用户是否同意协议
  HuaweiLoginViewController? _loginButtonViewController;
  bool loadingLogin = false; // 标识用户是否正在登录
  bool loggingIn = false; // 标识是否正在调用后端登录接口
  BuildContext? contextRef;

  // 用于等待协议状态同步的Completer
  Completer<void>? _agreementSyncCompleter;

  // 存储从HarmonyOS端接收的用户头像和昵称信息
  String? _receivedAvatarUri;
  String? _receivedNickName;

  final CloudLogService _cloudLogService = CloudLogService();

  void onLoginButtonOhosViewCreated(HuaweiLoginViewController controller) {
    _loginButtonViewController = controller;
    controller.customDataStream.listen((data) {
      // 从OHOS端接收数据
      final result = jsonDecode(data);
      setState(() {
        switch (result['method']) {
          case 'quickLoginAnonymousPhone':
            // 获取匿名手机号
            phoneNumber = result['data'];
            break;

          case 'loginSuccess':
            // 登录成功
            // 现在接收到的是纯authCode字符串，而不是JSON对象
            final authCode = result['data']; // 这里已经是authCode字符串了
            // 弹窗提示授权码并调用后端登录
            _showAuthCodeDialog(authCode);
            break;

          case 'userProfile':
            // 接收用户头像和昵称信息
            final profile = jsonDecode(result['data']);
            _receivedAvatarUri =
                profile['quickLoginAnonymousPhone']; // 使用匿名手机号作为标识
            _receivedNickName = profile['nickName'];
            break;

          case 'openPrivacy':
            // 跳转到协议页面
            String type = result['data'];
            break;

          case 'loginStart':
            // 登录开始
            loadingLogin = true;
            break;

          case 'loginEnd':
            // 登录结束
            loadingLogin = false;
            break;

          case 'AgreementStatusChanged':
            // 同意协议状态变更
            agreement = result['data'] == '1' ? true : false;
            break;

          case 'AgreementStatusChangedAck':
            // 协议状态变更确认，完成同步Completer
            if (_agreementSyncCompleter != null) {
              _agreementSyncCompleter!.complete();
              _agreementSyncCompleter = null;
            }
            break;

          case 'loginError':
            // 登录错误
            final errorInfo = result['data'];
            
            // 检查错误消息内容，如果是协议相关错误，转换为用户友好的提示
            String errorMessage = '登录失败: $errorInfo';
            if (errorInfo.toString().contains('accept the agreement') || 
                errorInfo.toString().contains('the user did not accept the agreement') ||
                errorInfo.toString().contains('1005300001')) {
              errorMessage = '请阅读并同意协议';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
            break;

          default:
            // 未处理的消息
            break;
        }
      });
    });
  }

  // 显示授权码弹窗并调用后端登录
  void _showAuthCodeDialog(String authCode) async {
    // 使用接收到的头像和昵称信息
    String? avatarUri = _receivedAvatarUri;
    String? nickName = _receivedNickName;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('授权码获取成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('正在使用授权码登录...'),
            ],
          ),
        );
      },
    );

    // 调用后端登录接口，传递头像和昵称信息
    final loginResult = await HuaweiLoginService.loginWithAuthCode(
      authCode,
      avatarUri: avatarUri,
      nickName: nickName,
    );

    if (!mounted) return;

    // 关闭授权码弹窗
    Navigator.of(context).pop();

    if (loginResult.success) {
      // 显示用户信息弹窗
      _showUserInfoDialog(loginResult.user);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loginResult.message ?? '登录失败')),
      );

      // 返回首页
      if (contextRef != null) {
        Navigator.of(contextRef!).pop();
      }
    }
  }

  // 显示用户信息弹窗
  void _showUserInfoDialog(dynamic user) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('登录成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (user['avatar'] != null && user['avatar'].isNotEmpty)
                ClipOval(
                  child: Image.network(
                    user['avatar'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 40),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 40),
                ),
              const SizedBox(height: 16),
              Text(
                '',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '昵称: ${user['nickname'] ?? '未知'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user['avatar'] != null && user['avatar'].isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // 登录成功后跳转到主页
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                  (route) => false,
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 登录按钮
  Widget _loginButton() {
    return Column(children: [
      _buildLoginOhosView(),
    ]);
  }

  // 一键登录按钮
  Widget _buildLoginOhosView() {
    return Container(
      height: 40,
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 448,
      ),
      child: GestureDetector(
        onTap: () async {
          // 检查用户是否同意协议
          if (!agreement) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('请阅读并同意协议'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          
          // 确保协议状态同步到原生端
          // 创建一个Completer来等待协议状态同步确认
          _agreementSyncCompleter = Completer<void>();
          
          // 发送当前协议状态到原生端
          if (_loginButtonViewController != null) {
            await _loginButtonViewController!.sendMessageToOhosView(
              'AgreementStatusChanged', 
              agreement,
            );
            
            // 等待协议状态同步确认
            try {
              await _agreementSyncCompleter!.future.timeout(
                const Duration(milliseconds: 500), // 设置超时时间
              );
            } catch (e) {
              // 如果超时，使用默认行为继续
              print('协议状态同步等待超时: $e');
            }
            
            // 发送登录请求到原生端
            await _loginButtonViewController!.sendMessageToOhosView(
              'login', 
              '',
            );
          }
        },
        child: HuaweiLoginOhosView(onLoginButtonOhosViewCreated, huaweiLoginButtonID),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    contextRef = context;

    return Container(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 28),
        color: const Color(0xFFF1F3F5),
        width: double.infinity,
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  // 返回按钮
                  Row(children: [
                    GestureDetector(
                      onTap: () {
                        if (!loadingLogin) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Opacity(
                        opacity: loadingLogin ? 0.6 : 1,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.grey[300],
                          ),
                          child:
                              const Icon(Icons.arrow_back, color: Colors.black),
                        ),
                      ),
                    )
                  ]),

                  // App图标
                  const Expanded(
                    child: Center(
                      child: Image(
                        image: AssetImage('assets/logo.png'),
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // 显示绑定到HUAWEI ID的手机号
                  Text(
                    phoneNumber,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: const Text(
                      '华为账号绑定号码',
                      style: TextStyle(
                          color: Color(0x66000000), fontSize: 12, height: 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 56),
                    child: _loginButton(),
                  ),
                  Expanded(child: Container()),
                  _buildFlutterView()
                ],
              ),
            )
          ],
        ));
  }

  Widget _buildFlutterView() {
    final size = MediaQuery.of(context).size;
    const double pagePadding = 16;
    const double checkBoxWidth = 24;
    const double checkBoxMarginRight = 6;
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: checkBoxWidth,
            height: checkBoxWidth,
            padding: const EdgeInsets.all(2),
            margin: EdgeInsets.only(right: checkBoxMarginRight),
            child: Opacity(
              opacity: loadingLogin ? 0.6 : 1,
              child: Checkbox(
                shape: const CircleBorder(),
                side: BorderSide(
                  width: 1,
                  color: Color(0x66000000),
                ),
                value: agreement,
                activeColor: const Color.fromARGB(255, 205, 14, 45),
                onChanged: (value) async {
                  if (loadingLogin) {
                    return;
                  }
                  
                  // 创建一个Completer来等待协议状态同步确认
                  _agreementSyncCompleter = Completer<void>();
                  
                  _loginButtonViewController?.sendMessageToOhosView(
                      'AgreementStatusChanged', value);
                  setState(() {
                    agreement = value ?? false;
                  });
                  
                  // 等待协议状态同步确认
                  try {
                    await _agreementSyncCompleter!.future.timeout(
                      const Duration(milliseconds: 500), // 设置超时时间
                    );
                  } catch (e) {
                    // 如果超时或其他错误，继续执行（不阻塞用户交互）
                    print('协议状态同步等待超时或出错: $e');
                  }
                },
              ),
            ),
          ),
          Container(
            width: size.width -
                pagePadding * 2 -
                checkBoxWidth -
                checkBoxMarginRight,
            height: 30,
            constraints: const BoxConstraints(maxWidth: 36 * 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                children: [
                  const TextSpan(text: '我已阅读并同意'),
                  TextSpan(
                    text: '《用户协议》',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // 跳转到用户协议页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: '《隐私协议》',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // 跳转到隐私协议页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ServiceAgreementScreen(),
                          ),
                        );
                      },
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: '《华为账号用户认证协议》',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // 导航到协议显示页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HuaweiAuthAgreementPage(),
                          ),
                        );
                      },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
