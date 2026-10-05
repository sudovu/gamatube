class Comment {
  final String id;
  final String authorName;
  final String authorAvatarUrl;
  final String text;
  final DateTime? publishedAt;
  final int likeCount;
  final int replyCount;

  const Comment({
    required this.id,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.text,
    this.publishedAt,
    this.likeCount = 0,
    this.replyCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'text': text,
      'publishedAt': publishedAt?.toIso8601String(),
      'likeCount': likeCount,
      'replyCount': replyCount,
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorAvatarUrl: json['authorAvatarUrl'] as String? ?? '',
      text: json['text'] as String? ?? '',
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      likeCount: json['likeCount'] as int? ?? 0,
      replyCount: json['replyCount'] as int? ?? 0,
    );
  }

  String get formattedTimeAgo {
    if (publishedAt == null) return '';
    final diff = DateTime.now().difference(publishedAt!);
    if (diff.inDays >= 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays >= 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inMinutes}m ago';
  }
}
