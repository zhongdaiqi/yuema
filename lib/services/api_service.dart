import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kReleaseMode, kDebugMode;
import 'package:http_parser/http_parser.dart';
import './session_service.dart';
import './cloud_log_service.dart'; // 导入云日志服务
import '../screens/login_screen.dart'; // 导入登录屏幕
import 'package:flutter/widgets.dart'; // 用于BuildContext访问
import 'package:flutter/material.dart'; // 用于显示SnackBar

class ApiService {
  static const String _devBaseUrl = 'http://localhost';
  static const String _prodBaseUrl = 'https://yuema.zuime.com';

  // 微信开放平台配置（iOS 回跳三处必须一致，见 wechat_login_service.dart 注释）
  static const String wechatAppId = 'wxff760c510b1c8b20';
  static const String wechatUniversalLink = 'https://yuema.zuime.com/app/';

  // 根据运行环境确定baseUrl
  static String get baseUrl {
    if (kReleaseMode) {
      return _prodBaseUrl;
    } else {
      return _devBaseUrl;
    }
  }

  // 全局上下文，用于显示错误消息
  static BuildContext? _globalContext;

  // 设置全局上下文
  static void setGlobalContext(BuildContext context) {
    _globalContext = context;
  }

  // 检查HTTP响应状态码
  static void _checkResponseStatus(http.Response response) {
    if (response.statusCode == 401) {
      // 登录失效，清除会话并提示用户重新登录
      _handleUnauthorized();
    }
  }

