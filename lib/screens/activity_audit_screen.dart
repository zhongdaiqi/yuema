import 'package:flutter/material.dart';
import '../models/activity_join.dart';
import '../services/api_service.dart';
import '../services/thumb_url_util.dart';

class ActivityAuditScreen extends StatefulWidget {
  final int noteId;

  const ActivityAuditScreen({Key? key, required this.noteId}) : super(key: key);

  @override
  State<ActivityAuditScreen> createState() => _ActivityAuditScreenState();
}

class _ActivityAuditScreenState extends State<ActivityAuditScreen> {
  List<ActivityJoin> _joins = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // 格式化日期时间
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '';

    try {
      DateTime dateTime;
      // 尝试解析ISO 8601格式
      if (dateTimeStr.contains('T')) {
        dateTime = DateTime.parse(dateTimeStr);
      } else {
        // 尝试解析其他格式，如 "2024-01-01 12:00:00"
        dateTime = DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
      }
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // 如果解析失败，返回原字符串
      return dateTimeStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadJoinList();

    // 添加滚动监听器以实现无限滚动加载
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadJoinList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await ApiService.getActivityJoinList(
        noteId: widget.noteId,
        page: _currentPage,
      );

      if (result['success'] == true) {
        final List<dynamic> joinsData = result['data'];
        final joins = joinsData.map((e) => ActivityJoin.fromJson(e)).toList();

        setState(() {
          if (_currentPage == 1) {
            _joins = joins;
          } else {
            _joins.addAll(joins);
          }
          _hasMore = joins.length == 10; // 假设每页10条数据
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? '获取报名列表失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载报名列表失败: $e';
      });
      print('加载报名列表失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _loadJoinList();
  }

  Future<void> _refreshData() async {
    _currentPage = 1;
    await _loadJoinList();
  }

  // 显示审核对话框
  void _showAuditDialog(ActivityJoin join, bool isPass) {
    final memoController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isPass ? '通过审核' : '拒绝审核'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('确定要${isPass ? '通过' : '拒绝'}用户"${join.nickname}"的报名申请吗？'),
              const SizedBox(height: 16),
              TextField(
                controller: memoController,
                decoration: const InputDecoration(
                  labelText: '审核备注（可选）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performAudit(join, isPass, memoController.text);
              },
              child: Text(isPass ? '通过' : '拒绝'),
            ),
          ],
        );
      },
    );
  }

  // 执行审核操作
  Future<void> _performAudit(
      ActivityJoin join, bool isPass, String memo) async {
    try {
      final result = isPass
          ? await ApiService.passActivity(
              noteId: widget.noteId,
              userId: join.userId,
              memo: memo.isEmpty ? null : memo,
            )
          : await ApiService.rejectActivity(
              noteId: widget.noteId,
              userId: join.userId,
              memo: memo.isEmpty ? null : memo,
            );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isPass ? '通过' : '拒绝'}审核成功')),
        );

        // 刷新数据
        _currentPage = 1;
        await _loadJoinList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${isPass ? '通过' : '拒绝'}审核失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isPass ? '通过' : '拒绝'}审核失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活动报名审核'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading && _currentPage == 1
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage),
                        ElevatedButton(
                          onPressed: _refreshData,
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  )
                : _joins.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无报名信息',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _joins.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _joins.length) {
                            // 加载更多指示器
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final join = _joins[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 用户信息行
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: join.avatar.isNotEmpty
                                            ? NetworkImage(ThumbUrlUtil.avatar100(join.avatar))
                                            : null,
                                        child: join.avatar.isEmpty
                                            ? const Icon(Icons.person, size: 20)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              join.nickname,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '报名时间: ${_formatDateTime(join.createdAt)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 状态标签
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(join.status),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          join.statusText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // 报名详细信息
                                  _buildInfoRow('姓名', join.name),
                                  _buildInfoRow('手机号', join.phone),
                                  if (join.wxId != null &&
                                      join.wxId!.isNotEmpty)
                                    _buildInfoRow('微信', join.wxId!),
                                  if (join.memo != null &&
                                      join.memo!.isNotEmpty)
                                    _buildInfoRow('备注', join.memo!),

                                  const SizedBox(height: 16),

                                  // 操作按钮（仅对未审核的报名显示）
                                  if (join.status == 0)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () =>
                                              _showAuditDialog(join, false),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('拒绝'),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _showAuditDialog(join, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                          child: const Text('通过'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  // 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 获取状态颜色
  Color _getStatusColor(int status) {
    switch (status) {
      case 0: // 未审核
        return Colors.orange;
      case 1: // 审核通过
        return Colors.green;
      case 2: // 审核未通过
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
