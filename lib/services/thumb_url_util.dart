/// 缩略图 URL 工具（2026-11-23）
///
/// 背景：活动瀑布流直接加载原图（单张 2~5MB），一屏十几张严重拖慢加载。
/// 后端在上传时 / 批量补生成时，把缩略图写成真实静态文件：
///   原图  http://host/picture/20251206/uuid.png
///   缩略图 http://host/picture/20251206/thumb/w640/uuid.png
/// 走的是和原图完全相同的 CDN 回源规则，无需额外接口。
///
/// 本工具只做 URL 字符串变换，不依赖任何包；对非本服务的图片（外链、
/// avatar 模板等）原样返回，避免把第三方 URL 拼坏。
class ThumbUrlUtil {
  /// 默认缩略图宽度，与后端 ImageThumbUtil.DEFAULT_WIDTH 保持一致
  static const int defaultWidth = 640;

  /// 原图 URL -> 缩略图 URL。已经是缩略图的不会重复插入 thumb 段。
  static String of(String url, {int width = defaultWidth}) {
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return url;
    if (url.contains('/thumb/w')) return url; // 幂等

    final q = url.indexOf('?');
    final base = q >= 0 ? url.substring(0, q) : url;
    final query = q >= 0 ? url.substring(q) : '';

    // 只处理本服务 picture / avatar 下的图片（含日期子目录）
    final marker = _markerOf(base);
    if (marker == null) return url;

    final markerPos = base.indexOf(marker);
    final afterMarker = base.substring(markerPos + marker.length);
    final slash = afterMarker.lastIndexOf('/');
    // 需要形如 /picture/<目录>/<文件>，至少有一层目录
    if (slash <= 0) return url;

    final dir = afterMarker.substring(0, slash);
    final file = afterMarker.substring(slash + 1);
    if (file.isEmpty) return url;

    return '${base.substring(0, markerPos + marker.length)}$dir/thumb/w$width/$file$query';
  }

  /// 返回 '/picture/' 或 '/avatar/'，非本服务图片返回 null
  static String? _markerOf(String url) {
    if (url.contains('/picture/')) return '/picture/';
    if (url.contains('/avatar/')) return '/avatar/';
    return null;
  }

  /// 判断是否为缩略图 URL
  static bool isThumb(String url) => url.contains('/thumb/w');

  /// 头像缩略图目录段（与后端 ImageThumbUtil.AVATAR_THUMB_DIR = s100 一致）
  static const String avatarThumbSeg = '/thumb/s100/';

  /// 头像原图 URL -> 100x100 正方形缩略图 URL。
  /// 后端上传头像时同步生成 thumb/s100/ 静态文件（居中裁剪，不拉伸）。
  /// - 空串 / 非 http(s) 外链 / 已是缩略图：原样返回（幂等）
  /// - 仅处理 /avatar/ 下的本服务图片，避免拼坏第三方 URL
  static String avatar100(String url) {
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return url;
    if (url.contains(avatarThumbSeg)) return url; // 幂等

    final q = url.indexOf('?');
    final base = q >= 0 ? url.substring(0, q) : url;
    final query = q >= 0 ? url.substring(q) : '';
    final marker = '/avatar/';
    final markerPos = base.indexOf(marker);
    if (markerPos < 0) return url;

    final afterMarker = base.substring(markerPos + marker.length);
    final slash = afterMarker.lastIndexOf('/');
    if (slash <= 0) return url; // 需要 /avatar/<目录>/<文件>
    final file = afterMarker.substring(slash + 1);
    if (file.isEmpty) return url;

    return '${base.substring(0, markerPos + marker.length)}'
        '${afterMarker.substring(0, slash + 1)}'
        'thumb/s100/$file$query';
  }

  /// 判断是否为头像 100x100 缩略图 URL
  static bool isAvatarThumb(String url) => url.contains(avatarThumbSeg);
}
