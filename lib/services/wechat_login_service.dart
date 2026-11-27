/**
 * 项目：约吗
 * 功能：微信授权登录（fluwx）
 *
 * 参考定制侠（dingzhixia）同名实现，但按约吗架构适配：
 *   - 会话写入只用 SessionService 的 3 个字段（token/userId/username）。
 *     定制侠还有昵称/头像的会话字段，约吗没有，不可照搬其会话写入代码。
 *   - 后端接口：POST {baseUrl}/api/user/wxlogin  body={appId, code}
 *     返回 {success, data:{id, nickname, avatar, token, expire_time}}
 *   - appId 是业务标识 com.zuime.yuema（后端据此查 wx_app_setting 表），
 *     不是微信开放平台 AppID。
 *
 * iOS 回跳三处必须一致（缺一不可，否则授权后无法回到 App）：
 *   1) 微信开放平台后台 Universal Links：https://yuema.zuime.com/app/
 *   2) 服务端 AASA：https://yuema.zuime.com/.well-known/apple-app-site-association
 *      appIDs 需含 <TEAMID>.com.zuime.yuema，paths 覆盖 /app/ 下的路径
 *   3) ios/Runner/Runner.entitlements 的 applinks:yuema.zuime.com
 *   URL Scheme = 微信开放平台 AppID（wxff760c510b1c8b20），见 Info.plist。
 *
 * 体验设计（与定制侠不同）：
 *   - 用户取消授权：回调 cancelled=true，页面静默处理，不弹错误。
 *   - 未安装微信：回调明确的失败文案（提示改用用户名密码登录）。
 *   - 授权成功但 code 为空 / 后端失败：明确文案，不把原始异常抛给用户。
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fluwx/fluwx.dart';

import 'api_service.dart';
import 'cloud_log_service.dart';
import 'session_service.dart';

/// 微信登录结果
class WechatLoginResult {
  final bool success;
  final String? message;

  /// 是否为用户主动取消（页面据此静默处理，不弹提示）
  final bool cancelled;

  const WechatLoginResult({
    required this.success,
    this.message,
    this.cancelled = false,
  });
}

class WechatLoginService {
  WechatLoginService._();

  /// 业务 appId（后端 wx_app_setting 表的 key）
  static const String appId = 'com.zuime.yuema';

  static bool _initialized = false;
  static final Fluwx _fluwx = Fluwx();
  static void Function(WeChatResponse)? _responseHandler;
  static void Function(WechatLoginResult)? _resultCallback;

  /// 是否已初始化
  static bool get isInitialized => _initialized;

  /// 初始化微信 SDK（幂等）。进入登录页时调用一次即可。
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await _fluwx.registerApi(
        appId: ApiService.wechatAppId,
        doOnAndroid: true,
        doOnIOS: true,
        universalLink: ApiService.wechatUniversalLink,
      );
      _setupResponseListener();
      _initialized = true;
      await _log('wechat_init_success', '微信登录服务初始化成功');
    } catch (e) {
      await _log('wechat_init_error', '微信登录服务初始化失败: $e');
      rethrow;
    }
  }

  /// 检查微信是否已安装（fluwx 要求先 init）
  static Future<bool> isWeChatInstalled() async {
    try {
      if (!_initialized) await init();
      final installed = await _fluwx.isWeChatInstalled;
      await _log('wechat_check_installed', 'installed=$installed');
      return installed;
    } catch (e) {
      await _log('wechat_check_installed_error', '$e');
      return false;
    }
  }

  /// 发起微信授权登录。
  /// 结果（成功/失败/取消）统一通过 [onResult] 回调给出：
  /// 授权结果走 fluwx 的 WeChatResponse 订阅，无法同步返回，故用回调。
  static Future<void> signIn({
    required void Function(WechatLoginResult result) onResult,
  }) async {
    _resultCallback = onResult;
    try {
      if (!_initialized) await init();

      final installed = await isWeChatInstalled();
      if (!installed) {
        _finish(const WechatLoginResult(
            success: false, message: '未检测到微信，请先安装微信或使用用户名密码登录'));
        return;
      }

      await _log('wechat_login_start', '发起 snsapi_userinfo 授权');
      await _fluwx.authBy(
        which: NormalAuth(
          scope: 'snsapi_userinfo',
          state: 'yuema_login_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    } catch (e) {
      await _log('wechat_login_error', '$e');
      _finish(const WechatLoginResult(
          success: false, message: '发起微信授权失败，请稍后重试'));
    }
  }

  /// 处理微信授权响应：拿 code → 调后端 → 写会话 → 回调结果
  static Future<void> _handleAuthResponse(WeChatAuthResponse response) async {
    try {
      if (response.isSuccessful == true &&
          response.code != null &&
          response.code!.isNotEmpty) {
        final code = response.code!;
        await _log('wechat_auth_success', 'code length=${code.length}');
        final result = await _loginWithCode(code);
        _finish(result);
        return;
      }

      final errCode = response.errCode ?? -1;
      // -6 = 用户取消授权：静默处理
      if (errCode == -6) {
        await _log('wechat_auth_cancelled', '用户取消授权');
        _finish(const WechatLoginResult(success: false, cancelled: true));
        return;
      }

      await _log('wechat_auth_failed', 'errCode=$errCode');
      _finish(const WechatLoginResult(
          success: false, message: '微信授权失败，请重试或改用用户名密码登录'));
    } catch (e) {
      await _log('wechat_auth_exception', '$e');
      _finish(const WechatLoginResult(
          success: false, message: '微信登录异常，请稍后重试'));
    }
  }

  /// 用 code 调后端登录并写会话
  static Future<WechatLoginResult> _loginWithCode(String code) async {
    try {
      await _log('wechat_backend_login_start', 'code length=${code.length}');
      final result = await ApiService.wechatLogin(appId: appId, code: code);

      if (result['success'] == true) {
        final data = result['data'];
        final Map<String, dynamic> user = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};

        final session = await SessionService.getInstance();
        final userId = (user['id'] ?? user['userId'] ?? '').toString();
        await session.setAuthToken((user['token'] ?? '').toString());
        await session.setUserId(userId);
        // 约吗 username 用于展示/会话标识：微信用户用昵称，缺省用 wx_<id> 兜底
        final nickname = (user['nickname'] ?? user['nickName'] ?? '').toString();
        await session.setUsername(
            nickname.isNotEmpty ? nickname : 'wx_$userId');

        await _log('wechat_login_success', 'userId=$userId');
        return const WechatLoginResult(success: true, message: '登录成功');
      }

      final msg = (result['message'] ?? '微信登录失败').toString();
      await _log('wechat_login_rejected', msg);
      return WechatLoginResult(success: false, message: msg);
    } catch (e) {
      await _log('wechat_login_exception', '$e');
      return const WechatLoginResult(
          success: false, message: '网络请求失败，请检查网络后重试');
    }
  }

  static void _finish(WechatLoginResult result) {
    final cb = _resultCallback;
    _resultCallback = null; // 一次性回调，防止重复
    cb?.call(result);
  }

  static void _setupResponseListener() {
    if (_responseHandler != null) {
      _fluwx.removeSubscriber(_responseHandler!);
    }
    _responseHandler = (response) {
      if (response is WeChatAuthResponse) {
        unawaited(_handleAuthResponse(response));
      }
    };
    _fluwx.addSubscriber(_responseHandler!);
  }

  /// 释放监听（App 退出时可选；登录页常驻，通常不必调用）
  static void dispose() {
    if (_responseHandler != null) {
      _fluwx.removeSubscriber(_responseHandler!);
      _responseHandler = null;
    }
    _resultCallback = null;
    _initialized = false;
  }

  static Future<void> _log(String operation, String content) async {
    try {
      await CloudLogService().logError(operation, content);
    } catch (_) {
      // 日志失败不影响登录主流程
    }
    debugPrint('[WechatLogin] $operation $content');
  }
}
