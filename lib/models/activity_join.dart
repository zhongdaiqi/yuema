// 活动报名信息模型
class ActivityJoin {
  final int userId;
  final String nickname;
  final String avatar;
  final int noteId;
  final String name;
  final String phone;
  final String? wxId;
  final String createdAt;
  final int status; // 0-未审核 1-审核通过 2-审核未通过
  final String? memo;

  ActivityJoin({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.noteId,
    required this.name,
    required this.phone,
    this.wxId,
    required this.createdAt,
    required this.status,
    this.memo,
  });

  factory ActivityJoin.fromJson(Map<String, dynamic> json) {
    return ActivityJoin(
      userId: json['userId'] ?? 0,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      noteId: json['noteId'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      wxId: json['wxId'],
      createdAt: json['createdAt'] ?? '',
      status: json['status'] ?? 0,
      memo: json['memo'],
    );
  }

  // 获取状态文本描述
  String get statusText {
    switch (status) {
      case 0:
        return '未审核';
      case 1:
        return '审核通过';
      case 2:
        return '审核未通过';
      default:
        return '未知状态';
    }
  }

  // 获取状态颜色
  // 获取状态颜色
  String get statusColor {
    switch (status) {
      case 0:
        return 'orange'; // 未审核 - 橙色
      case 1:
        return 'green'; // 审核通过 - 绿色
      case 2:
        return 'red'; // 审核未通过 - 红色
      default:
        return 'grey'; // 未知状态 - 灰色
    }
  }
}
