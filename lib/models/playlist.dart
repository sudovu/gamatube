import 'video.dart';

class Playlist {
  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final int videoCount;
  final bool isLocal;
  final DateTime createdAt;
  final List<Video> items;

  const Playlist({
    required this.id,
    required this.title,
    this.description = '',
    this.thumbnailUrl,
    this.videoCount = 0,
    this.isLocal = true,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'videoCount': items.isNotEmpty ? items.length : videoCount,
      'isLocal': isLocal,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((v) => v.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List?;
    final itemsList = rawItems != null
        ? rawItems.whereType<Map<String, dynamic>>().map((v) => Video.fromJson(v)).toList()
        : <Video>[];

    return Playlist(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      videoCount: json['videoCount'] as int? ?? itemsList.length,
      isLocal: json['isLocal'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: itemsList,
    );
  }

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    int? videoCount,
    bool? isLocal,
    DateTime? createdAt,
    List<Video>? items,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoCount: videoCount ?? this.videoCount,
      isLocal: isLocal ?? this.isLocal,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
