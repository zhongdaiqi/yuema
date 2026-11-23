import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kReleaseMode, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import './session_service.dart';

class CloudLogService {
  static const String _devBaseUrl = 'http://localhost';
  static const String _prodBaseUrl = 'https://yuema.zuime.com';

  // 初始化方法
  Future<void> init() async {
    try {
      // 尝试上传本地缓存的日志
      await uploadLocalLogs();
    } catch (e) {
      print('CloudLogService初始化失败: $e');
    }
  }

  // 记录应用启动
  Future<void> logAppLaunch() async {
    await logAppStarted();
  }

  // 根据运行环境确定baseUrl
  static String get baseUrl {
    if (kReleaseMode) {
      return _prodBaseUrl;
    } else {
      return _devBaseUrl;
    }
  }

  // 记录应用启动
  Future<void> logAppStarted() async {
    await _logToCloud(
      operation: 'app_started',
      content: '应用启动',
    );
  }

  // 记录登录开始
  Future<void> logLoginStart(String username) async {
    await _logToCloud(
      operation: 'login_start',
      content: '用户登录开始: $username',
    );
  }

  // 记录登录请求发送
  Future<void> logLoginRequestSent(String username) async {
    await _logToCloud(
      operation: 'login_request_sent',
      content: '用户登录请求发送: $username',
    );
  }

  // 记录登录响应接收
  Future<void> logLoginResponseReceived(String username, bool success) async {
    await _logToCloud(
      operation: 'login_response_received',
      content: '用户登录响应接收: $username, 成功: $success',
    );
  }

  // 记录登录成功
  Future<void> logLoginSuccess(int userId, String username) async {
    await _logToCloud(
      operation: 'login_success',
      userId: userId,
      content: '用户登录成功: $username',
    );
  }

  // 记录登录失败
  Future<void> logLoginFailure(String username, String message) async {
    await _logToCloud(
      operation: 'login_failure',
      content: '用户登录失败: $username, 错误: $message',
    );
  }

  // 记录错误
  Future<void> logError(String operation, String content) async {
    await _logToCloud(
      operation: operation,
      content: content,
    );
  }

  // 记录闪退异常
  Future<void> logCrashException(dynamic error, StackTrace stackTrace) async {
    try {
      await _logToCloud(
        operation: 'crash_exception',
        content: '应用闪退异常: ${error.toString()}\n堆栈跟踪: $stackTrace',
      );
    } catch (e) {
      print('记录闪退异常失败: $e');
      // 即使云端上传失败，也要确保本地日志记录
      try {
        await _logToLocal('crash_exception', '应用闪退异常: ${error.toString()}\n堆栈跟踪: $stackTrace', e.toString());
      } catch (localError) {
        print('记录本地闪退日志失败: $localError');
      }
    }
  }

  // 记录页面访问
  Future<void> logPageView(String pageName) async {
    await _logToCloud(
      operation: 'page_view',
      content: '页面访问: $pageName',
    );
  }

  // 记录按钮点击
  Future<void> logButtonClick(String buttonName) async {
    await _logToCloud(
      operation: 'button_click',
      content: '按钮点击: $buttonName',
    );
  }

  // 记录API调用
  Future<void> logApiCall(String apiEndpoint, String method, bool success, String? error) async {
    await _logToCloud(
      operation: 'api_call',
      content: 'API调用: $method $apiEndpoint, 成功: $success, 错误: $error',
    );
  }

  // 记录API调用及参数
  Future<void> logApiCallWithParams(String apiEndpoint, String method, Map<String, dynamic> params) async {
    await _logToCloud(
      operation: 'api_call_with_params',
      content: 'API调用: $method $apiEndpoint, 参数: ${jsonEncode(params)}',
    );
  }

  // 记录笔记创建
  Future<void> logNoteCreate(int userId, String title) async {
    await _logToCloud(
      operation: 'note_create',
      userId: userId,
      content: '笔记创建: $title',
    );
  }

  // 记录笔记更新
  Future<void> logNoteUpdate(int userId, int noteId, String title) async {
    await _logToCloud(
      operation: 'note_update',
      userId: userId,
      content: '笔记更新: $noteId, 标题: $title',
    );
  }

  // 记录笔记删除
  Future<void> logNoteDelete(int userId, int noteId) async {
    await _logToCloud(
      operation: 'note_delete',
      userId: userId,
      content: '笔记删除: $noteId',
    );
  }

  // 记录笔记点赞
  Future<void> logNoteLike(int userId, int noteId) async {
    await _logToCloud(
      operation: 'note_like',
      userId: userId,
      content: '笔记点赞: $noteId',
    );
  }