  // 处理未授权错误
  static void _handleUnauthorized() async {
    // 清除会话数据
    final session = await SessionService.getInstance();
    await session.clearSession();

    // 显示错误消息
    if (_globalContext != null) {
      // 确保在主线程上执行UI操作
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(_globalContext!).showSnackBar(
          const SnackBar(content: Text('登录已失效，请重新登录')),
        );

        // 导航到登录页面
        Navigator.pushAndRemoveUntil(
          _globalContext!,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      });
    }
  }

  // UTF-8解码函数，确保正确处理中文字符
  static String _decodeUtf8ResponseBody(http.Response response) {
    // 尝试从响应头获取字符集
    String contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('charset=gbk') ||
        contentType.contains('charset=gb2312')) {
      // 如果是GBK或GB2312编码，需要特殊处理
      try {
        // 这里可以添加特定编码的处理逻辑
        // 目前我们仍然使用UTF-8，因为大多数现代API应该使用UTF-8
        return utf8.decode(response.bodyBytes);
      } catch (e) {
        // 如果UTF-8解码失败，回退到默认方式
        return response.body;
      }
    } else {
      // 默认使用UTF-8解码
      try {
        return utf8.decode(response.bodyBytes);
      } catch (e) {
        // 如果UTF-8解码失败，回退到默认方式
        return response.body;
      }
    }
  }

  // 注册用户
  static Future<Map<String, dynamic>> registerUser({
    required String username,
    required String password,
    required String nickname,
    String? avatar,
  }) async {
    final url = Uri.parse('$baseUrl/api/user/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'nickname': nickname,
        'appId': 'com.zuime.yuema',
        if (avatar != null) 'avatar': avatar,
      }),
    );

    final responseBody = _decodeUtf8ResponseBody(response);
    return jsonDecode(responseBody);
  }

  // 用户登录
  static Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/user/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'appId': 'com.zuime.yuema',
      }),
    );

    final responseBody = _decodeUtf8ResponseBody(response);
    final result = jsonDecode(responseBody);

    // 如果登录成功，保存认证信息
    if (result is Map<String, dynamic> && result['success'] == true) {
      print('Login successful, saving session data: ${result['data']}');
      final session = await SessionService.getInstance();
      await session.setAuthToken(result['data']?['token'] ?? '');
      await session.setUserId(result['data']?['id']?.toString() ?? '');
      await session.setUsername(username);
    }

    return result;
  }

  /// 微信授权登录：用微信授权 code 换取后端会话
  /// POST /api/user/wxlogin  body={appId, code}
  /// 返回 {success, message, data:{id, nickname, avatar, token, expire_time}}
  /// 注意：会话写入由 WechatLoginService 统一处理，这里只做请求与解码，
  /// 避免 Sso 写入逻辑分散两处（与 loginUser 的写法不同是有意为之）。
  static Future<Map<String, dynamic>> wechatLogin({
    required String appId,
    required String code,
  }) async {
    final url = Uri.parse('$baseUrl/api/user/wxlogin');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'appId': appId, 'code': code}),
      );
      final responseBody = _decodeUtf8ResponseBody(response);
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) return decoded;
      return {
        'success': false,
        'message': '微信登录响应格式异常',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '网络请求失败，请检查网络后重试',
      };
    }
  }

  // 上传头像
  static Future<Map<String, dynamic>?> uploadAvatar({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      // 创建一个完整的多部件请求
      final uri = Uri.parse('$baseUrl/api/user/avator/upload');
      final request = http.MultipartRequest('POST', uri);

      // 添加适当的头部（上传接口需要登录态，必须带访问令牌）
      request.headers['Accept'] = 'application/json';
      final sessionForUpload = await SessionService.getInstance();
      if (sessionForUpload.authToken != null &&
          sessionForUpload.authToken!.isNotEmpty) {
        request.headers['Authorization'] =
            'Bearer ${sessionForUpload.authToken}';
      }

      // 确保文件名有合适的扩展名，并使用标准英文名
      String finalFileName = fileName;
      String contentType = 'image/jpeg'; // 默认内容类型

      if (!fileName.contains('.')) {
        // 如果文件名没有扩展名，添加一个默认的
        finalFileName = 'avatar.jpg';
      } else {
        // 根据扩展名确定内容类型
        final extension = fileName.split('.').last.toLowerCase();
        switch (extension) {
          case 'png':
            finalFileName = 'avatar.png';
            contentType = 'image/png';
            break;
          case 'gif':
            finalFileName = 'avatar.gif';
            contentType = 'image/gif';
            break;
          case 'jpeg':
          case 'jpg':
            finalFileName = 'avatar.jpg';
            contentType = 'image/jpeg';
            break;
          default:
            // 不识别的格式使用jpg作为默认
            finalFileName = 'avatar.jpg';
            contentType = 'image/jpeg';
        }
      }

      // 添加文件部分
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: finalFileName,
        contentType:
            MediaType(contentType.split('/')[0], contentType.split('/')[1]),
      );

      request.files.add(multipartFile);

      // 打印调试信息
      print('Sending file with name: $finalFileName');
      print('Content type: $contentType');
      print('File size: ${fileBytes.length} bytes');

      // 发送请求并获取响应
      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      // 打印响应以便调试
      print('Upload response status: ${response.statusCode}');
      print('Upload response body: $respStr');

      if (respStr.isNotEmpty) {
        final decoded = json.decode(respStr);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          return {
            'success': false,
            'message': '服务器响应格式错误',
          };
        }
      } else {
        return {
          'success': false,
          'message': '服务器返回空响应',
        };
      }
    } catch (e, stackTrace) {
      print('Upload error: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': '上传过程中发生错误: $e',
      };
    }
  }

  // 更新用户头像
  static Future<Map<String, dynamic>> updateAvatar({
    required String avatarUrl,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/avator/update');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'avatorUrl': avatarUrl,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error updating avatar: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 创建笔记
  static Future<Map<String, dynamic>> createNote(
      Map<String, dynamic> noteData) async {
    try {
      final session = await SessionService.getInstance();
      print('Creating note with auth token: ${session.authToken}');

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/create');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(noteData),
      );

      print('Create note response status: ${response.statusCode}');
      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error creating note: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取主页笔记列表
  static Future<Map<String, dynamic>> getHomeNotes({
    required int page,
    required int size,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/note/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting home notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取活动笔记列表
  static Future<Map<String, dynamic>> getActivityNotes({
    required int page,
    required int size,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/note/activity/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting activity notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取笔记详情
  static Future<Map<String, dynamic>> getNoteDetail({
    required int noteId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/note');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting note detail: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取笔记详情（包含活动报名统计信息）
  static Future<Map<String, dynamic>> getNoteDetailWithStats({
    required int noteId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/note');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting note detail with stats: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 点赞笔记
  static Future<Map<String, dynamic>> likeNote({
    required int noteId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/like');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error liking note: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 取消点赞笔记
  static Future<Map<String, dynamic>> unlikeNote({
    required int noteId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/unlike');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error unliking note: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 收藏笔记
  static Future<Map<String, dynamic>> collectNote({
    required int noteId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/collect');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error collecting note: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 取消收藏笔记
  static Future<Map<String, dynamic>> uncollectNote({
    required int noteId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/uncollect');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error uncollecting note: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 关注用户
  static Future<Map<String, dynamic>> followUser({
    required int noteId,
    required int followUserId,
    String flowFrom = '笔记',
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/follow');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'noteId': noteId,
          'appId': 'com.zuime.yuema',
          'followUserId': followUserId,
          'flowFrom': flowFrom,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error following user: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 取消关注用户
  static Future<Map<String, dynamic>> unfollowUser({
    required int followUserId,
    String flowFrom = '笔记',
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/unfollow');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'followUserId': followUserId,
          'flowFrom': flowFrom,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error unfollowing user: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取用户关注列表
  static Future<Map<String, dynamic>> getUserFollowList({
    required int noteId,
    int page = 1,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/follow/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'noteId': noteId,
          'appId': 'com.zuime.yuema',
          'page': page,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting user follow list: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 加入活动笔记
  static Future<Map<String, dynamic>> joinActivity({
    required int noteId,
    required String name,
    required String phone,
    String? wxId,
    String? address,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/join');

      final Map<String, dynamic> requestData = {
        'appId': 'com.zuime.yuema',
        'noteId': noteId,
        'name': name,
        'phone': phone,
      };

      if (wxId != null) {
        requestData['wxId'] = wxId;
      }

      if (address != null) {
        requestData['address'] = address;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(requestData),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error joining activity: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取活动报名列表
  static Future<Map<String, dynamic>> getActivityJoinList({
    required int noteId,
    int page = 1,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/join/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
          'page': page,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting activity join list: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 通过活动审核
  static Future<Map<String, dynamic>> passActivity({
    required int noteId,
    required int userId,
    String? memo,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/pass');

      final Map<String, dynamic> requestData = {
        'appId': 'com.zuime.yuema',
        'noteId': noteId,
        'userId': userId,
      };

      if (memo != null) {
        requestData['memo'] = memo;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(requestData),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error passing activity: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 拒绝活动审核
  static Future<Map<String, dynamic>> rejectActivity({
    required int noteId,
    required int userId,
    String? memo,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/reject');

      final Map<String, dynamic> requestData = {
        'appId': 'com.zuime.yuema',
        'noteId': noteId,
        'userId': userId,
      };

      if (memo != null) {
        requestData['memo'] = memo;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(requestData),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error rejecting activity: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取用户主页信息
  static Future<Map<String, dynamic>> getUserProfile({
    required int userId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/user');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'userId': userId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting user profile: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取用户发布的笔记列表
  static Future<Map<String, dynamic>> getUserNotes({
    required int userId,
    int page = 1,
    int size = 10,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/user/note/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'userId': userId,
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting user notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取用户发布的活动笔记列表
  static Future<Map<String, dynamic>> getUserActivityNotes({
    required int userId,
    int page = 1,
    int size = 10,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/user/note/activity/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'userId': userId,
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting user activity notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取用户收藏的笔记列表
  static Future<Map<String, dynamic>> getUserCollectedNotes({
    required int userId,
    int page = 1,
    int size = 10,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/home/user/note/collect/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'userId': userId,
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting user collected notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取个人主页信息
  static Future<Map<String, dynamic>> getPersonalInfo() async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/info');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting personal info: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取个人发布的笔记列表
  static Future<Map<String, dynamic>> getPersonalNotes({
    int page = 1,
    int size = 10,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting personal notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取个人发布的活动笔记列表
  static Future<Map<String, dynamic>> getPersonalActivityNotes({
    int page = 1,
    int size = 10,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/activity/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting personal activity notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取个人参与的活动笔记列表
  static Future<Map<String, dynamic>> getPersonalJoinedActivities({
    int page = 1,
    int size = 10,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/activity/join/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting personal joined activities: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 更新用户签名
  static Future<Map<String, dynamic>> updateSignature({
    required String signature,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/signature');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'signature': signature,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error updating signature: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取个人收藏的笔记列表
  static Future<Map<String, dynamic>> getPersonalCollectedNotes({
    int page = 1,
    int size = 10,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/collect/list');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'page': page,
          'size': size,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error getting personal collected notes: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 删除笔记
  static Future<Map<String, dynamic>> deleteNote({
    required int noteId,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/delete');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'noteId': noteId,
        }),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error deleting note: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 更新笔记
  static Future<Map<String, dynamic>> updateNote({
    required int noteId,
    required String noteTitle,
    required String noteContent,
    required String coverImgUrl,
    List<String>? notePhotos,
    required String noteType,
    required String noteTag,
    required int noteStatus,
    String? startTime,
    String? endTime,
    String? address,
  }) async {
    try {
      final session = await SessionService.getInstance();

      // 检查用户是否已登录
      if (!session.isLoggedIn) {
        return {
          'success': false,
          'message': '用户未登录',
        };
      }

      final url = Uri.parse('$baseUrl/api/user/note/update');

      final Map<String, dynamic> requestBody = {
        'noteId': noteId,
        'noteTitle': noteTitle,
        'noteContent': noteContent,
        'coverImgUrl': coverImgUrl,
        'noteType': noteType,
        'noteTag': noteTag,
        'noteStatus': noteStatus,
        'appId': 'com.zuime.yuema',
      };

      // 可选参数
      if (notePhotos != null) {
        requestBody['notePhotos'] = notePhotos;
      }

      if (startTime != null) {
        requestBody['startTime'] = startTime;
      }

      if (endTime != null) {
        requestBody['endTime'] = endTime;
      }

      if (address != null) {
        requestBody['address'] = address;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(requestBody),
      );

      // 检查响应状态码
      _checkResponseStatus(response);

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error updating note: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 华为账号登录
  static Future<Map<String, dynamic>> huaweiLogin({
    required String code,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/user/hwlogin');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'code': code,
        }),
      );

      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error huawei login: $e');
      return {
        'success': false,
        'message': '网络请求失败',
      };
    }
  }

  // 获取龙珠活动应用列表
  static Future<Map<String, dynamic>> getLongZhuApps({int page = 1, int size = 20}) async {
    final session = await SessionService.getInstance();

    // 检查用户是否已登录
    if (!session.isLoggedIn) {
      final cloudLog = CloudLogService();
      cloudLog.logGetLongZhuAppsFailure('用户未登录');
      return {
        'success': false,
        'message': '用户未登录',
      };
    }

    // 在请求之前记录日志
    final cloudLog = CloudLogService();
    cloudLog.logGetLongZhuAppsStart(page, size);

    // 构建完整的URL
    final fullUrl = '$baseUrl/api/user/longzhu/list';
    
    // 记录完整的请求信息到日志（根据规范：在发起API请求之前，必须使用云端日志服务记录将要调用的接口地址、HTTP方法及所有请求参数）
    final requestParams = {'page': page, 'size': size};
    cloudLog.logApiCallWithParams(fullUrl, 'POST', requestParams);
    
    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(<String, dynamic>{
          'page': page,
          'size': size,
        }),
      );

      if (response.statusCode == 200) {
        try {
          final responseBody = _decodeUtf8ResponseBody(response);
          final result = jsonDecode(responseBody);
          if (result['success'] == true) {
            cloudLog.logGetLongZhuAppsSuccess((result['data'] as List?)?.length ?? 0);
          } else {
            cloudLog.logGetLongZhuAppsFailure(result['message'] ?? '获取龙珠活动应用列表失败');
          }
          return result;
        } catch (e) {
          cloudLog.logGetLongZhuAppsFailure('响应解析失败: $e');
          throw Exception('响应解析失败: $e');
        }
      } else {
        cloudLog.logGetLongZhuAppsFailure('HTTP错误: ${response.statusCode}');
        throw Exception('获取龙珠活动应用列表失败: ${response.statusCode}');
      }
    } catch (e) {
      // 记录网络请求失败的详细信息
      cloudLog.logError('api_call_failed', 'API调用失败: $fullUrl, 参数: ${jsonEncode({'page': page, 'size': size})}, 错误: $e');
      rethrow;
    }
  }

  // 用户领取龙珠
  static Future<Map<String, dynamic>> claimLongZhu({required String appId, required String deviceId}) async {
    final session = await SessionService.getInstance();

    // 检查用户是否已登录
    if (!session.isLoggedIn) {
      final cloudLog = CloudLogService();
      cloudLog.logLongZhuClaimFailure(appId, deviceId, '用户未登录');
      return {
        'success': false,
        'message': '用户未登录',
      };
    }

    // 强制使用当前应用ID（根据业务规则：每个应用只能领取自身龙珠）
    const currentAppId = 'com.zuime.yuema';
    
    // 在请求之前记录日志
    final cloudLog = CloudLogService();
    cloudLog.logLongZhuClaimStart(currentAppId, deviceId);

    // 构建完整的URL
    final fullUrl = '$baseUrl/api/user/longzhu';
    
    // 记录完整的请求信息到日志（根据规范：在发起API请求之前，必须使用云端日志服务记录将要调用的接口地址、HTTP方法及所有请求参数）
    final requestParams = {'appId': currentAppId, 'deviceId': deviceId};
    cloudLog.logApiCallWithParams(fullUrl, 'POST', requestParams);
    
    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(<String, dynamic>{
          'appId': currentAppId,  // 使用固定的当前应用ID
          'deviceId': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        try {
          final responseBody = _decodeUtf8ResponseBody(response);
          final result = jsonDecode(responseBody);
          if (result['success'] == true) {
            cloudLog.logLongZhuClaimSuccess(currentAppId, deviceId, result['data'] ?? {});
          } else {
            cloudLog.logLongZhuClaimFailure(currentAppId, deviceId, result['message'] ?? '领取龙珠失败');
          }
          return result;
        } catch (e) {
          cloudLog.logLongZhuClaimFailure(currentAppId, deviceId, '响应解析失败: $e');
          throw Exception('响应解析失败: $e');
        }
      } else {
        cloudLog.logLongZhuClaimFailure(currentAppId, deviceId, 'HTTP错误: ${response.statusCode}');
        throw Exception('领取龙珠失败: ${response.statusCode}');
      }
    } catch (e) {
      // 记录网络请求失败的详细信息
      cloudLog.logError('api_call_failed', 'API调用失败: $fullUrl, 参数: ${jsonEncode({'appId': currentAppId, 'deviceId': deviceId})}, 错误: $e');
      rethrow;
    }
  }

  // 用户激活龙珠
  static Future<Map<String, dynamic>> activateLongZhu({required String appId}) async {
    final session = await SessionService.getInstance();

    // 检查用户是否已登录
    if (!session.isLoggedIn) {
      final cloudLog = CloudLogService();
      cloudLog.logLongZhuActivateFailure(appId, '用户未登录');
      return {
        'success': false,
        'message': '用户未登录',
      };
    }

    // 强制使用当前应用ID（根据业务规则：每个应用只能领取自身龙珠）
    const currentAppId = 'com.zuime.yuema';
    
    // 在请求之前记录日志
    final cloudLog = CloudLogService();
    cloudLog.logLongZhuActivateStart(currentAppId);

    // 构建完整的URL
    final fullUrl = '$baseUrl/api/user/longzhu/active';
    
    // 记录完整的请求信息到日志（根据规范：在发起API请求之前，必须使用云端日志服务记录将要调用的接口地址、HTTP方法及所有请求参数）
    final requestParams = {'appId': currentAppId};
    cloudLog.logApiCallWithParams(fullUrl, 'POST', requestParams);
    
    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode(<String, dynamic>{
          'appId': currentAppId,  // 使用固定的当前应用ID
        }),
      );

      if (response.statusCode == 200) {
        try {
          final responseBody = _decodeUtf8ResponseBody(response);
          final result = jsonDecode(responseBody);
          if (result['success'] == true) {
            cloudLog.logLongZhuActivateSuccess(currentAppId, result['data']?['longZhuCode'] ?? '', result['data']?['activeTime'] ?? '');
          } else {
            cloudLog.logLongZhuActivateFailure(currentAppId, result['message'] ?? '激活龙珠失败');
          }
          return result;
        } catch (e) {
          cloudLog.logLongZhuActivateFailure(currentAppId, '响应解析失败: $e');
          throw Exception('响应解析失败: $e');
        }
      } else {
        cloudLog.logLongZhuActivateFailure(currentAppId, 'HTTP错误: ${response.statusCode}');
        throw Exception('激活龙珠失败: ${response.statusCode}');
      }
    } catch (e) {
      // 记录网络请求失败的详细信息
      cloudLog.logError('api_call_failed', 'API调用失败: $fullUrl, 参数: ${jsonEncode({'appId': currentAppId})}, 错误: $e');
      rethrow;
    }
  }

  /// 注销当前账号（App Store 5.1.1(v) 自助注销）
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final session = await SessionService.getInstance();
      if (!session.isLoggedIn) {
        return {'success': false, 'message': '用户未登录'};
      }

      final url = Uri.parse('$baseUrl/api/user/delete-account');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({'appId': 'com.zuime.yuema'}),
      );

      _checkResponseStatus(response);
      final responseBody = _decodeUtf8ResponseBody(response);
      return jsonDecode(responseBody);
    } catch (e) {
      print('Error deleting account: $e');
      return {'success': false, 'message': '网络请求失败'};
    }
  }

  /// 举报违规内容
  static Future<Map<String, dynamic>> reportContent({
    required int noteId,
    required String reportType,
    String reason = '',
  }) async {
    try {
      final session = await SessionService.getInstance();
      if (!session.isLoggedIn) {
        return {'success': false, 'message': '用户未登录'};
      }
      final url = Uri.parse('$baseUrl/api/user/report');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'noteId': noteId,
          'reportType': reportType,
          'reason': reason,
        }),
      );
      _checkResponseStatus(response);
      return jsonDecode(_decodeUtf8ResponseBody(response));
    } catch (e) {
      print('Error reporting content: $e');
      return {'success': false, 'message': '网络请求失败'};
    }
  }

  /// 屏蔽用户
  static Future<Map<String, dynamic>> blockUser(int blockedUserId) async {
    try {
      final session = await SessionService.getInstance();
      if (!session.isLoggedIn) {
        return {'success': false, 'message': '用户未登录'};
      }
      final url = Uri.parse('$baseUrl/api/user/block');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({
          'appId': 'com.zuime.yuema',
          'blockedUserId': blockedUserId,
        }),
      );
      _checkResponseStatus(response);
      return jsonDecode(_decodeUtf8ResponseBody(response));
    } catch (e) {
      print('Error blocking user: $e');
      return {'success': false, 'message': '网络请求失败'};
    }
  }

  /// 取消屏蔽用户
  static Future<Map<String, dynamic>> unblockUser(int blockedUserId) async {
    try {
      final session = await SessionService.getInstance();
      if (!session.isLoggedIn) {
        return {'success': false, 'message': '用户未登录'};
      }
      final url = Uri.parse('$baseUrl/api/user/unblock');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.authToken}',
        },
        body: jsonEncode({'blockedUserId': blockedUserId}),
      );
      _checkResponseStatus(response);
      return jsonDecode(_decodeUtf8ResponseBody(response));
    } catch (e) {
      print('Error unblocking user: $e');
      return {'success': false, 'message': '网络请求失败'};
    }
  }
}
