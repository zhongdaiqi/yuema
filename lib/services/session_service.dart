import 'package:shared_preferences/shared_preferences.dart';
import './cloud_log_service.dart';

class SessionService {
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  static SessionService? _instance;
  static late SharedPreferences _prefs;

  String? _authToken;
  String? _userId;
  String? _username;

  SessionService._internal();

  static Future<SessionService> getInstance() async {
    try {
      _instance ??= SessionService._internal();

      // 添加额外的安全检查
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e) {
        print('SharedPreferences初始化失败: $e');
        // 使用模拟的SharedPreferences
        SharedPreferences.setMockInitialValues({});
        _prefs = await SharedPreferences.getInstance();
      }

      // 安全地读取数据
      _instance!._authToken = _prefs.getString(_authTokenKey) ?? '';
      _instance!._userId = _prefs.getString(_userIdKey) ?? '';
      _instance!._username = _prefs.getString(_usernameKey) ?? '';

      print(
          '✅ Loaded session data: token=${_instance!._authToken}, userId=${_instance!._userId}, username=${_instance!._username}');

      return _instance!;
    } catch (e, stackTrace) {
      print('❌ SessionService初始化失败: $e');
      print('堆栈跟踪: $stackTrace');
      
      // 记录错误到云端
      try {
        await CloudLogService().logError('session_service_init_failure', 
            'SessionService初始化失败: $e\nStack trace: $stackTrace');
      } catch (logError) {
        print('记录SessionService错误失败: $logError');
      }
      
      // 创建一个安全的空实例
      _instance ??= SessionService._internal();
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e) {
        SharedPreferences.setMockInitialValues({});
        _prefs = await SharedPreferences.getInstance();
      }
      return _instance!;
    }
  }

  String? get authToken => _authToken;
  String? get userId => _userId;
  String? get username => _username;

  bool get isLoggedIn {
    print('Checking login status: token=$_authToken');
    return _authToken != null && _authToken!.isNotEmpty;
  }

  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    print('Setting auth token: $token');
    if (token != null) {
      await _prefs.setString(_authTokenKey, token);
    } else {
      await _prefs.remove(_authTokenKey);
    }
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;
    if (userId != null) {
      await _prefs.setString(_userIdKey, userId);
    } else {
      await _prefs.remove(_userIdKey);
    }
  }

  Future<void> setUsername(String? username) async {
    _username = username;
    if (username != null) {
      await _prefs.setString(_usernameKey, username);
    } else {
      await _prefs.remove(_usernameKey);
    }
  }

  Future<void> clearSession() async {
    _authToken = null;
    _userId = null;
    _username = null;
    await _prefs.remove(_authTokenKey);
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_usernameKey);
  }
}
