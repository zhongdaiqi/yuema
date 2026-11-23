import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

// 简单模拟设备信息用于测试
class MockDeviceIdService {
  static const String _deviceIdKey = 'device_id';

  /// 生成设备ID的模拟实现
  String generateMockDeviceId() {
    // 返回一个固定的测试ID
    return 'test_device_id_${DateTime.now().millisecondsSinceEpoch}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdService Mock Tests', () {
    setUp(() async {
      // 初始化SharedPreferences以供测试使用
      SharedPreferences.setMockInitialValues({});
    });

    test('Should generate mock device ID', () async {
      final service = MockDeviceIdService();
      
      // 生成设备ID
      final deviceId = service.generateMockDeviceId();
      
      // 验证设备ID不为空
      expect(deviceId, isNotNull);
      expect(deviceId, isNotEmpty);
      expect(deviceId.contains('test_device_id_'), isTrue);
      
      print('Generated Mock Device ID: $deviceId');
    });
  });

  group('DeviceInfoPlus Tests', () {
    test('Can initialize DeviceInfoPlugin', () async {
      // 测试可以初始化插件
      final deviceInfo = DeviceInfoPlugin();
      expect(deviceInfo, isNotNull);
    });
  });
}