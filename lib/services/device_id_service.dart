import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:math';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static DeviceIdService? _instance;
  static DeviceIdService get instance => _instance ??= DeviceIdService._();

  DeviceIdService._();

  /// 获取设备ID，如果不存在则生成一个新的
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 先尝试从本地存储获取已保存的设备ID
    String? savedDeviceId = prefs.getString(_deviceIdKey);
    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }

    // 如果没有保存的设备ID，则生成新的设备ID
    String newDeviceId = await _generateDeviceId();
    
    // 保存到本地存储
    await prefs.setString(_deviceIdKey, newDeviceId);
    
    return newDeviceId;
  }

  /// 生成设备ID
  Future<String> _generateDeviceId() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      // 首先尝试鸿蒙系统专用API
      try {
        OhosDeviceInfo ohosInfo = await deviceInfo.ohosInfo;
        // 在鸿蒙系统上，优先使用 odID（OpenHarmony 设备 ID）
        if (ohosInfo.odID != null && ohosInfo.odID!.isNotEmpty) {
          return 'ohos_${ohosInfo.odID}';
        }
        
        // 如果 odID 不可用，使用其他鸿蒙系统信息生成ID
        String combinedInfo = '';
        combinedInfo += ohosInfo.manufacture ?? '';
        combinedInfo += ohosInfo.brand ?? '';
        combinedInfo += ohosInfo.productModel ?? '';
        combinedInfo += ohosInfo.hardwareModel ?? '';
        combinedInfo += ohosInfo.versionId ?? '';
        
        if (combinedInfo.isNotEmpty) {
          return 'ohos_${combinedInfo.hashCode.abs()}'; // 使用绝对值确保正数
        }
      } catch (e) {
        print('无法获取鸿蒙设备信息: $e');
      }
      
      // 其他平台的回退方案
      try {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        
        // 检查是否有AndroidId在原始数据中
        String? androidId;
        if (androidInfo.data.containsKey('id')) {
          androidId = androidInfo.data['id'];
        } else if (androidInfo.data.containsKey('id')) {
          androidId = androidInfo.data['id'];
        }
        
        // 如果找到AndroidId，优先使用
        if (androidId != null && androidId.isNotEmpty) {
          return 'android_$androidId';
        }
        
        // 否则使用设备信息生成ID
        String combinedInfo = '';
        combinedInfo += androidInfo.board;
        combinedInfo += androidInfo.brand;
        combinedInfo += androidInfo.device;
        combinedInfo += androidInfo.model;
        combinedInfo += androidInfo.product;
        
        // 生成哈希值作为设备ID
        if (combinedInfo.isNotEmpty) {
          return 'android_${combinedInfo.hashCode.abs()}'; // 使用绝对值确保正数
        }
      } catch (e) {
        print('无法获取Android设备信息: $e');
      }
      
      try {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        // 在iOS上，使用identifierForVendor作为设备ID
        String? vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          return 'ios_$vendorId';
        }
      } catch (e) {
        print('无法获取iOS设备信息: $e');
      }
      
      try {
        WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        // 检查deviceId是否非空
        if (windowsInfo.deviceId.isNotEmpty) {
          return 'windows_${windowsInfo.deviceId}';
        }
      } catch (e) {
        print('无法获取Windows设备信息: $e');
      }
      
      try {
        MacOsDeviceInfo macOsInfo = await deviceInfo.macOsInfo;
        String? systemGuid = macOsInfo.systemGUID;
        if (systemGuid != null && systemGuid.isNotEmpty) {
          return 'macos_$systemGuid';
        }
      } catch (e) {
        print('无法获取macOS设备信息: $e');
      }
      
      try {
        LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
        String? machineId = linuxInfo.machineId;
        if (machineId != null && machineId.isNotEmpty) {
          return 'linux_$machineId';
        }
      } catch (e) {
        print('无法获取Linux设备信息: $e');
      }

      // 如果所有平台特定的方法都失败，使用备用方法
      return _generateFallbackId();
    } catch (e) {
      print('获取设备信息时出错: $e');
      // 出错时返回备用ID
      return _generateFallbackId();
    }
  }

  /// 生成备用ID（当无法获取特定平台的设备ID时）
  String _generateFallbackId() {
    // 使用时间戳生成一个唯一的备用ID
    return 'fallback_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  /// 生成随机字符串
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final StringBuffer buffer = StringBuffer();
    final Random random = Random();

    for (int i = 0; i < length; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }
}