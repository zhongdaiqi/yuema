import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/cloud_log_service.dart'; // 添加云日志服务导入
import '../services/thumb_url_util.dart';
import 'note_detail_screen.dart';
import 'personal_note_detail_screen.dart'; // 导入个人笔记详情页面
import 'login_screen.dart'; // 导入登录页面
import 'avatar_edit_screen.dart'; // 导入头像编辑页面

// 个人主页信息模型
class PersonalProfile {
  int userId;
  String nickname;
  String avatar;
  String signature;
  String lastLoginIpRegion;

  PersonalProfile({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.signature,
    required this.lastLoginIpRegion,
  });

  factory PersonalProfile.fromJson(Map<String, dynamic> json) {
    return PersonalProfile(
      userId: json['userId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      signature: json['signature'] ?? '',
      lastLoginIpRegion: json['lastLoginIpRegion'] ?? '',
    );
  }
}

// 笔记模型
class PersonalNote {
  final int noteId;
  final String noteTitle;
  final String coverImgUrl;
  final String noteType;
  final String noteTag;
  final String nickName;
  final String avatarUrl;
  final int? joinStatus; // 参与状态，仅在参与活动中使用
  final int? coverImgWidth; // 图片宽度
  final int? coverImgHeight; // 图片高度

  PersonalNote({
    required this.noteId,
    required this.noteTitle,
    required this.coverImgUrl,
    required this.noteType,
    required this.noteTag,
    required this.nickName,
    required this.avatarUrl,
    this.joinStatus,
    this.coverImgWidth,
    this.coverImgHeight,
  });

  factory PersonalNote.fromJson(Map<String, dynamic> json) {
    return PersonalNote(
      noteId: json['noteId'] ?? 0,
      noteTitle: json['noteTitle'] ?? '',
      coverImgUrl: json['coverImgUrl'] ?? '',
      noteType: json['noteType'] ?? '',
      noteTag: json['noteTag'] ?? '',
      nickName: json['nickName'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      joinStatus: json['joinStatus'], // 可能为null
      coverImgWidth: json['coverImgWidth'] ?? null,
      coverImgHeight: json['coverImgHeight'] ?? null,
    );
  }

  double get aspectRatio {
    if (coverImgWidth != null &&
        coverImgHeight != null &&
        coverImgHeight! > 0) {
      // 使用图片的实际宽高比
      return coverImgWidth! / coverImgHeight!;
    }
    // 默认使用3:4比例
    return 0.75;
  }
}

// 自适应高度的图片Widget
class PersonalAdaptiveImage extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;

