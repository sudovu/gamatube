class Channel {
  final String id;
  final String title;
  final String description;
  final String avatarUrl;
  final String? bannerUrl;
  final int subscriberCount;
  final int videoCount;
  final bool isSubscribed;

  const Channel({
    required this.id,
    required this.title,
    required this.description,
    required this.avatarUrl,
    this.bannerUrl,
    this.subscriberCount = 0,
    this.videoCount = 0,
    this.isSubscribed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
      'isSubscribed': isSubscribed,
    };
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      bannerUrl: json['bannerUrl'] as String?,
      subscriberCount: json['subscriberCount'] as int? ?? 0,
      videoCount: json['videoCount'] as int? ?? 0,
      isSubscribed: json['isSubscribed'] as bool? ?? false,
    );
  }

  String get formattedSubscribers {
    if (subscriberCount >= 1000000) {
      return '${(subscriberCount / 1000000).toStringAsFixed(1)}M subscribers';
    } else if (subscriberCount >= 1000) {
      return '${(subscriberCount / 1000).toStringAsFixed(1)}K subscribers';
    } else if (subscriberCount > 0) {
      return '$subscriberCount subscribers';
    }
    return '';
  }

  Channel copyWith({
    String? id,
    String? title,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    int? subscriberCount,
    int? videoCount,
    bool? isSubscribed,
  }) {
    return Channel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      videoCount: videoCount ?? this.videoCount,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}
