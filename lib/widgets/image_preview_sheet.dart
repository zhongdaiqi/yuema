import 'package:flutter/material.dart';
import '../services/thumb_url_util.dart';

/// 大图预览组件（2026-11-23）
///
/// 交互：默认展示缩略图（省流量、秒开），用户明确点「查看原图」后才加载原图。
/// 缩略图加载失败（存量图未补生成）时自动回退原图，保证不裂图。
/// 支持 InteractiveViewer 缩放/拖动。
class ImagePreviewSheet extends StatefulWidget {
  /// 原图 URL 列表
  final List<String> imageUrls;
  /// 初始索引
  final int initialIndex;

  const ImagePreviewSheet({
    Key? key,
    required this.imageUrls,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<ImagePreviewSheet> {
  late int _index;
  /// 是否为用户主动切换到原图（默认 false = 缩略图）
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _next() {
    if (_index < widget.imageUrls.length - 1) {
      setState(() {
        _index++;
        _showOriginal = false; // 换图后回到缩略图
      });
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() {
        _index--;
        _showOriginal = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final originalUrl = widget.imageUrls[_index];
    final thumbUrl = _showOriginal ? originalUrl : ThumbUrlUtil.of(originalUrl);

    return Material(
      color: Colors.black,
      child: Column(
        children: [
          // 顶部操作栏
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  '${_index + 1}/${widget.imageUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16.0),
                ),
                // 「查看原图 / 缩略图」切换入口
                TextButton(
                  onPressed: () {
                    setState(() => _showOriginal = !_showOriginal);
                  },
                  child: Text(
                    _showOriginal ? '看缩略图' : '查看原图',
                    style: TextStyle(
                      color: _showOriginal ? Colors.amber : Colors.white,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 图片预览区（默认缩略图）
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image.network(
                    thumbUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // 缩略图失败 → 回退原图（存量图未补生成时保底）
                      if (!_showOriginal && thumbUrl != originalUrl) {
                        return Image.network(
                          originalUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image,
                                color: Colors.white, size: 48.0);
                          },
                        );
                      }
                      return const Icon(Icons.broken_image,
                          color: Colors.white, size: 48.0);
                    },
                  ),
                ),
                // 左右翻页
                if (widget.imageUrls.length > 1) ...[
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white70, size: 36),
                      onPressed: _index > 0 ? _prev : null,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.white70, size: 36),
                      onPressed: _index < widget.imageUrls.length - 1 ? _next : null,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 底部提示
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                _showOriginal ? '当前：原图' : '当前：缩略图 · 点右上「查看原图」加载高清',
                style: const TextStyle(color: Colors.white54, fontSize: 12.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
