import 'video.dart';

class WatchHistoryItem {
  final Video video;
  final DateTime watchedAt;
  final Duration position;
  final Duration duration;
  final double completionPercentage;

  const WatchHistoryItem({
    required this.video,
    required this.watchedAt,
    required this.position,
    required this.duration,
    required this.completionPercentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'video': video.toJson(),
      'watchedAt': watchedAt.toIso8601String(),
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'completionPercentage': completionPercentage,
    };
  }

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    final video = Video.fromJson(json['video'] as Map<String, dynamic>? ?? {});
    final watchedAt = json['watchedAt'] != null
        ? DateTime.tryParse(json['watchedAt'] as String) ?? DateTime.now()
        : DateTime.now();
    final posMs = json['positionMs'] as int? ?? 0;
    final durMs = json['durationMs'] as int? ?? 1;
    final position = Duration(milliseconds: posMs);
    final duration = Duration(milliseconds: durMs);
    final pct = json['completionPercentage'] as num? ?? (posMs / (durMs > 0 ? durMs : 1));

    return WatchHistoryItem(
      video: video,
      watchedAt: watchedAt,
      position: position,
      duration: duration,
      completionPercentage: pct.toDouble().clamp(0.0, 1.0),
    );
  }

  String get formattedPosition {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  WatchHistoryItem copyWith({
    Video? video,
    DateTime? watchedAt,
    Duration? position,
    Duration? duration,
    double? completionPercentage,
  }) {
    return WatchHistoryItem(
      video: video ?? this.video,
      watchedAt: watchedAt ?? this.watchedAt,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      completionPercentage: completionPercentage ?? this.completionPercentage,
    );
  }
}
