import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logging/app_logger.dart';
import '../models/video.dart';
import 'cache_manager.dart';

/// Service that queries YouTube's InnerTube endpoint and public HTML endpoints
/// to deliver broad, live, YouTube-wide search results without requiring an API key.
class InnerTubeService {
  final http.Client _client;
  final CacheManager? _cacheManager;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  InnerTubeService({
    http.Client? client,
    CacheManager? cacheManager,
  })  : _client = client ?? http.Client(),
        _cacheManager = cacheManager;

  /// Performs a live search across all of YouTube using InnerTube API with HTML scraping fallback.
  Future<List<Video>> search(String query, {int limit = 35}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cacheKey = 'innertube_search_${trimmed.toLowerCase()}';
    if (_cacheManager != null) {
      final cached = _cacheManager.get(cacheKey);
      if (cached is List<dynamic>) {
        try {
          final list = cached
              .map((e) => Video.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty) return list;
        } catch (_) {}
      }
    }

    List<Video> results = [];

    // Attempt 1: InnerTube API
    try {
      results = await _searchInnerTube(trimmed, limit: limit);
    } catch (e) {
      AppLogger.debug('InnerTube search request failed: $e');
    }

    // Attempt 2: HTML scraping fallback if InnerTube returned empty
    if (results.isEmpty) {
      try {
        results = await _searchHtml(trimmed, limit: limit);
      } catch (e) {
        AppLogger.debug('InnerTube HTML scraping fallback failed: $e');
      }
    }

    if (results.isNotEmpty && _cacheManager != null) {
      try {
        _cacheManager.put(
          key: cacheKey,
          data: results.map((v) => v.toJson()).toList(),
          ttl: const Duration(minutes: 30),
        );
      } catch (_) {}
    }

    return results;
  }

