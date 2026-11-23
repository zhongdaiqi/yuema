import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 用于剪贴板功能
import 'package:url_launcher/url_launcher.dart'; // 用于打开外部链接
import '../services/api_service.dart';
import '../services/device_id_service.dart';
import '../services/cloud_log_service.dart'; // 添加云日志服务导入

class LongZhuScreen extends StatefulWidget {
  const LongZhuScreen({super.key});

  @override
  State<LongZhuScreen> createState() => _LongZhuScreenState();
}

class _LongZhuScreenState extends State<LongZhuScreen> {
  bool _isLoading = false;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  String _countdownMessage = '';
  bool _canActivate = false;
  String? _longZhuCode;
  String? _activeTime;
  List<Map<String, dynamic>> _appsList = [];
  String? _currentAppId;
  bool _isFindingLongZhu = false;  // 新增标志，表示正在寻找龙珠

  @override
  void initState() {
    super.initState();
    _loadLongZhuApps();
    
    // 记录页面访问日志
    final cloudLog = CloudLogService();
    cloudLog.logLongZhuScreenView();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 格式化日期时间显示
  String _formatDateTime(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      // 如果解析失败，返回原字符串
      return dateTimeString;
    }
  }

  // 检查URL是否有效
  bool _isValidUrl(String url) {
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  // 安全构建网络图片
  Widget _buildNetworkImage({
    required String imageUrl,
    required double width,
    required double height,
    required BoxFit fit,
    Widget? placeholder,
  }) {
    if (!_isValidUrl(imageUrl)) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: placeholder ?? const Icon(Icons.image),
      );
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: placeholder ?? const Icon(Icons.image),
        );
      },
    );
  }

  // 加载龙珠活动应用列表
  Future<void> _loadLongZhuApps() async {
    setState(() {
      _isLoading = true;
    });

    // 记录获取龙珠活动应用列表开始
    final cloudLog = CloudLogService();
    cloudLog.logGetLongZhuAppsStart(1, 20);

    try {
      final result = await ApiService.getLongZhuApps(page: 1, size: 20);
      if (result['success'] == true) {
        setState(() {
          _appsList = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
        
        // 记录获取龙珠活动应用列表成功
        cloudLog.logGetLongZhuAppsSuccess(_appsList.length);
      } else {
        // 记录获取龙珠活动应用列表失败
        cloudLog.logGetLongZhuAppsFailure(result['message'] ?? '获取龙珠活动应用列表失败');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '获取龙珠活动应用列表失败')),
          );
        }
      }
    } catch (e) {
      // 记录获取龙珠活动应用列表失败
      cloudLog.logGetLongZhuAppsFailure(e.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络请求失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 领取龙珠
  Future<void> _claimLongZhu(String appId) async {
    setState(() {
      _isLoading = true;
      _isFindingLongZhu = true;  // 开始寻找龙珠
    });

    try {
      // 获取设备ID
      String deviceId = await DeviceIdService.instance.getDeviceId();
      
      // 记录龙珠领取开始
      final cloudLog = CloudLogService();
      cloudLog.logLongZhuClaimStart(appId, deviceId);

      // 先显示倒计时，模拟寻找龙珠过程
      _startFindingLongZhuCountdown();

      // 等待倒计时结束后再发起请求
      await Future.delayed(const Duration(seconds: 10));

      // 倒计时结束后，发起真正的请求
      final result = await ApiService.claimLongZhu(appId: appId, deviceId: deviceId);
      if (result['success'] == true) {
        final data = result['data'];
        final createTime = DateTime.parse(data['createTime']);
        final duration = data['duration'] as int;
        
        // 记录龙珠领取成功
        cloudLog.logLongZhuClaimSuccess(appId, deviceId, data);
        
        // 计算激活冷却结束时间
        final activateTime = createTime.add(Duration(seconds: duration));
        final now = DateTime.now();
        
        // 计算激活倒计时
        int activationCountdown = activateTime.difference(now).inSeconds;
        
        if (activationCountdown > 0) {
          // 激活倒计时大于0，显示激活倒计时
          _remainingSeconds = activationCountdown;
          _startActivationCountdown();
          
          // 设置当前应用ID并标记为需要倒计时
          setState(() {
            _currentAppId = appId;
            _canActivate = false;  // 需要倒计时结束后才能激活
            _isFindingLongZhu = false;  // 结束寻找龙珠状态
          });
        } else {
          // 激活倒计时小于等于0，显示激活按钮
          setState(() {
            _canActivate = true;
            _currentAppId = appId;
            _isFindingLongZhu = false;  // 结束寻找龙珠状态
          });
          
          // 显示成功消息
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('领到了龙珠，请及时激活')),
            );
          }
        }
      } else {
        // 记录龙珠领取失败
        cloudLog.logLongZhuClaimFailure(appId, deviceId, result['message'] ?? '领取龙珠失败');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '领取龙珠失败')),
          );
        }
      }
    } catch (e) {
      // 记录龙珠领取失败
      final cloudLog = CloudLogService();
      cloudLog.logLongZhuClaimFailure('com.zuime.yuema', 'unknown', e.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络请求失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 激活龙珠
  Future<void> _activateLongZhu() async {
    if (_currentAppId == null) return;

    // 检查是否还在倒计时阶段
    if (!_canActivate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('倒计时结束后才可以激活')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 记录龙珠激活开始
      final cloudLog = CloudLogService();
      cloudLog.logLongZhuActivateStart(_currentAppId!);

      final result = await ApiService.activateLongZhu(appId: _currentAppId!);
      if (result['success'] == true) {
        final data = result['data'];
        setState(() {
          _longZhuCode = data['longZhuCode'];
          _activeTime = data['activeTime'];
          _canActivate = false;
        });
        
        // 记录龙珠激活成功
        cloudLog.logLongZhuActivateSuccess(_currentAppId!, data['longZhuCode'], data['activeTime']);
      } else {
        // 记录龙珠激活失败
        cloudLog.logLongZhuActivateFailure(_currentAppId!, result['message'] ?? '激活龙珠失败');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '激活龙珠失败')),
          );
        }
      }
    } catch (e) {
      // 记录龙珠激活失败
      final cloudLog = CloudLogService();
      cloudLog.logLongZhuActivateFailure(_currentAppId!, e.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络请求失败')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 开始寻找龙珠倒计时（10秒）
  void _startFindingLongZhuCountdown() {
    int findingSeconds = 10;
    
    setState(() {
      _countdownMessage = '倒计时${findingSeconds}秒，正在找龙珠';
    });
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      findingSeconds--;
      if (findingSeconds > 0) {
        setState(() {
          _countdownMessage = '倒计时${findingSeconds}秒，正在找龙珠';
        });
      } else {
        timer.cancel();
        // 倒计时结束后清空倒计时消息
        setState(() {
          _countdownMessage = '';
        });
      }
    });
  }
  
  // 开始激活倒计时
  void _startActivationCountdown() {
    _countdownTimer?.cancel();

    setState(() {
      _canActivate = false;
      _countdownMessage = '您在 $_remainingSeconds 秒后可以激活龙珠';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _canActivate = true;
          _countdownMessage = '现在可以激活龙珠了！';
        });
      } else {
        setState(() {
          _countdownMessage = '您在 $_remainingSeconds 秒后可以激活龙珠';
        });
      }
    });
  }

  // 复制龙珠编码到剪贴板
  Future<void> _copyLongZhuCode() async {
    if (_longZhuCode != null) {
      await Clipboard.setData(ClipboardData(text: _longZhuCode!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('龙珠编码已复制到剪贴板')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('龙珠活动'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 顶部图片
            Image.asset(
              'assets/longzhu_hb.png',
              width: double.infinity,
              height: null, // 高度自适应
              fit: BoxFit.fitWidth, // 宽度填充，高度自适应
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.grey[300],
                  child: const Center(child: Text('顶部图片')),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // 龙珠活动功能区
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 龙珠图标
                    Image.asset(
                      'assets/longzhu.png',
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange[200],
                          ),
                          child: const Icon(
                            Icons.star,
                            size: 60,
                            color: Colors.orange,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 领取按钮
                    if (_currentAppId == null && _longZhuCode == null)
                      ElevatedButton(
                        onPressed: _isLoading ? null : () {
                          // 直接使用当前应用的ID领取龙珠
                          _claimLongZhu('com.zuime.yuema');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('领取龙珠', style: TextStyle(fontSize: 16)),
                      ),
                    
                    // 激活按钮
                    if (_currentAppId != null && _longZhuCode == null)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _activateLongZhu,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,  // 设置文字颜色为白色
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('激活龙珠', style: TextStyle(fontSize: 16)),
                      ),
                    
                    // 倒计时提示
                    if (_countdownMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _countdownMessage,
                          style: const TextStyle(fontSize: 16, color: Colors.blue),
                        ),
                      ),
                    
                    // 寻找龙珠提示
                    if (_isFindingLongZhu && _countdownMessage.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '正在寻找龙珠...',
                          style: TextStyle(fontSize: 16, color: Colors.blue),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // 提示语
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow[50],
                        border: Border.all(color: Colors.yellow[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '龙珠领取后3天内有效，无论是否激活龙珠，有效期为3天。同一个账号同一个应用抓到的龙珠不会变。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 显示龙珠激活结果
                    if (_longZhuCode != null)
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '龙珠激活成功！',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const SizedBox(height: 8),
                              Text('龙珠编码: $_longZhuCode'),
                              if (_activeTime != null) Text('领取时间: ${_formatDateTime(_activeTime!)}'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _copyLongZhuCode,
                                icon: const Icon(Icons.copy),
                                label: const Text('复制编码'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 更多龙珠活动APP列表
            if (_appsList.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '更多龙珠活动APP',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _appsList.length,
                        itemBuilder: (context, index) {
                          final app = _appsList[index];
                          return Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildNetworkImage(
                                      imageUrl: app['appIconUrl'] ?? '',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: const Icon(Icons.apps),
                                    ),
                                  ),
                                  title: Text(app['appName'] ?? ''),
                                  subtitle: Text(app['appDescription'] ?? ''),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          final Uri url = Uri.parse(app['appLink'] ?? '');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('无法打开链接')),
                                            );
                                          }
                                        },
                                        child: const Text('前往领取', style: TextStyle(color: Colors.blue)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.info),
                                        onPressed: () {
                                          // 显示应用详情
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(app['appName'] ?? ''),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // 龙珠图标
                                                  Center(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: _buildNetworkImage(
                                                        imageUrl: app['longzhuLogoUrl'] ?? '',
                                                        width: 60,
                                                        height: 60,
                                                        fit: BoxFit.cover,
                                                        placeholder: const Icon(Icons.star, size: 40),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text('龙珠名称: ${app['longZhuName']}'),
                                                  const SizedBox(height: 8),
                                                  Text('应用描述: ${app['appDescription']}'),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('确定'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            
            // 底部图片
            const SizedBox(height: 20),
            Image.asset(
              'assets/longzhu_rule.png',
              width: double.infinity,
              height: null, // 高度自适应
              fit: BoxFit.fitWidth, // 宽度填充，高度自适应
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 100,
                  color: Colors.grey[300],
                  child: const Center(child: Text('规则图片')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}