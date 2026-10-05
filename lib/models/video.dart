class Video {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String? highThumbnailUrl;
  final String? standardThumbnailUrl;
  final String channelId;
  final String channelTitle;
  final String? channelAvatarUrl;
  final DateTime? publishedAt;
  final Duration? duration;
  final int viewCount;
  final int likeCount;
  final bool isLive;

  const Video({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    this.highThumbnailUrl,
    this.standardThumbnailUrl,
    required this.channelId,
    required this.channelTitle,
    this.channelAvatarUrl,
    this.publishedAt,
    this.duration,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isLive = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'highThumbnailUrl': highThumbnailUrl,
      'standardThumbnailUrl': standardThumbnailUrl,
      'channelId': channelId,
      'channelTitle': channelTitle,
      'channelAvatarUrl': channelAvatarUrl,
      'publishedAt': publishedAt?.toIso8601String(),
      'durationMs': duration?.inMilliseconds,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'isLive': isLive,
    };
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      highThumbnailUrl: json['highThumbnailUrl'] as String?,
      standardThumbnailUrl: json['standardThumbnailUrl'] as String?,
      channelId: json['channelId'] as String? ?? '',
      channelTitle: json['channelTitle'] as String? ?? '',
      channelAvatarUrl: json['channelAvatarUrl'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      viewCount: json['viewCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      isLive: json['isLive'] as bool? ?? false,
    );
  }

  String get formattedViews {
    if (viewCount >= 1000000000) {
      return '${(viewCount / 1000000000).toStringAsFixed(1)}B views';
    } else if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K views';
    } else if (viewCount > 0) {
      return '$viewCount views';
    }
    return '';
  }

  String get formattedDuration {
    if (duration == null) return '';
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedTimeAgo {
    if (publishedAt == null) return '';
    final diff = DateTime.now().difference(publishedAt!);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago';
    }
    return 'Just now';
  }

  Video copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? highThumbnailUrl,
    String? standardThumbnailUrl,
    String? channelId,
    String? channelTitle,
    String? channelAvatarUrl,
    DateTime? publishedAt,
    Duration? duration,
    int? viewCount,
    int? likeCount,
    bool? isLive,
  }) {
    return Video(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      highThumbnailUrl: highThumbnailUrl ?? this.highThumbnailUrl,
      standardThumbnailUrl: standardThumbnailUrl ?? this.standardThumbnailUrl,
      channelId: channelId ?? this.channelId,
      channelTitle: channelTitle ?? this.channelTitle,
      channelAvatarUrl: channelAvatarUrl ?? this.channelAvatarUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      duration: duration ?? this.duration,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      isLive: isLive ?? this.isLive,
    );
  }
}