  // 记录笔记收藏
  Future<void> logNoteCollect(int userId, int noteId) async {
    await _logToCloud(
      operation: 'note_collect',
      userId: userId,
      content: '笔记收藏: $noteId',
    );
  }

  // 记录用户关注
  Future<void> logUserFollow(int userId, int followUserId) async {
    await _logToCloud(
      operation: 'user_follow',
      userId: userId,
      content: '用户关注: $followUserId',
    );
  }

  // 记录活动报名
  Future<void> logActivityJoin(int userId, int noteId) async {
    await _logToCloud(
      operation: 'activity_join',
      userId: userId,
      content: '活动报名: $noteId',
    );
  }

  // 记录启动屏日志
  Future<void> logSplashScreen() async {
    await _logToCloud(
      operation: 'splash_screen',
      content: '启动屏显示',
    );
  }

  // 记录启动屏延迟完成日志
  Future<void> logSplashDelayCompleted() async {
    await _logToCloud(
      operation: 'splash_delay_completed',
      content: '启动屏延迟完成',
    );
  }

  // 记录会话服务初始化完成日志
  Future<void> logSessionServiceInitialized() async {
    await _logToCloud(
      operation: 'session_service_initialized',
      content: '会话服务初始化完成',
    );
  }

  // 记录会话用户信息日志
  Future<void> logSessionUserInfo(String? userId, bool isLoggedIn) async {
    await _logToCloud(
      operation: 'session_user_info',
      content: '会话用户信息 - userId: $userId, 已登录: $isLoggedIn',
    );
  }

  // 记录导航决策日志
  Future<void> logNavigationDecision(bool isLoggedIn) async {
    await _logToCloud(
      operation: 'navigation_decision',
      content: '导航决策 - 已登录: $isLoggedIn',
    );
  }

  // 记录导航到主页面日志
  Future<void> logNavigateToMain() async {
    await _logToCloud(
      operation: 'navigate_to_main',
      content: '导航到主页面',
    );
  }

  // 记录导航到登录页面日志
  Future<void> logNavigateToLogin() async {
    await _logToCloud(
      operation: 'navigate_to_login',
      content: '导航到登录页面',
    );
  }

  // 记录导航到页面日志
  Future<void> logNavigateToPage(String pageType) async {
    await _logToCloud(
      operation: 'navigate_to_$pageType',
      content: '导航到${pageType == 'main' ? '主页面' : '登录页面'}',
    );
  }

  // 记录龙珠领取开始
  Future<void> logLongZhuClaimStart(String appId, String deviceId) async {
    await _logToCloud(
      operation: 'longzhu_claim_start',
      content: '龙珠领取开始 - appId: $appId, deviceId: $deviceId',
    );
  }

  // 记录龙珠领取成功
  Future<void> logLongZhuClaimSuccess(String appId, String deviceId, Map<String, dynamic> responseData) async {
    await _logToCloud(
      operation: 'longzhu_claim_success',
      content: '龙珠领取成功 - appId: $appId, deviceId: $deviceId, response: ${jsonEncode(responseData)}',
    );
  }

  // 记录龙珠领取失败
  Future<void> logLongZhuClaimFailure(String appId, String deviceId, String errorMessage) async {
    await _logToCloud(
      operation: 'longzhu_claim_failure',
      content: '龙珠领取失败 - appId: $appId, deviceId: $deviceId, error: $errorMessage',
    );
  }

  // 记录龙珠激活开始
  Future<void> logLongZhuActivateStart(String appId) async {
    await _logToCloud(
      operation: 'longzhu_activate_start',
      content: '龙珠激活开始 - appId: $appId',
    );
  }

  // 记录龙珠激活成功
  Future<void> logLongZhuActivateSuccess(String appId, String longZhuCode, String activeTime) async {
    await _logToCloud(
      operation: 'longzhu_activate_success',
      content: '龙珠激活成功 - appId: $appId, longZhuCode: $longZhuCode, activeTime: $activeTime',
    );
  }

  // 记录龙珠激活失败
  Future<void> logLongZhuActivateFailure(String appId, String errorMessage) async {
    await _logToCloud(
      operation: 'longzhu_activate_failure',
      content: '龙珠激活失败 - appId: $appId, error: $errorMessage',
    );
  }

  // 记录获取龙珠活动应用列表开始
  Future<void> logGetLongZhuAppsStart(int page, int size) async {
    await _logToCloud(
      operation: 'get_longzhu_apps_start',
      content: '获取龙珠活动应用列表开始 - page: $page, size: $size',
    );
  }

