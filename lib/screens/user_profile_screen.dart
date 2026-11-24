import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/api_service.dart';
import '../services/thumb_url_util.dart';
import 'note_detail_screen.dart';
import '../services/session_service.dart'; // 添加这一行
import 'dart:ui';

// 用户信息模型
class UserProfile {
  final int userId;
  final String nickname;
  final String avatar;
  final String lastLoginIpRegion;
  final bool isFollowed;
  final String signature; // 添加签名字段

  UserProfile({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.lastLoginIpRegion,
    required this.isFollowed,
    required this.signature, // 添加签名字段
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      lastLoginIpRegion: json['lastLoginIpRegion'] ?? '',
      isFollowed: json['isFollowed'] ?? false,
      signature: json['signature'] ?? '', // 从JSON中获取签名
    );
  }
}

// 笔记模型
class UserNote {
  final int noteId;
  final String noteTitle;
  final String coverImgUrl;
  final String noteType;
  final String noteTag;
  final String nickName;
  final String avatarUrl;

  UserNote({
    required this.noteId,
    required this.noteTitle,
    required this.coverImgUrl,
    required this.noteType,
    required this.noteTag,
    required this.nickName,
    required this.avatarUrl,
  });

  factory UserNote.fromJson(Map<String, dynamic> json) {
    return UserNote(
      noteId: json['noteId'] ?? 0,
      noteTitle: json['noteTitle'] ?? '',
      coverImgUrl: json['coverImgUrl'] ?? '',
      noteType: json['noteType'] ?? '',
      noteTag: json['noteTag'] ?? '',
      nickName: json['nickName'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
    );
  }

  double get aspectRatio {
    // 默认使用3:4比例
    return 0.75;
  }
}

// 自适应高度的图片Widget
class AdaptiveImage extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;

