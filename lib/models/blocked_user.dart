class BlockedUser {
  final int id;
  final int userId;
  final int blockedUserId;
  final String appId;
  final String createdAt;
  final String updatedAt;

  BlockedUser({
    required this.id,
    required this.userId,
    required this.blockedUserId,
    required this.appId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      blockedUserId: json['blockedUserId'] ?? 0,
      appId: json['appId'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}
