import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/cloud_log_service.dart';
import '../services/thumb_url_util.dart';
import 'note_publish_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'service_agreement_screen.dart';
import 'note_detail_screen.dart';
import 'activity_screen.dart';
import 'personal_profile_screen.dart';

// 笔记模型
class Note {
  final int noteId;
  final String noteTitle;
  final String coverImgUrl;
  final int? coverImgWidth;
  final int? coverImgHeight;
  final String noteType;
  final String noteTag;
  final String nickName;
  final String avatarUrl;

  Note({
    required this.noteId,
    required this.noteTitle,
    required this.coverImgUrl,
    this.coverImgWidth,
    this.coverImgHeight,
    required this.noteType,
    required this.noteTag,
    required this.nickName,
    required this.avatarUrl,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      noteId: json['noteId'] ?? 0,
      noteTitle: json['noteTitle'] ?? '',
      coverImgUrl: json['coverImgUrl'] ?? '',
      coverImgWidth: json['coverImgWidth'],
      coverImgHeight: json['coverImgHeight'],
      noteType: json['noteType'] ?? '',
      noteTag: json['noteTag'] ?? '',
      nickName: json['nickName'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
    );
  }

  double get aspectRatio {
    if (coverImgWidth != null &&
        coverImgHeight != null &&
        coverImgHeight! > 0) {
      return coverImgWidth! / coverImgHeight!;
    }
    return 0.75;
  }
}

class AdaptiveImage extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;

  const AdaptiveImage({
    Key? key,
    required this.imageUrl,
    required this.aspectRatio
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 检查URL是否有效
    final bool isValidUrl = imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    if (!isValidUrl) {
      // URL无效，显示占位图
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          color: Colors.grey[300],
          child: const Icon(Icons.image, size: 40, color: Colors.grey),
        ),
      );
    }

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
                  child: const Icon(Icons.image, size: 40, color: Colors.grey),
                );
              },
            );
          }
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.image, size: 40, color: Colors.grey),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  final List<Note> _notes = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _scrollController.addListener(_scrollListener);
    final cloudLog = CloudLogService();
    cloudLog.logPageView('main_screen');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_hasMore && !_isLoading) {
        _loadMoreNotes();
      }
    }
  }

  Future<void> _loadNotes() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getHomeNotes(page: 1, size: 10);

      if (result['success'] == true) {
        final List<dynamic> notesData = result['data'];
        final notes = notesData.map((e) => Note.fromJson(e)).toList();

        setState(() {
          _notes.clear();
          _notes.addAll(notes);
          _page = 1;
          _hasMore = notes.length == 10;
        });
      } else {
        // 如果是认证失败，导航到登录页面
        if (result['message'] == '用户未登录') {
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
      // 错误处理
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotes() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getHomeNotes(page: _page + 1, size: 10);

      if (result['success'] == true) {
        final List<dynamic> notesData = result['data'];
        final notes = notesData.map((e) => Note.fromJson(e)).toList();

        setState(() {
          _notes.addAll(notes);
          _page++;
          _hasMore = notes.length == 10;
        });
      } else {
        // 如果是认证失败，导航到登录页面
        if (result['message'] == '用户未登录') {
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
      // 错误处理
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;

      switch (index) {
        case 0:
          break;
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ActivityScreen(),
            ),
          ).then((_) {
            setState(() {});
          });
          break;
        case 2:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotePublishScreen(),
            ),
          ).then((_) {
            _loadNotes();
          });
          break;
        case 3:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PersonalProfileScreen(),
            ),
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('约吗'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              switch (result) {
                case 'privacy':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                  break;
                case 'service':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ServiceAgreementScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'privacy',
                child: Text('隐私政策'),
              ),
              const PopupMenuItem<String>(
                value: 'service',
                child: Text('用户协议'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('退出'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: '活动',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: '发布',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_notes.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notes.isEmpty) {
      return const Center(
        child: Text('暂无笔记'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // 瀑布流内容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: StaggeredGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 2.0,
                mainAxisSpacing: 2.0,
                children: [
                  for (int i = 0; i < _notes.length; i++) ...[
                    StaggeredGridTile.extent(
                      crossAxisCellCount: 1,
                      mainAxisExtent: _calculateTileHeight(_notes[i], context),
                      child: Card(
                        elevation: 4.0,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NoteDetailScreen(noteId: _notes[i].noteId),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: AdaptiveImage(
                                  imageUrl: _notes[i].coverImgUrl,
                                  aspectRatio: _notes[i].aspectRatio,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _notes[i].noteTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.0,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4.0),
                                    Row(
                                      children: [
                                        _buildAvatar(_notes[i].avatarUrl),
                                        const SizedBox(width: 4.0),
                                        Text(
                                          _notes[i].nickName,
                                          style: const TextStyle(
                                            fontSize: 12.0,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4.0),
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
                                            color: _notes[i].noteType == '活动'
                                                ? Colors.blue
                                                : Colors.green,
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                          ),
                                          child: Text(
                                            _notes[i].noteType,
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
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                          ),
                                          child: Text(
                                            _notes[i].noteTag,
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
                  if (_hasMore) ...[
                    StaggeredGridTile.extent(
                      crossAxisCellCount: 2,
                      mainAxisExtent: 50,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTileHeight(Note note, BuildContext context) {
    double totalSpacing = 2.0 * 2 + 2.0;
    double maxWidth = (MediaQuery.of(context).size.width - totalSpacing) / 2;
    double imageHeight = maxWidth / note.aspectRatio;

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
    )..layout(maxWidth: maxWidth - 8);

    double titleHeight = textPainter.size.height;
    double fixedElementsHeight = titleHeight + 24 + 20 + 8 + 8;

    return imageHeight + fixedElementsHeight;
  }

  // 安全构建头像的辅助方法
  Widget _buildAvatar(String avatarUrl) {
    // 检查URL是否有效
    final bool isValidUrl = avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    if (isValidUrl) {
      return CircleAvatar(
        radius: 10.0,
        backgroundImage: NetworkImage(ThumbUrlUtil.avatar100(avatarUrl)),
        onBackgroundImageError: (exception, stackTrace) {
          // 图片加载失败时的处理（静默失败，不抛出异常）
        },
        backgroundColor: Colors.grey[300],
      );
    } else {
      // URL无效，显示默认头像
      return CircleAvatar(
        radius: 10.0,
        backgroundColor: Colors.grey[300],
        child: const Icon(
          Icons.person,
          size: 16,
          color: Colors.grey,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final session = await SessionService.getInstance();
    await session.clearSession();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }
}