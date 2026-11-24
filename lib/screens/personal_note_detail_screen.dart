import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:convert';

import '../services/api_service.dart';
import '../services/thumb_url_util.dart';
import '../widgets/image_preview_sheet.dart';
import 'user_profile_screen.dart';
import 'personal_profile_screen.dart';
import 'note_edit_screen.dart';
import 'activity_audit_screen.dart';

// 个人笔记详情模型
class PersonalNoteDetail {
  final int noteId;
  final int? userId; // 用户ID字段设为可选
  final String noteTitle;
  final String noteContent;
  final String coverImgUrl;
  final int? coverImgWidth;
  final int? coverImgHeight;
  final String noteType;
  final String noteTag;
  final String nickName;
  final String avatarUrl;
  final List<String> notePhotos;
  final String? startTime;
  final String? endTime;
  final String? address;
  final bool isLiked; // 喜欢状态
  final bool isCollected; // 收藏状态
  final bool isFollowed; // 关注状态
  final bool isJoined; // 活动报名状态
  final int? joinStatus; // 活动报名审核状态

  // 活动报名统计信息
  final int? totalJoins; // 总报名人数
  final int? pendingJoins; // 等待审核人数
  final int? approvedJoins; // 通过审核人数
  final int? rejectedJoins; // 未通过审核人数

  PersonalNoteDetail({
    required this.noteId,
    this.userId,
    required this.noteTitle,
    required this.noteContent,
    required this.coverImgUrl,
    this.coverImgWidth,
    this.coverImgHeight,
    required this.noteType,
    required this.noteTag,
    required this.nickName,
    required this.avatarUrl,
    required this.notePhotos,
    this.startTime,
    this.endTime,
    this.address,
    this.isLiked = false, // 默认为false
    this.isCollected = false, // 默认为false
    this.isFollowed = false, // 默认为false
    this.isJoined = false, // 默认为false
    this.joinStatus, // 默认为null
    this.totalJoins, // 默认为null
    this.pendingJoins, // 默认为null
    this.approvedJoins, // 默认为null
    this.rejectedJoins, // 默认为null
  });

  factory PersonalNoteDetail.fromJson(Map<String, dynamic> json) {
    List<String> photos = [];
    if (json['notePhotos'] != null) {
      try {
        // 尝试解析为标准JSON数组
        if (json['notePhotos'] is String) {
          String photosString = json['notePhotos'];
          print('原始notePhotos字符串: $photosString'); // 调试信息

          // 检查是否是标准的JSON数组格式
          if (photosString.trim().startsWith('[') &&
              photosString.trim().endsWith(']')) {
            try {
              // 尝试标准JSON解析
              photos = List<String>.from(jsonDecode(photosString));
            } catch (jsonError) {
              print('标准JSON解析失败: $jsonError');
              // 如果标准JSON解析失败，尝试手动解析
              photos = _parsePhotoUrls(photosString);
            }
          } else {
            // 非数组格式的单个URL或其他格式
            photos = _parsePhotoUrls(photosString);
          }
        } else if (json['notePhotos'] is List) {
          // 已经是列表格式
          photos = List<String>.from(json['notePhotos']);
        }
      } catch (e) {
        print('解析notePhotos出错: $e');
        // 出错时使用默认空列表
        photos = [];
      }
    }

    return PersonalNoteDetail(
      noteId: json['noteId'] ?? 0,
      userId: json['userId'],
      noteTitle: json['noteTitle'] ?? '',
      noteContent: json['noteContent'] ?? '',
      coverImgUrl: json['coverImgUrl'] ?? '',
      coverImgWidth: json['coverImgWidth'],
      coverImgHeight: json['coverImgHeight'],
      noteType: json['noteType'] ?? '',
      noteTag: json['noteTag'] ?? '',
      nickName: json['nickName'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      notePhotos: photos,
      startTime: json['startTime'],
      endTime: json['endTime'],
      address: json['address'],
      isLiked: json['isLiked'] ?? false, // 从JSON获取喜欢状态
      isCollected: json['isCollected'] ?? false, // 从JSON获取收藏状态
      isFollowed: json['isFollowed'] ?? false, // 从JSON获取关注状态
      isJoined: json['isJoined'] ?? false, // 从JSON获取活动报名状态
      joinStatus: json['joinStatus'], // 从JSON获取活动报名审核状态
      totalJoins: json['totalJoins'], // 从JSON获取总报名人数
      pendingJoins: json['pendingJoins'], // 从JSON获取等待审核人数
      approvedJoins: json['approvedJoins'], // 从JSON获取通过审核人数
      rejectedJoins: json['rejectedJoins'], // 从JSON获取未通过审核人数
    );
  }

  // 手动解析照片URL的辅助方法
  static List<String> _parsePhotoUrls(String input) {
    print('手动解析照片URL: $input');

    // 移除首尾的方括号和空格
    String cleanInput = input.trim();
    if (cleanInput.startsWith('[') && cleanInput.endsWith(']')) {
      cleanInput = cleanInput.substring(1, cleanInput.length - 1).trim();
    }

    // 如果为空，返回空列表
    if (cleanInput.isEmpty) {
      return [];
    }

    List<String> urls = [];

    // 尝试按逗号分割
    List<String> parts = cleanInput.split(',');

    for (String part in parts) {
      String trimmedPart = part.trim();

      // 移除可能的引号
      if (trimmedPart.startsWith('"') &&
          trimmedPart.endsWith('"') &&
          trimmedPart.length > 1) {
        trimmedPart = trimmedPart.substring(1, trimmedPart.length - 1);
      } else if (trimmedPart.startsWith("'") &&
          trimmedPart.endsWith("'") &&
          trimmedPart.length > 1) {
        trimmedPart = trimmedPart.substring(1, trimmedPart.length - 1);
      }

      // 检查是否是有效的URL格式
      if (trimmedPart.isNotEmpty &&
          (trimmedPart.startsWith('http://') ||
              trimmedPart.startsWith('https://'))) {
        urls.add(trimmedPart);
      }
    }

    print('解析得到的URL列表: $urls');
    return urls;
  }

  double get aspectRatio {
    if (coverImgWidth != null &&
        coverImgHeight != null &&
        coverImgHeight! > 0) {
      return coverImgWidth! / coverImgHeight!;
    }
    return 0.75; // 默认3:4比例
  }
}

class PersonalNoteDetailScreen extends StatefulWidget {
  final int noteId;

