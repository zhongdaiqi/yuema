/**
 * 项目：约吗
 * 功能：原生 Sign in with Apple（iOS）
 *
 * 参考定制侠（dingzhixia）同名实现，后端已部署端点：
 *   POST /api/auth/apple/com.zuime.yuema/native
 *   body: {appId, identityToken, authorizationCode, userIdentifier, email, fullName}
 *   已实测：空 identityToken 时返回 {"success":false,"message":"identityToken 不能为空"}，
 *   说明端点与字段名均已就绪（2026-11-24 探测）。
 *
 * 后端安全：identityToken 由服务端拉 Apple JWKS 验签（iss/aud/exp/sub），
 * 客户端不做验签，只负责把原生凭证透传。
 *
 * 会话写入：yuema 的第三方登录成功返回为 {success:true, data:{token,id,nickname}}，
 * 但苹果端点可能沿用 dingzhixia 的扁平结构 {success:true,token,userId,nickname}，
 * 故两种结构都兼容（见 _extractSessionFields）。
 *
 * 平台：仅 iOS 支持原生 SIWA；Android/鸿蒙无 Apple SDK，登录页不显示该按钮。
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../screens/main_screen.dart';
import 'api_service.dart';
import 'cloud_log_service.dart';
import 'session_service.dart';

class AppleLoginService {
  AppleLoginService._();

  static const String appId = 'com.zuime.yuema';

  /// 是否支持原生 Sign in with Apple（仅 iOS）
  static bool get isSupported => Platform.isIOS;

  /// 发起原生 SIWA 登录：拿凭证 → POST 后端 → 写会话 → 跳主页。
  /// 失败用 SnackBar 提示，用户取消静默返回。
  static Future<void> signIn(BuildContext context) async {
    if (!isSupported) {
      _toast(context, '当前平台不支持 Apple 登录');
      return;
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        _toast(context, '苹果未返回登录凭证，请重试');
        return;
      }

      final result = await _loginToBackend(
        identityToken: identityToken,
        authorizationCode: credential.authorizationCode ?? '',
        userIdentifier: credential.userIdentifier ?? '',
        email: credential.email ?? '',
        fullName: _buildFullName(credential.givenName, credential.familyName),
      );

      if (result['success'] == true) {
        final fields = _extractSessionFields(result);
        final session = await SessionService.getInstance();
        await session.setAuthToken(fields['token']);
        await session.setUserId(fields['userId']);
        await session.setUsername(fields['nickname']);
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        _toast(context, result['message'] ?? 'Apple 登录失败，请重试');
      }
    } catch (e) {
      final msg = e.toString();
      // 用户主动取消不算错误（Apple 侧 error code 1001 / cancel 文案）
      if (msg.contains('cancel') || msg.contains('1001')) return;
      _toast(context, 'Apple 登录异常: $e');
      await _log('apple_native_login_exception', '原生 SIWA 流程异常: $e');
    }
  }

  /// 姓名拼接：苹果仅在首次授权返回 givenName/familyName
  static String _buildFullName(String? given, String? family) {
    final parts = [given, family].where((e) => e != null && e.isNotEmpty);
    return parts.join(' ').trim();
  }

  /// 提取会话字段：兼容后端扁平结构（dingzhixia 同款）与 yuema 的 data 包裹结构
  static Map<String, String> _extractSessionFields(
      Map<String, dynamic> result) {
    final data = result['data'];
    final Map<String, dynamic> src =
        data is Map ? Map<String, dynamic>.from(data) : result;
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = src[k];
        if (v != null) return v.toString();
      }
      return '';
    }

    return {
      'token': pick(['token', 'authToken']),
      'userId': pick(['userId', 'id']),
      'nickname': pick(['nickname', 'nickName']),
    };
  }

  /// 调后端原生 SIWA 端点。失败分三类给出可操作文案，并上云日志。
  static Future<Map<String, dynamic>> _loginToBackend({
    required String identityToken,
    required String authorizationCode,
    required String userIdentifier,
    required String email,
    required String fullName,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/auth/apple/$appId/native');
    final body = <String, dynamic>{
      'appId': appId,
      'identityToken': identityToken,
      'authorizationCode': authorizationCode,
      'userIdentifier': userIdentifier,
      'email': email,
      'fullName': fullName,
    };
    try {
      final response = await httpPostJson(url, body);

      if (response.statusCode != 200) {
        await _log(
          'apple_native_login_backend_error',
          'HTTP ${response.statusCode} | url=$url | '
              'body=${_clip(response.body)}',
        );
        return {
          'success': false,
          'message': 'Apple 登录服务暂不可用（HTTP ${response.statusCode}）',
        };
      }

      Map<String, dynamic> decoded;
      try {
        final json = jsonDecode(response.body);
        if (json is! Map<String, dynamic>) {
          throw const FormatException('response is not a JSON object');
        }
        decoded = json;
      } on FormatException catch (e) {
        await _log('apple_native_login_parse_error',
            'HTTP 200 但响应不是 JSON 对象: $e | body=${_clip(response.body)}');
        return {'success': false, 'message': 'Apple 登录服务响应异常'};
      }

      if (decoded['success'] != true) {
        await _log('apple_native_login_rejected',
            '后端业务拒绝: message=${decoded['message']}');
      }
      return decoded;
    } catch (e) {
      await _log('apple_native_login_network_error', '网络请求失败: $e | url=$url');
      return {'success': false, 'message': '网络请求失败，请检查网络后重试'};
    }
  }

  /// 用项目现有 http 包发 POST JSON（yuema 的 ApiService 未暴露 postJson）
  static Future<http.Response> httpPostJson(
      Uri url, Map<String, dynamic> body) {
    return http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  static String _clip(String text) =>
      text.length > 300 ? text.substring(0, 300) : text;

  static Future<void> _log(String operation, String content) async {
    try {
      await CloudLogService().logError(operation, content);
    } catch (_) {
      // 日志失败不影响登录主流程
    }
  }

  static void _toast(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