  // 记录获取龙珠活动应用列表成功
  Future<void> logGetLongZhuAppsSuccess(int count) async {
    await _logToCloud(
      operation: 'get_longzhu_apps_success',
      content: '获取龙珠活动应用列表成功 - count: $count',
    );
  }

  // 记录获取龙珠活动应用列表失败
  Future<void> logGetLongZhuAppsFailure(String errorMessage) async {
    await _logToCloud(
      operation: 'get_longzhu_apps_failure',
      content: '获取龙珠活动应用列表失败 - error: $errorMessage',
    );
  }

  // 记录龙珠界面访问
  Future<void> logLongZhuScreenView() async {
    await _logToCloud(
      operation: 'longzhu_screen_view',
      content: '龙珠界面访问',
    );
  }

  // 通用日志上传方法
  Future<void> _logToCloud({
    required String operation,
    int? userId,
    String? content,
  }) async {
    try {
      // 如果没有提供userId，尝试从会话中获取
      if (userId == null) {
        try {
          final session = await SessionService.getInstance();
          final sessionUserId = session.userId;
          if (sessionUserId != null && sessionUserId.isNotEmpty) {
            userId = int.tryParse(sessionUserId);
          }
        } catch (e) {
          print('获取会话用户ID失败: $e');
        }
      }

      final url = Uri.parse('$baseUrl/api/log/upload');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'userId': userId,
          'operation': operation,
          'content': content,
        }),
      );

      // 检查响应状态码
      if (response.statusCode == 200) {
        // 检查响应内容类型
        String contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('application/json')) {
          // 正常的JSON响应
          try {
            final result = jsonDecode(response.body);
            if (result['success'] != true) {
              print('云端日志上传失败: ${result['message']}');
            }
          } catch (e) {
            // 如果响应是HTML或其他非JSON格式
            print('云端日志上传响应解析失败: $e, 响应内容: ${response.body}');
            // 将错误信息记录到本地日志
            await _logToLocal(operation, content, '响应解析失败: $e, 响应内容: ${response.body}');
          }
        } else {
          // 响应不是JSON格式，可能是错误页面
          print('云端日志上传收到非JSON响应，状态码: ${response.statusCode}, 内容类型: $contentType, 响应内容: ${response.body}');
          // 将错误信息记录到本地日志
          await _logToLocal(operation, content, '收到非JSON响应: 状态码-${response.statusCode}, 内容-${response.body}');
        }
      } else {
        // HTTP状态码非200
        print('云端日志上传HTTP错误，状态码: ${response.statusCode}, 响应内容: ${response.body}');
        // 将错误信息记录到本地日志
        await _logToLocal(operation, content, 'HTTP错误: 状态码-${response.statusCode}, 内容-${response.body}');
      }
    } catch (e, stackTrace) {
      print('云端日志上传异常: $e');
      print('堆栈跟踪: $stackTrace');
      // 如果上传失败，记录到本地日志
      await _logToLocal(operation, content, '$e\n$stackTrace');
    }
  }

  // 记录本地日志（当云端上传失败时）
  Future<void> _logToLocal(String operation, String? content, String error) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('local_logs') ?? [];
      
      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'operation': operation,
        'content': content,
        'error': error,
      };
      
      logs.add(jsonEncode(logEntry));
      
      // 限制本地日志数量，最多保存100条
      if (logs.length > 100) {
        logs.removeRange(0, logs.length - 100);
      }
      
      await prefs.setStringList('local_logs', logs);
    } catch (e) {
      print('本地日志记录失败: $e');
    }
  }

  // 尝试上传本地缓存的日志
  Future<void> uploadLocalLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('local_logs') ?? [];
      
      for (final logJson in logs) {
        try {
          final logData = jsonDecode(logJson);
          await _logToCloud(
            operation: logData['operation'],
            content: logData['content'],
          );
        } catch (e) {
          print('上传本地日志条目失败: $e');
        }
      }
      
      // 清空本地日志
      await prefs.setStringList('local_logs', []);
    } catch (e) {
      print('上传本地缓存日志失败: $e');
    }
  }

  // 立即上传本地日志（不等待）
  void uploadLocalLogsNow() {
    // 在后台上传本地日志
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final logs = prefs.getStringList('local_logs') ?? [];
        
        for (final logJson in logs) {
          try {
            final logData = jsonDecode(logJson);
            await _logToCloud(
              operation: logData['operation'],
              content: logData['content'],
            );
          } catch (e) {
            print('上传本地日志条目失败: $e');
          }
        }
        
        // 清空本地日志
        await prefs.setStringList('local_logs', []);
      } catch (e) {
        print('上传本地缓存日志失败: $e');
      }
    });
  }
}