  const PersonalNoteDetailScreen({Key? key, required this.noteId})
      : super(key: key);

  @override
  State<PersonalNoteDetailScreen> createState() =>
      _PersonalNoteDetailScreenState();
}

class _PersonalNoteDetailScreenState extends State<PersonalNoteDetailScreen> {
  PersonalNoteDetail? _noteDetail;
  bool _isLoading = true;
  bool _isCommentsLoading = true;
  String _errorMessage = '';
  bool _isLiked = false;
  bool _isCollected = false;
  bool _isFollowing = false;
  bool _isJoined = false; // 活动报名状态

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
    _loadNoteDetail();
  }

  // 加载笔记详情
  Future<void> _loadNoteDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 使用新的API方法获取包含活动统计信息的笔记详情
      final result =
          await ApiService.getNoteDetailWithStats(noteId: widget.noteId);

      if (result['success'] == true) {
        setState(() {
          _noteDetail = PersonalNoteDetail.fromJson(result['data']);
          // 初始化状态
          _isLiked = _noteDetail!.isLiked;
          _isCollected = _noteDetail!.isCollected;
          _isFollowing = _noteDetail!.isFollowed;
          // 初始化活动报名状态
          _isJoined = _noteDetail!.isJoined;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? '获取笔记详情失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载笔记详情失败: $e';
      });
      print('加载笔记详情失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 设置全局上下文以处理401错误
    ApiService.setGlobalContext(context);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage),
                        ElevatedButton(
                          onPressed: _loadNoteDetail,
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  )
                : _noteDetail == null
                    ? const Center(child: Text('未找到笔记详情'))
                    : _buildNoteDetailContent(),
      ),
    );
  }

  Widget _buildNoteDetailContent() {
    return CustomScrollView(
      slivers: [
        // 顶部用户信息行（返回图标、用户头像、昵称、关注按钮在一行）
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverAppBarDelegate(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 返回图标
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8.0),

                  // 用户头像
                  GestureDetector(
                    onTap: () {
                      // 点击头像进入个人主页
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PersonalProfileScreen(),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 20.0,
                      backgroundImage: _noteDetail!.avatarUrl.isNotEmpty
                          ? NetworkImage(ThumbUrlUtil.avatar100(_noteDetail!.avatarUrl))
                          : null,
                      backgroundColor: Colors.grey[200],
                      child: _noteDetail!.avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 20)
                          : null,
                      onBackgroundImageError: (exception, stackTrace) {
                        // 处理头像加载失败
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // 用户昵称
                  GestureDetector(
                    onTap: () {
                      // 点击昵称进入个人主页
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PersonalProfileScreen(),
                        ),
                      );
                    },
                    child: Text(
                      _noteDetail!.nickName.isNotEmpty
                          ? _noteDetail!.nickName
                          : '未知用户',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  ),

                  // 关注按钮放在最右侧
                  const Spacer(),
                  ElevatedButton(
                    onPressed:
                        _noteDetail!.isFollowed ? _unfollowUser : _followUser,
                    child: Text(_noteDetail!.isFollowed ? '已关注' : '关注'),
                  ),

                  // 个人笔记特有的管理功能：删除和编辑按钮
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      // 删除笔记功能
                      _showDeleteConfirmationDialog();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      // 编辑笔记功能
                      _editNote();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 主要内容
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片轮播（显示笔记图集）
              CarouselSlider(
                items: _noteDetail!.notePhotos.asMap().entries.map((entry) {
                  int index = entry.key;
                  String photoUrl = entry.value;

                  return Builder(
                    builder: (BuildContext context) {
                      return GestureDetector(
                        onTap: () {
                          // 点击图片进入预览模式
                          _previewImage(index);
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(horizontal: 5.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                          ),
                          // 详情页默认加载缩略图，失败回退原图
                          child: _buildThumbImage(photoUrl),
                        ),
                      );
                    },
                  );
                }).toList(),
                options: CarouselOptions(
                  height: 300.0,
                  enlargeCenterPage: true,
                  autoPlay: false,
                  aspectRatio: 16 / 9,
                  onPageChanged: (index, reason) {
                    // 页面改变回调
                  },
                ),
              ),

              // 笔记内容
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      _noteDetail!.noteTitle,
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // 内容
                    Text(
                      _noteDetail!.noteContent,
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // 标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        _noteDetail!.noteTag,
                        style: const TextStyle(
                          fontSize: 12.0,
                        ),
                      ),
                    ),

                    // 活动报名统计信息（放在标签下方）
                    if (_noteDetail!.noteType == '活动') ...[
                      const SizedBox(height: 8.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (_noteDetail!.totalJoins != null)
                            Column(
                              children: [
                                Text(
                                  '${_noteDetail!.totalJoins}',
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '总',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          if (_noteDetail!.approvedJoins != null)
                            Column(
                              children: [
                                Text(
                                  '${_noteDetail!.approvedJoins}',
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '通过',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          if (_noteDetail!.pendingJoins != null)
                            Column(
                              children: [
                                Text(
                                  '${_noteDetail!.pendingJoins}',
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '待审',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          if (_noteDetail!.rejectedJoins != null)
                            Column(
                              children: [
                                Text(
                                  '${_noteDetail!.rejectedJoins}',
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '拒绝',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      // 添加进入审核按钮（放在活动统计信息下方）
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            // 进入审核页面
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ActivityAuditScreen(
                                  noteId: _noteDetail!.noteId,
                                ),
                              ),
                            );
                          },
                          child: const Text('进入审核'),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // 活动相关信息（如果是活动类型）
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '活动信息',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            if (_noteDetail!.startTime != null)
                              _buildInfoRow('开始时间',
                                  _formatDateTime(_noteDetail!.startTime)),
                            if (_noteDetail!.endTime != null)
                              _buildInfoRow('结束时间',
                                  _formatDateTime(_noteDetail!.endTime)),
                            if (_noteDetail!.address != null)
                              _buildInfoRow('活动地点', _noteDetail!.address!),
                            const SizedBox(height: 16.0),
                            Center(
                              child: ElevatedButton(
                                onPressed: _isJoined
                                    ? null // 如果已报名，则禁用按钮
                                    : _showJoinActivityDialog, // 否则显示报名对话框
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _getJoinButtonColor(), // 设置按钮背景色
                                  foregroundColor:
                                      _getJoinButtonTextColor(), // 设置按钮文字颜色
                                ),
                                child: Text(_getJoinButtonText()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // 获取报名按钮文本
  String _getJoinButtonText() {
    // 确保joinStatus是非空的，并且处理可能的类型转换问题
    if (_noteDetail?.joinStatus != null) {
      final status = _noteDetail!.joinStatus!;

      // 处理不同类型的比较（数字或字符串）
      if (status == 1 || status == "1") {
        return '待审核'; // WAITING
      } else if (status == 2 || status == "2") {
        return '已通过'; // APPROVED
      } else if (status == 3 || status == "3") {
        return '已拒绝'; // REJECTED
      }
    }

    // 如果用户已经报名但状态未知，显示"已报名"
    if (_isJoined) {
      return '已报名';
    }

    return '我要报名';
  }

  // 获取报名按钮颜色
  Color _getJoinButtonColor() {
    // 确保joinStatus是非空的，并且处理可能的类型转换问题
    if (_noteDetail?.joinStatus != null) {
      final status = _noteDetail!.joinStatus!;

      // 处理不同类型的比较（数字或字符串）
      if (status == 2 || status == "2") {
        return Colors.green; // 通过的状态使用绿色
      } else if (status == 1 || status == "1") {
        return Colors.orange; // 待审核使用橙色
      } else if (status == 3 || status == "3") {
        return Colors.red; // 拒绝使用红色
      }
    }

    // 默认颜色（我要报名/已报名）
    return Theme.of(context).colorScheme.primary;
  }

  // 获取报名按钮文字颜色
  Color _getJoinButtonTextColor() {
    // 对于大多数背景色，使用白色文字以确保良好的对比度
    return Colors.white;
  }

  // 关注用户
  Future<void> _followUser() async {
    if (_noteDetail == null) return;

    try {
      final result = await ApiService.followUser(
        noteId: _noteDetail!.noteId,
        followUserId: _noteDetail!.userId!,
      );

      if (result['success'] == true) {
        setState(() {
          _isFollowing = true;
          _noteDetail = PersonalNoteDetail(
            noteId: _noteDetail!.noteId,
            userId: _noteDetail!.userId,
            noteTitle: _noteDetail!.noteTitle,
            noteContent: _noteDetail!.noteContent,
            coverImgUrl: _noteDetail!.coverImgUrl,
            coverImgWidth: _noteDetail!.coverImgWidth,
            coverImgHeight: _noteDetail!.coverImgHeight,
            noteType: _noteDetail!.noteType,
            noteTag: _noteDetail!.noteTag,
            nickName: _noteDetail!.nickName,
            avatarUrl: _noteDetail!.avatarUrl,
            notePhotos: _noteDetail!.notePhotos,
            startTime: _noteDetail!.startTime,
            endTime: _noteDetail!.endTime,
            address: _noteDetail!.address,
            isLiked: _noteDetail!.isLiked,
            isCollected: _noteDetail!.isCollected,
            isFollowed: true, // 更新关注状态
            isJoined: _noteDetail!.isJoined,
            joinStatus: _noteDetail!.joinStatus,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('关注成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('关注失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('关注失败: $e')),
      );
    }
  }

  // 取消关注用户
  Future<void> _unfollowUser() async {
    if (_noteDetail == null) return;

    try {
      final result = await ApiService.unfollowUser(
        followUserId: _noteDetail!.userId!,
      );

      if (result['success'] == true) {
        setState(() {
          _isFollowing = false;
          _noteDetail = PersonalNoteDetail(
            noteId: _noteDetail!.noteId,
            userId: _noteDetail!.userId,
            noteTitle: _noteDetail!.noteTitle,
            noteContent: _noteDetail!.noteContent,
            coverImgUrl: _noteDetail!.coverImgUrl,
            coverImgWidth: _noteDetail!.coverImgWidth,
            coverImgHeight: _noteDetail!.coverImgHeight,
            noteType: _noteDetail!.noteType,
            noteTag: _noteDetail!.noteTag,
            nickName: _noteDetail!.nickName,
            avatarUrl: _noteDetail!.avatarUrl,
            notePhotos: _noteDetail!.notePhotos,
            startTime: _noteDetail!.startTime,
            endTime: _noteDetail!.endTime,
            address: _noteDetail!.address,
            isLiked: _noteDetail!.isLiked,
            isCollected: _noteDetail!.isCollected,
            isFollowed: false, // 更新关注状态
            isJoined: _noteDetail!.isJoined,
            joinStatus: _noteDetail!.joinStatus,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取消关注成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消关注失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取消关注失败: $e')),
      );
    }
  }

  // 点赞笔记
  Future<void> _likeNote() async {
    if (_noteDetail == null) return;

    try {
      final result = await ApiService.likeNote(noteId: _noteDetail!.noteId);

      if (result['success'] == true) {
        setState(() {
          _isLiked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('点赞成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('点赞失败: $e')),
      );
    }
  }

  // 取消点赞笔记
  Future<void> _unlikeNote() async {
    if (_noteDetail == null) return;

    try {
      final result = await ApiService.unlikeNote(noteId: _noteDetail!.noteId);

      if (result['success'] == true) {
        setState(() {
          _isLiked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取消点赞成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消点赞失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取消点赞失败: $e')),
      );
    }
  }

  // 收藏笔记
  Future<void> _collectNote() async {
    if (_noteDetail == null) return;

    try {
      final result = await ApiService.collectNote(noteId: _noteDetail!.noteId);

      if (result['success'] == true) {
        setState(() {
          _isCollected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('收藏失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏失败: $e')),
      );
    }
  }

  // 取消收藏笔记
  Future<void> _uncollectNote() async {
    if (_noteDetail == null) return;

    try {
      final result =
          await ApiService.uncollectNote(noteId: _noteDetail!.noteId);

      if (result['success'] == true) {
        setState(() {
          _isCollected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取消收藏成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消收藏失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取消收藏失败: $e')),
      );
    }
  }

  // 显示活动报名对话框
  void _showJoinActivityDialog() {
    if (_noteDetail == null) return;

    // 创建控制器用于表单输入
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final wxIdController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('活动报名'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名*',
                    hintText: '请输入您的姓名',
                  ),
                  autofocus: true,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: '手机号*',
                    hintText: '请输入您的手机号',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: wxIdController,
                  decoration: const InputDecoration(
                    labelText: '微信号',
                    hintText: '请输入您的微信号（可选）',
                  ),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: '地址',
                    hintText: '请输入您的地址（可选）',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 取消按钮
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // 验证必填字段
                if (nameController.text.isEmpty ||
                    phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写姓名和手机号')),
                  );
                  return;
                }

                // 提交报名信息
                _joinActivity(
                  name: nameController.text,
                  phone: phoneController.text,
                  wxId:
                      wxIdController.text.isEmpty ? null : wxIdController.text,
                  address: addressController.text.isEmpty
                      ? null
                      : addressController.text,
                );

                // 关闭对话框
                Navigator.of(context).pop();
              },
              child: const Text('提交'),
            ),
          ],
        );
      },
    );
  }

  // 加入活动
  Future<void> _joinActivity({
    required String name,
    required String phone,
    String? wxId,
    String? address,
  }) async {
    if (_noteDetail == null) return;

    try {
      final result = await ApiService.joinActivity(
        noteId: _noteDetail!.noteId,
        name: name,
        phone: phone,
        wxId: wxId,
        address: address,
      );

      if (result['success'] == true) {
        setState(() {
          _isJoined = true; // 更新报名状态
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('活动报名成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('报名失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('报名失败: $e')),
      );
    }
  }

  // 显示删除确认对话框
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这篇笔记吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 取消
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 关闭对话框
                _deleteNote(); // 删除笔记
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 删除笔记
  Future<void> _deleteNote() async {
    if (_noteDetail == null) return;

    try {
      final result = await ApiService.deleteNote(noteId: widget.noteId);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功')),
        );

        // 返回上一页
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  // 编辑笔记
  Future<void> _editNote() async {
    if (_noteDetail == null) return;

    // 跳转到笔记编辑页面
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditScreen(noteDetail: _noteDetail!),
      ),
    );

    // 如果编辑成功，刷新笔记详情
    if (result == true) {
      _loadNoteDetail();
    }
  }

  /// 详情轮播图：默认缩略图，失败回退原图
  Widget _buildThumbImage(String originalUrl) {
    final thumbUrl = ThumbUrlUtil.of(originalUrl);
    return Image.network(
      thumbUrl,
      fit: BoxFit.contain,
      cacheWidth: 640,
      errorBuilder: (context, error, stackTrace) {
        if (thumbUrl != originalUrl) {
          return Image.network(
            originalUrl,
            fit: BoxFit.contain,
            cacheWidth: 640,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error);
            },
          );
        }
        return const Icon(Icons.error);
      },
    );
  }

  // 图片预览：默认缩略图，用户点「查看原图」才加载原图
  void _previewImage(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: ImagePreviewSheet(
            imageUrls: _noteDetail!.notePhotos,
            initialIndex: index,
          ),
        );
      },
    );
  }
}

// 自定义SliverAppBar Delegate
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 60.0; // 根据规范设置为60.0

  @override
  double get minExtent => 60.0; // 根据规范设置为60.0

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}
