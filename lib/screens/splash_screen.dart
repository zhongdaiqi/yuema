import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';
import '../services/cloud_log_service.dart'; // 添加云日志服务导入
import 'main_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'service_agreement_screen.dart';
import 'dart:io' show exit; // 用于退出应用

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAgreementsAndLoginStatus();
  }

  Future<void> _checkAgreementsAndLoginStatus() async {
    final cloudLog = CloudLogService();
    
    try {
      // 1. 记录进入启动屏
      try {
        await cloudLog.logSplashScreen();
      } catch (e) {
        print('⚠️ 无法记录启动屏日志: $e');
      }

      // 2. 初始化SharedPreferences，增加容错处理
      SharedPreferences prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        print('⚠️ SharedPreferences初始化失败，使用模拟值: $e');
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      }

      // 3. 检查用户是否已经同意协议
      bool hasAgreedToAgreements = false;
      try {
        hasAgreedToAgreements = prefs.getBool('agreed_to_agreements') ?? false;
      } catch (e) {
        print('⚠️ 读取协议状态失败: $e');
        // 默认视为未同意，显示协议对话框
        hasAgreedToAgreements = false;
      }

      if (!hasAgreedToAgreements) {
        // 如果是首次打开APP，显示协议对话框
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          bool? agreed = await _showAgreementDialog(prefs);

          // 如果用户不同意协议，退出应用
          if (agreed == false || agreed == null) {
            await Future.delayed(const Duration(milliseconds: 100));
            exit(0);
          }
        }
      }

      // 4. 添加延迟，让用户看到splash屏幕
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        await cloudLog.logSplashDelayCompleted();
      } catch (e) {
        print('⚠️ 无法记录启动延迟完成日志: $e');
      }

      // 5. 安全地获取会话服务
      SessionService? session;
      try {
        session = await SessionService.getInstance();
      } catch (e, stackTrace) {
        print('❌ SessionService获取失败: $e');
        try {
          await cloudLog.logError('session_service_failure',
              'SessionService获取失败: $e\nStack trace: $stackTrace');
        } catch (logError) {
          print('无法记录SessionService错误: $logError');
        }
        // 即使会话服务失败，也跳转到登录页面
        session = null;
      }

      // 6. 记录会话服务状态
      try {
        if (session != null) {
          await cloudLog.logSessionServiceInitialized();
          await cloudLog.logSessionUserInfo(session.userId, session.isLoggedIn);
          await cloudLog.logNavigationDecision(session.isLoggedIn);
        } else {
          await cloudLog.logError('session_null', '会话服务为空，跳转到登录页面');
        }
      } catch (e) {
        print('⚠️ 无法记录会话状态日志: $e');
      }

      // 7. 安全导航
      if (mounted) {
        Widget targetPage;
        String navigationType;
        
        if (session?.isLoggedIn == true) {
          targetPage = const MainScreen();
          navigationType = 'main';
        } else {
          targetPage = const LoginScreen();
          navigationType = 'login';
        }

        try {
          await cloudLog.logNavigateToPage(navigationType);
        } catch (e) {
          print('⚠️ 无法记录导航日志: $e');
        }

        // 使用安全的导航方法
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => targetPage,
          ),
        );
      }
    } catch (e, stackTrace) {
      // 8. 全局异常捕获和记录
      print('🔥 启动屏全局异常: $e');
      print('堆栈跟踪: $stackTrace');
      
      try {
        await cloudLog.logCrashException(e, stackTrace);
      } catch (logError) {
        print('无法记录全局异常: $logError');
      }
      
      // 即使发生异常，也尝试导航到登录页面
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  Future<bool?> _showAgreementDialog(SharedPreferences prefs) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 用户不能点击外部关闭对话框
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('隐私协议提示'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('请查看《用户隐私协议》\\ 《用户服务协议》'),
                    const SizedBox(height: 10),
                    const Text('请阅读同意后方可使用本软件。'),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            // 跳转到隐私协议页面
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                          child: const Text('《用户隐私协议》'),
                        ),
                        TextButton(
                          onPressed: () {
                            // 跳转到服务协议页面
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ServiceAgreementScreen(),
                              ),
                            );
                          },
                          child: const Text('《用户服务协议》'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('不同意'),
                  onPressed: () {
                    // 用户点击不同意，关闭对话框并标记为不同意
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton(
                  child: const Text('同意'),
                  onPressed: () async {
                    // 用户点击同意，记录并关闭对话框
                    await prefs.setBool('agreed_to_agreements', true);
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ],
              actionsAlignment: MainAxisAlignment.spaceEvenly,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or splash image would go here
            const Text(
              '约吗',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