  const PersonalAdaptiveImage({
    Key? key,
    required this.imageUrl,
    required this.aspectRatio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 瀑布流默认加载缩略图，失败回退原图（存量图未补生成时保底）
    final thumbUrl = ThumbUrlUtil.of(imageUrl);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(
        thumbUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        cacheWidth: 640,
        errorBuilder: (context, error, stackTrace) {
          if (thumbUrl != imageUrl) {
            return Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              cacheWidth: 640,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                );
              },
            );
          }
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      ),
    );
  }
}

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({Key? key}) : super(key: key);

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PersonalProfile? _personalProfile;
  bool _isLoadingProfile = true;
  bool _isLoadingNotes = true;
  List<PersonalNote> _notes = []; // 发布的笔记
  List<PersonalNote> _activities = []; // 发布的活动
  List<PersonalNote> _joinedActivities = []; // 参与的活动
  List<PersonalNote> _collections = []; // 收藏的笔记
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPersonalProfile();
    _loadNotes();

    // 记录页面访问日志
    final cloudLog = CloudLogService();
    cloudLog.logPageView('personal_profile_screen');

    // 监听Tab变化
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentPage = 1;
        });
        _loadNotes();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final result = await ApiService.getPersonalInfo();

      if (result['success'] == true) {
        setState(() {
          _personalProfile = PersonalProfile.fromJson(result['data']);
        });
      } else {
        print('获取个人主页信息失败: ${result['message']}');
        if (result['message'] == '用户未登录') {
          // 处理未登录情况
          final session = await SessionService.getInstance();
          await session.clearSession();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      print('加载个人主页信息失败: $e');
    } finally {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoadingNotes = true;
    });

    try {
      // 根据当前选中的tab加载对应的数据
      final tabIndex = _tabController.index;
      final result = await _fetchNotesByTabIndex(tabIndex);

      if (result['success'] == true) {
        List<dynamic> notesData = [];

        // 检查返回的数据结构
        if (result['data'] is Map<String, dynamic>) {
          // 对于收藏接口，数据在data.list中
          final dataMap = result['data'] as Map<String, dynamic>;
          notesData = dataMap['list'] as List<dynamic>? ?? [];
        } else if (result['data'] is List) {
          // 其他接口直接返回数组
          notesData = result['data'] as List<dynamic>;
        }

        final notes = notesData.map((e) {
          // 如果是收藏接口的数据结构，需要转换
          if (e is Map<String, dynamic> && e.containsKey('author')) {
            // 收藏接口的数据结构转换
            final author = e['author'] as Map<String, dynamic>? ?? {};
            return PersonalNote(
              noteId: e['noteId'] ?? 0,
              noteTitle: e['noteTitle'] ?? '',
              coverImgUrl: e['coverImgUrl'] ?? '',
              noteType: e['noteType'] ?? '',
              noteTag: e['noteTag'] ?? '',
              nickName: author['nickname'] ?? '',
              avatarUrl: author['avatar'] ?? '',
              coverImgWidth: e['coverImgWidth'],
              coverImgHeight: e['coverImgHeight'],
            );
          } else {
            // 其他接口的数据结构
            return PersonalNote.fromJson(e as Map<String, dynamic>);
          }
        }).toList();

        setState(() {
          switch (tabIndex) {
            case 0: // 笔记
              if (_currentPage == 1) {
                _notes = notes;
              } else {
                _notes.addAll(notes);
              }
              break;
            case 1: // 活动
              if (_currentPage == 1) {
                _activities = notes;
              } else {
                _activities.addAll(notes);
              }
              break;
            case 2: // 参与
              if (_currentPage == 1) {
                _joinedActivities = notes;
              } else {
                _joinedActivities.addAll(notes);
              }
              break;
            case 3: // 收藏
              if (_currentPage == 1) {
                _collections = notes;
              } else {
                _collections.addAll(notes);
              }
              break;
          }
          _hasMore = notes.length == 10;
        });
      } else {
        print('获取笔记失败: ${result['message']}');
        if (result['message'] == '用户未登录') {
          // 处理未登录情况
          final session = await SessionService.getInstance();
          await session.clearSession();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      print('加载笔记失败: $e');
    } finally {
      setState(() {
        _isLoadingNotes = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchNotesByTabIndex(int index) async {
    switch (index) {
      case 0: // 笔记
        return await ApiService.getPersonalNotes(
          page: _currentPage,
          size: 10,
        );
      case 1: // 活动
        return await ApiService.getPersonalActivityNotes(
          page: _currentPage,
          size: 10,
        );
      case 2: // 参与
        return await ApiService.getPersonalJoinedActivities(
          page: _currentPage,
          size: 10,
        );
      case 3: // 收藏
        return await ApiService.getPersonalCollectedNotes(
          page: _currentPage,
          size: 10,
        );
      default:
        return {
          'success': false,
          'message': '未知的tab索引',
        };
    }
  }

  Future<void> _refreshData() async {
    _currentPage = 1;
    await _loadPersonalProfile();
    await _loadNotes();
  }

  List<PersonalNote> _getCurrentNotes() {
    switch (_tabController.index) {
      case 0:
        return _notes;
      case 1:
        return _activities;
      case 2:
        return _joinedActivities;
      case 3:
        return _collections;
      default:
        return _notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人主页'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 用户信息部分
            SliverToBoxAdapter(
              child: _buildUserInfoSection(),
            ),

            // Tab导航部分
            SliverToBoxAdapter(
              child: _buildTabSection(),
            ),

            // 笔记瀑布流部分
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    if (_isLoadingProfile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_personalProfile == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('无法加载个人主页信息'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 用户头像
          GestureDetector(
            onTap: () {
              // 进入头像编辑页面
              _editAvatar();
            },
            child: CircleAvatar(
              radius: 50.0,
              backgroundImage: _personalProfile!.avatar.isNotEmpty
                  ? NetworkImage(_personalProfile!.avatar)
                  : null,
              backgroundColor: Colors.grey[200],
              child: _personalProfile!.avatar.isEmpty
                  ? const Icon(Icons.person, size: 50)
                  : null,
              onBackgroundImageError: (exception, stackTrace) {
                // 处理头像加载失败
              },
            ),
          ),

          const SizedBox(height: 16.0),

          // 用户昵称
          Text(
            _personalProfile!.nickname.isNotEmpty
                ? _personalProfile!.nickname
                : '未知用户',
            style: const TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8.0),

          // 用户签名
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _personalProfile!.signature.isNotEmpty
                    ? _personalProfile!.signature
                    : '暂无签名',
                style: const TextStyle(
                  fontSize: 16.0,
                  color: Colors.grey,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () {
                  // 修改签名功能
                  _showEditSignatureDialog();
                },
              ),
            ],
          ),

          const SizedBox(height: 8.0),

          // 用户地区信息
          Text(
            _personalProfile!.lastLoginIpRegion.isNotEmpty
                ? _personalProfile!.lastLoginIpRegion
                : '未知地区',
            style: const TextStyle(
              fontSize: 14.0,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 16.0),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  // 修改头像功能 - 进入头像编辑页面
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AvatarEditScreen(
                        currentAvatarUrl: _personalProfile!.avatar,
                      ),
                    ),
                  ).then((newAvatarUrl) {
                    if (newAvatarUrl != null) {
                      setState(() {
                        _personalProfile!.avatar = newAvatarUrl;
                      });
                    }
                  });
                },
                child: const Text('修改头像'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: '笔记'),
          Tab(text: '活动'),
          Tab(text: '参与'),
          Tab(text: '收藏'),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    final notes = _getCurrentNotes();

    if (_isLoadingNotes && _currentPage == 1) {
      return SliverToBoxAdapter(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (notes.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const Text(
            '暂无内容',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
        itemBuilder: (context, index) {
          final note = notes[index];
          return Card(
            elevation: 4.0,
            child: InkWell(
              onTap: () {
                // 点击笔记进入详情页面
                // 根据当前tab决定使用哪个详情页面
                if (_tabController.index == 0 || _tabController.index == 1) {
                  // 个人笔记（发布和活动）使用个人笔记详情页
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PersonalNoteDetailScreen(noteId: note.noteId),
                    ),
                  ).then((_) {
                    // 从详情页返回时刷新数据
                    _refreshData();
                  });
                } else {
                  // 参与和收藏的笔记使用普通笔记详情页
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NoteDetailScreen(noteId: note.noteId),
                    ),
                  ).then((_) {
                    // 从详情页返回时刷新数据
                    _refreshData();
                  });
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 笔记封面 - 使用封装好的AdaptiveImage组件
                  SizedBox(
                    width: double.infinity,
                    child: PersonalAdaptiveImage(
                      imageUrl: note.coverImgUrl,
                      aspectRatio: note.aspectRatio,
                    ),
                  ),
                  // 笔记信息
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题
                        Text(
                          note.noteTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4.0),
                        // 用户信息
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10.0,
                              backgroundImage: note.avatarUrl.isNotEmpty
                                  ? NetworkImage(note.avatarUrl)
                                  : null,
                              backgroundColor: Colors.grey[200],
                              child: note.avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 12)
                                  : null,
                              onBackgroundImageError: (exception, stackTrace) {
                                // 处理头像加载失败
                              },
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              note.nickName,
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        // 类型和标签
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: note.noteType == '活动'
                                    ? Colors.blue
                                    : Colors.green,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                note.noteType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.0,
                                ),
                              ),
                            ),
                            if (note.joinStatus != null)
                              _buildJoinStatusChip(note.joinStatus!),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                note.noteTag,
                                style: const TextStyle(
                                  fontSize: 10.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: notes.length,
      ),
    );
  }

  Widget _buildJoinStatusChip(int joinStatus) {
    String text;
    Color color;

    switch (joinStatus) {
      case 0:
        text = '待审核';
        color = Colors.orange;
        break;
      case 1:
        text = '已通过';
        color = Colors.green;
        break;
      case 2:
        text = '已拒绝';
        color = Colors.red;
        break;
      default:
        text = '未知';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6.0,
        vertical: 2.0,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.0,
        ),
      ),
    );
  }

  // 修改签名对话框
  Future<void> _showEditSignatureDialog() async {
    final _signatureController =
        TextEditingController(text: _personalProfile?.signature ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('修改签名'),
          content: TextField(
            controller: _signatureController,
            decoration: const InputDecoration(
              hintText: '请输入新的签名',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('保存'),
              onPressed: () async {
                final newSignature = _signatureController.text.trim();

                try {
                  final result = await ApiService.updateSignature(
                    signature: newSignature,
                  );

                  if (result['success'] == true) {
                    setState(() {
                      _personalProfile!.signature = newSignature;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('签名修改成功')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('签名修改失败: ${result['message']}')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('签名修改失败: $e')),
                  );
                }

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 编辑用户头像
  Future<void> _editAvatar() async {
    // 导航到头像编辑页面
    final newAvatarUrl = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarEditScreen(
          currentAvatarUrl: _personalProfile?.avatar ?? '',
        ),
      ),
    );

    // 如果返回了新的头像URL，则更新界面
    if (newAvatarUrl != null && mounted) {
      setState(() {
        if (_personalProfile != null) {
          _personalProfile!.avatar = newAvatarUrl;
        }
      });
    }
  }
}
