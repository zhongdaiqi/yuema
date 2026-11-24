import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/thumb_url_util.dart';
import 'note_detail_screen.dart';
import 'dart:ui';

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
      coverImgWidth: json['coverImgWidth'] ?? null,
      coverImgHeight: json['coverImgHeight'] ?? null,
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
      // 使用图片的实际宽高比
      return coverImgWidth! / coverImgHeight!;
    }
    // 小红书常用的比例是3:4(0.75)或1:1(1.0)
    // 对于瀑布流布局，我们使用3:4比例效果更好
    return 0.75; // 3:4比例
  }
}

// 自适应高度的图片Widget
class AdaptiveImage extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;

  const AdaptiveImage(
      {Key? key, required this.imageUrl, required this.aspectRatio})
      : super(key: key);

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

    // 瀑布流默认加载缩略图（原图 2~5MB，一屏十几张严重拖慢）；
    // 缩略图加载失败（存量图未补生成）时自动回退原图，保证不裂图。
    final thumbUrl = ThumbUrlUtil.of(imageUrl);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(
        thumbUrl,
        fit: BoxFit.cover, // 使用cover来填充整个区域，类似于小红书的显示风格
        width: double.infinity,
        // 让 Flutter 解码时直接缩到显示尺寸，避免整张原图驻留内存
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

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
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

  Future<void> _loadNotes() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getActivityNotes(page: 1, size: 10);

      if (result['success'] == true) {
        final List<dynamic> notesData = result['data'];
        final notes = notesData.map((e) => Note.fromJson(e)).toList();

        setState(() {
          _notes.clear();
          _notes.addAll(notes);
          _page = 1;
          _hasMore = notes.length == 10; // 如果返回少于10条，说明没有更多了
        });
      } else {
        print('获取活动笔记失败: ${result['message']}');
      }
    } catch (e) {
      print('加载活动笔记失败: $e');
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
      final result =
          await ApiService.getActivityNotes(page: _page + 1, size: 10);

      if (result['success'] == true) {
        final List<dynamic> notesData = result['data'];
        final notes = notesData.map((e) => Note.fromJson(e)).toList();

        setState(() {
          _notes.addAll(notes);
          _page++;
          _hasMore = notes.length == 10; // 如果返回少于10条，说明没有更多了
        });
      } else {
        print('获取更多活动笔记失败: ${result['message']}');
      }
    } catch (e) {
      print('加载更多活动笔记失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活动'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_notes.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notes.isEmpty) {
      return const Center(
        child: Text('暂无活动笔记'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: StaggeredGrid.count(
            crossAxisCount: 2,
            crossAxisSpacing: 2.0,
            mainAxisSpacing: 2.0,
            children: [
              for (int i = 0; i < _notes.length; i++) ...[
                StaggeredGridTile.extent(
                  crossAxisCellCount: 1,
                  mainAxisExtent: _calculateTileHeight(_notes[i]),
                  child: Card(
                    elevation: 4.0,
                    child: InkWell(
                      onTap: () {
                        // 点击笔记进入详情页面
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
                          // 笔记封面 - 使用封装好的AdaptiveImage组件
                          SizedBox(
                            width: double.infinity,
                            child: AdaptiveImage(
                              imageUrl: _notes[i].coverImgUrl,
                              aspectRatio: _notes[i].aspectRatio,
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
                                  _notes[i].noteTitle,
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
      ),
    );
  }

  /// 计算磁贴高度基于图片比例和其他固定元素的高度
  double _calculateTileHeight(Note note) {
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
