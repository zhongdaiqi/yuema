import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/cloud_log_service.dart'; // 添加云日志服务导入
import '../services/api_service.dart'; // 添加API服务导入
import '../services/session_service.dart'; // 添加会话服务导入

// 登录结果类
class HuaweiLoginResult {
  final bool success;
  final String? message;
  final dynamic user; // 用户信息

  HuaweiLoginResult({
    required this.success,
    this.message,
    this.user,
  });
}

class HuaweiLoginService {
  // 调用后端华为登录接口
  static Future<HuaweiLoginResult> loginWithAuthCode(
    String authCode, {
    String? avatarUri,
    String? nickName,
  }) async {
    try {
      // 这里应该调用后端API进行登录
      // 为了演示，我将使用一个模拟实现
      // 实际实现中应该调用API服务
      final cloudLog = CloudLogService();
      await cloudLog.logLoginStart('huawei_auth_code');
      
      // 调用后端API进行华为登录
      final result = await ApiService.huaweiLogin(
        code: authCode,
      );
      
      if (result['success'] == true) {
        // 登录成功，保存用户认证信息到本地会话
        final session = await SessionService.getInstance();
        final userData = result['data'];
        await session.setAuthToken(userData['token'] ?? '');
        await session.setUserId(userData['id'].toString());
        await session.setUsername(userData['nickname'] ?? '');
        
        return HuaweiLoginResult(
          success: true,
          user: userData,
        );
      } else {
        // 检查是否是协议未同意错误，如果是则返回用户友好的提示
        String errorMessage = result['message'] ?? '华为登录失败';
        if (errorMessage.contains('accept the agreement') || errorMessage.contains('未接受协议')) {
          errorMessage = '请阅读并同意协议';
        }
        
        return HuaweiLoginResult(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e) {
      final cloudLog = CloudLogService();
      await cloudLog.logError('huawei_login_error', e.toString());
      
      return HuaweiLoginResult(
        success: false,
        message: '华为登录失败: $e',
      );
    }
  }
}