  /// InnerTube v1/search endpoint
  Future<List<Video>> _searchInnerTube(String query, {required int limit}) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/search');
    final payload = jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20231201.00.00',
          'hl': 'en',
          'gl': 'US',
        },
      },
      'query': query,
    });

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': _userAgent,
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 7));

    if (response.statusCode != 200) {
      AppLogger.debug('InnerTube HTTP status: ${response.statusCode}');
      return [];
    }

    final data = jsonDecode(response.body);
    return _parseInnerTubeJson(data, limit: limit);
  }

  /// HTML scraping fallback for ytInitialData
  Future<List<Video>> _searchHtml(String query, {required int limit}) async {
    final filter = query.toLowerCase().contains('short') ? '' : '&sp=EgIQAQ%253D%253D';
    final uri = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}$filter',
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 7));

    if (response.statusCode != 200) return [];

    final html = response.body;
    final match = RegExp(r'var ytInitialData\s*=\s*({.+?});', dotAll: true).firstMatch(html);
    if (match == null) return [];

    final jsonStr = match.group(1);
    if (jsonStr == null) return [];

    final data = jsonDecode(jsonStr);
    return _parseInnerTubeJson(data, limit: limit);
  }

  /// Extracts Video models from InnerTube JSON payload
  List<Video> _parseInnerTubeJson(dynamic data, {required int limit}) {
    if (data is! Map) return [];

    final contents = data['contents']?['twoColumnSearchResultsRenderer']
        ?['primaryContents']?['sectionListRenderer']?['contents'] as List?;

    if (contents == null || contents.isEmpty) return [];

    final List<Video> videos = [];
    final Set<String> seenIds = {};

    for (final section in contents) {
      final items = section['itemSectionRenderer']?['contents'] as List?;
      if (items == null) continue;

      for (final item in items) {
        if (videos.length >= limit) break;

        // 1. Regular video renderer
        final vr = item['videoRenderer'];
        if (vr != null && vr is Map) {
          final videoId = vr['videoId']?.toString();
          if (videoId == null || videoId.isEmpty || seenIds.contains(videoId)) {
            continue;
          }

          final video = _parseVideoRenderer(vr, videoId);
          if (video != null) {
            seenIds.add(videoId);
            videos.add(video);
          }
          continue;
        }

        // 2. Shorts shelf (reelShelfRenderer)
        final reelShelf = item['reelShelfRenderer'];
        if (reelShelf != null && reelShelf is Map) {
          final reels = reelShelf['items'] as List?;
          if (reels != null) {
            for (final r in reels) {
              if (videos.length >= limit) break;
              final reel = r['reelItemRenderer'];
              if (reel != null && reel is Map) {
                final reelId = reel['videoId']?.toString();
                if (reelId == null || reelId.isEmpty || seenIds.contains(reelId)) {
                  continue;
                }
                final shortVideo = _parseReelItem(reel, reelId);
                if (shortVideo != null) {
                  seenIds.add(reelId);
                  videos.add(shortVideo);
                }
              }
            }
          }
        }

        // 3. Modern YouTube Shorts shelf (gridShelfViewModel)
        final gridShelf = item['gridShelfViewModel'];
        if (gridShelf != null && gridShelf is Map) {
          final shelfContents = gridShelf['contents'] as List?;
          if (shelfContents != null) {
            for (final c in shelfContents) {
              if (videos.length >= limit) break;
              if (c is Map && c['shortsLockupViewModel'] != null && c['shortsLockupViewModel'] is Map) {
                final sl = c['shortsLockupViewModel'] as Map;
                String? reelId = sl['onTap']?['innertubeCommand']?['reelWatchEndpoint']?['videoId']?.toString();
                if (reelId == null || reelId.isEmpty) {
                  final entityId = sl['entityId']?.toString();
                  if (entityId != null) {
                    reelId = entityId.replaceAll('shorts-shelf-item-', '');
                  }
                }
                if (reelId != null && reelId.isNotEmpty && !seenIds.contains(reelId)) {
                  final shortVideo = _parseShortsLockup(sl, reelId);
                  if (shortVideo != null) {
                    seenIds.add(reelId);
                    videos.add(shortVideo);
                  }
                }
              }
            }
          }
        }
      }
    }

    return videos;
  }

  Video? _parseShortsLockup(Map sl, String videoId) {
    try {
      final title = sl['overlayMetadata']?['primaryText']?['content']?.toString() ??
          sl['accessibilityText']?.toString() ??
          'Short';

      final viewCountStr = sl['overlayMetadata']?['secondaryText']?['content']?.toString();
      final viewCount = _parseViewCount(viewCountStr);

      final thumbs = sl['thumbnail']?['sources'] as List?;
      String thumbUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      if (thumbs != null && thumbs.isNotEmpty) {
        final last = thumbs.last;
        if (last is Map && last['url'] != null) {
          thumbUrl = last['url'].toString();
        }
      }

      return Video(
        id: videoId,
        title: title,
        description: '#shorts',
        thumbnailUrl: thumbUrl,
        highThumbnailUrl: 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
        channelId: 'channel_$videoId',
        channelTitle: 'YouTube Shorts',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
        duration: const Duration(seconds: 45),
        viewCount: viewCount > 0 ? viewCount : 500000,
        likeCount: (viewCount * 0.05).round(),
        isLive: false,
      );
    } catch (_) {
      return null;
    }
  }

  Video? _parseVideoRenderer(Map vr, String videoId) {
    try {
      final title = _extractText(vr['title']) ?? 'Untitled';
      final channelTitle = _extractText(vr['ownerText']) ??
          _extractText(vr['shortBylineText']) ??
          'Creator';

      final channelId = vr['ownerText']?['runs']?[0]?['navigationEndpoint']
              ?['browseEndpoint']?['browseId']
              ?.toString() ??
          vr['shortBylineText']?['runs']?[0]?['navigationEndpoint']
              ?['browseEndpoint']?['browseId']
              ?.toString() ??
          'channel_$videoId';

      final thumbs = vr['thumbnail']?['thumbnails'] as List?;
      String thumbUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      String? highThumbUrl;
      if (thumbs != null && thumbs.isNotEmpty) {
        final last = thumbs.last;
        if (last is Map && last['url'] != null) {
          thumbUrl = last['url'].toString();
        }
        if (thumbs.length > 1) {
          highThumbUrl = thumbUrl;
        }
      }

      final lengthStr = vr['lengthText']?['simpleText']?.toString() ??
          _extractText(vr['lengthText']);
      final duration = _parseDuration(lengthStr);

      final viewCountStr = vr['viewCountText']?['simpleText']?.toString() ??
          vr['shortViewCountText']?['simpleText']?.toString() ??
          _extractText(vr['viewCountText']);
      final viewCount = _parseViewCount(viewCountStr);

      final publishedStr = vr['publishedTimeText']?['simpleText']?.toString() ??
          _extractText(vr['publishedTimeText']);
      final publishedAt = _parseRelativeDate(publishedStr);

      final description = _extractDescription(vr);
      final isLive = lengthStr == null &&
          (vr['badges']?.toString().toLowerCase().contains('live') == true ||
              vr['thumbnailOverlays']?.toString().toLowerCase().contains('live') == true);

      return Video(
        id: videoId,
        title: title,
        description: description,
        thumbnailUrl: thumbUrl,
        highThumbnailUrl: highThumbUrl ?? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
        standardThumbnailUrl: 'https://img.youtube.com/vi/$videoId/sddefault.jpg',
        channelId: channelId,
        channelTitle: channelTitle,
        publishedAt: publishedAt,
        duration: duration,
        viewCount: viewCount,
        likeCount: (viewCount * 0.04).round(),
        isLive: isLive,
      );
    } catch (e) {
      AppLogger.debug('Failed to parse videoRenderer for $videoId: $e');
      return null;
    }
  }

  Video? _parseReelItem(Map reel, String videoId) {
    try {
      final title = reel['headline']?['simpleText']?.toString() ??
          _extractText(reel['headline']) ??
          'Short';

      final thumbs = reel['thumbnail']?['thumbnails'] as List?;
      String thumbUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      if (thumbs != null && thumbs.isNotEmpty) {
        final last = thumbs.last;
        if (last is Map && last['url'] != null) {
          thumbUrl = last['url'].toString();
        }
      }

      final viewCountStr = reel['viewCountText']?['simpleText']?.toString() ??
          _extractText(reel['viewCountText']);
      final viewCount = _parseViewCount(viewCountStr);

      return Video(
        id: videoId,
        title: title,
        description: '#shorts',
        thumbnailUrl: thumbUrl,
        highThumbnailUrl: 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
        channelId: 'channel_$videoId',
        channelTitle: 'YouTube Shorts',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
        duration: const Duration(seconds: 45),
        viewCount: viewCount,
        likeCount: (viewCount * 0.05).round(),
        isLive: false,
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractText(dynamic obj) {
    if (obj == null) return null;
    if (obj is String) return obj;
    if (obj is Map) {
      if (obj['simpleText'] != null) return obj['simpleText'].toString();
      final runs = obj['runs'] as List?;
      if (runs != null && runs.isNotEmpty) {
        return runs.map((r) => r is Map ? (r['text'] ?? '') : '').join();
      }
    }
    return null;
  }

  String _extractDescription(Map vr) {
    try {
      final snippets = vr['detailedMetadataSnippets'] as List?;
      if (snippets != null && snippets.isNotEmpty) {
        final text = _extractText(snippets[0]['snippetText']);
        if (text != null && text.isNotEmpty) return text;
      }
      final descSnippet = vr['descriptionSnippet'];
      if (descSnippet != null) {
        final text = _extractText(descSnippet);
        if (text != null && text.isNotEmpty) return text;
      }
    } catch (_) {}
    return '';
  }

  Duration? _parseDuration(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final parts = text.trim().split(':');
      if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      } else if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  int _parseViewCount(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final clean = text
        .replaceAll('views', '')
        .replaceAll('view', '')
        .replaceAll(',', '')
        .trim();
    final lower = clean.toLowerCase();
    try {
      if (lower.endsWith('b')) {
        final num = double.parse(lower.substring(0, lower.length - 1));
        return (num * 1000000000).round();
      } else if (lower.endsWith('m')) {
        final num = double.parse(lower.substring(0, lower.length - 1));
        return (num * 1000000).round();
      } else if (lower.endsWith('k')) {
        final num = double.parse(lower.substring(0, lower.length - 1));
        return (num * 1000).round();
      } else {
        return int.tryParse(clean) ?? 0;
      }
    } catch (_) {
      return 0;
    }
  }

  DateTime? _parseRelativeDate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match = RegExp(
      r'(\d+)\s*(second|minute|hour|day|week|month|year)s?\s*ago',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final count = int.tryParse(match.group(1) ?? '0') ?? 0;
    final unit = match.group(2)!.toLowerCase();
    final now = DateTime.now();
    switch (unit) {
      case 'second':
        return now.subtract(Duration(seconds: count));
      case 'minute':
        return now.subtract(Duration(minutes: count));
      case 'hour':
        return now.subtract(Duration(hours: count));
      case 'day':
        return now.subtract(Duration(days: count));
      case 'week':
        return now.subtract(Duration(days: count * 7));
      case 'month':
        return now.subtract(Duration(days: count * 30));
      case 'year':
        return now.subtract(Duration(days: count * 365));
      default:
        return now;
    }
  }
}