  const AdaptiveImage({
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

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;
  bool _isLoadingNotes = true;
  List<UserNote> _notes = [];
  List<UserNote> _activities = [];
  List<UserNote> _collections = [];
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
    _loadUserNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final result = await ApiService.getUserProfile(userId: widget.userId);

      if (result['success'] == true) {
        setState(() {
          _userProfile = UserProfile.fromJson(result['data']);
        });
      } else {
        print('获取用户信息失败: ${result['message']}');
      }
    } catch (e) {
      print('加载用户信息失败: $e');
    } finally {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadUserNotes() async {
    setState(() {
      _isLoadingNotes = true;
    });

    try {
      // 根据当前选中的tab加载对应的数据
      final tabIndex = _tabController.index;
      final result = await _fetchNotesByTabIndex(tabIndex);

      if (result['success'] == true) {
        final List<dynamic> notesData = result['data'];
        final notes = notesData.map((e) => UserNote.fromJson(e)).toList();

        setState(() {
          switch (tabIndex) {
            case 0: // 笔记
              _notes = notes;
              break;
            case 1: // 活动
              _activities = notes;
              break;
            case 2: // 收藏
              _collections = notes;
              break;
          }
          _hasMore = notes.length == 10;
        });
      } else {
        print('获取用户笔记失败: ${result['message']}');
      }
    } catch (e) {
      print('加载用户笔记失败: $e');
    } finally {
      setState(() {
        _isLoadingNotes = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchNotesByTabIndex(int index) async {
    switch (index) {
      case 0: // 笔记
        return await ApiService.getUserNotes(
          userId: widget.userId,
          page: _currentPage,
          size: 10,
        );
      case 1: // 活动
        return await ApiService.getUserActivityNotes(
          userId: widget.userId,
          page: _currentPage,
          size: 10,
        );
      case 2: // 收藏
        return await ApiService.getUserCollectedNotes(
          userId: widget.userId,
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
    await _loadUserProfile();
    await _loadUserNotes();
  }

  List<UserNote> _getCurrentNotes() {
    switch (_tabController.index) {
      case 0:
        return _notes;
      case 1:
        return _activities;
      case 2:
        return _collections;
      default:
        return _notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户主页'),
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

    if (_userProfile == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('无法加载用户信息'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 用户头像
          CircleAvatar(
            radius: 50.0,
            backgroundImage: NetworkImage(ThumbUrlUtil.avatar100(_userProfile!.avatar)),
            onBackgroundImageError: (exception, stackTrace) {
              // 处理头像加载失败
            },
          ),

          const SizedBox(height: 16.0),

          // 用户昵称
          Text(
            _userProfile!.nickname,
            style: const TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8.0),

          // 用户签名
          if (_userProfile!.signature.isNotEmpty) ...[
            Text(
              _userProfile!.signature,
              style: const TextStyle(
                fontSize: 16.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8.0),
          ],

          // 用户地区信息
          Text(
            _userProfile!.lastLoginIpRegion,
            style: const TextStyle(
              fontSize: 16.0,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 16.0),

          // 关注状态展示（关注操作请在笔记详情页进行）
          if (_userProfile!.isFollowed)
            const Center(
              child: Chip(
                avatar: Icon(Icons.check_circle, size: 16, color: Colors.green),
                label: Text('已关注'),
              ),
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
          Tab(text: '收藏'),
        ],
        onTap: (index) {
          setState(() {
            _currentPage = 1;
          });
          _loadUserNotes();
        },
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
      sliver: SliverToBoxAdapter(
        child: StaggeredGrid.count(
          crossAxisCount: 2,
          crossAxisSpacing: 2.0,
          mainAxisSpacing: 2.0,
          children: [
            for (int i = 0; i < notes.length; i++) ...[
              StaggeredGridTile.extent(
                crossAxisCellCount: 1,
                mainAxisExtent: _calculateTileHeight(notes[i]),
                child: Card(
                  elevation: 4.0,
                  child: InkWell(
                    onTap: () {
                      // 点击笔记进入详情页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NoteDetailScreen(noteId: notes[i].noteId),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 笔记封面
                        SizedBox(
                          width: double.infinity,
                          child: AdaptiveImage(
                            imageUrl: notes[i].coverImgUrl,
                            aspectRatio: notes[i].aspectRatio,
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
                                notes[i].noteTitle,
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
                                    backgroundImage:
                                        NetworkImage(ThumbUrlUtil.avatar100(notes[i].avatarUrl)),
                                    onBackgroundImageError:
                                        (exception, stackTrace) {
                                      // 处理头像加载失败
                                    },
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    notes[i].nickName,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 2.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: notes[i].noteType == '活动'
                                          ? Colors.blue
                                          : Colors.green,
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Text(
                                      notes[i].noteType,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.0,
                                      ),
                                    ),
                                  ),
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
                                      notes[i].noteTag,
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 计算磁贴高度基于图片比例和其他固定元素的高度
  double _calculateTileHeight(UserNote note) {
    // 图片高度基于宽度和纵横比计算
    // 假设每个磁贴的最大宽度约为 (屏幕宽度 - 间距) / 2
    // 屏幕宽度 - 左右边距(各2) - 中间间距(2) = 可用宽度
    double totalSpacing = 2.0 * 2 + 2.0; // 左右边距各2，中间间距2
    double maxWidth = (MediaQuery.of(context).size.width - totalSpacing) / 2;
    double imageHeight = maxWidth / note.aspectRatio;

    // 测量标题文本的实际高度
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: note.noteTitle,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16.0,
        ),
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth - 8); // 减去内边距

    // 固定元素高度估算:
    // 1. 标题实际高度（最多2行）
    double titleHeight = textPainter.size.height;
    // 2. 用户信息行: ~24
    // 3. 类型和标签行: ~20
    // 4. 内边距: 上下各4 = 8
    // 5. 行间距: 4 + 4 = 8
    double fixedElementsHeight = titleHeight + 24 + 20 + 8 + 8;

    // 总高度 = 图片高度 + 固定元素高度
    return imageHeight + fixedElementsHeight;
  }

}
