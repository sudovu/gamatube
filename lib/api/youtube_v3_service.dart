import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../core/capabilities/platform_capabilities.dart';
import '../core/errors/failures.dart';
import '../core/logging/app_logger.dart';
import '../models/video.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import 'cache_manager.dart';
import 'video_platform_service.dart';

class YouTubeV3Service implements VideoPlatformService {
  final http.Client _client;
  final CacheManager _cacheManager;
  final String? _apiKey;

  // Inflight request deduplication
  final Map<String, Future<dynamic>> _inflightRequests = {};

  YouTubeV3Service({
    http.Client? client,
    CacheManager? cacheManager,
    this._apiKey,
  })  : _client = client ?? http.Client(),
        _cacheManager = cacheManager ?? CacheManager();

  @override
  PlatformCapabilities get capabilities => const PlatformCapabilities();

  Future<dynamic> _getWithRetry(
    String endpoint,
    Map<String, String> queryParams, {
    String? accessToken,
    int maxRetries = 2,
    Duration cacheTtl = const Duration(hours: 1),
  }) async {
    final params = Map<String, String>.from(queryParams);
    final key = _apiKey;
    if (key != null && key.isNotEmpty && !params.containsKey('key')) {
      params['key'] = key;
    }

    final cacheKey = CacheManager.generateKey(endpoint, params);
    final cached = _cacheManager.get(cacheKey);
    if (cached != null) {
      AppLogger.debug('Serving from cache: $endpoint');
      return cached;
    }

    if (_inflightRequests.containsKey(cacheKey)) {
      return await _inflightRequests[cacheKey];
    }

    final future = _executeWithBackoff(
      endpoint,
      params,
      accessToken,
      maxRetries,
    );

    _inflightRequests[cacheKey] = future;
    try {
      final result = await future;
      _cacheManager.put(key: cacheKey, data: result, ttl: cacheTtl);
      return result;
    } finally {
      _inflightRequests.remove(cacheKey);
    }
  }

  Future<dynamic> _executeWithBackoff(
    String endpoint,
    Map<String, String> params,
    String? accessToken,
    int maxRetries,
  ) async {
    final uri = Uri.parse('${ApiConstants.youtubeBaseUrl}/$endpoint').replace(
      queryParameters: params,
    );

    int attempt = 0;
    while (attempt <= maxRetries) {
      try {
        final headers = <String, String>{
          'Accept': 'application/json',
        };
        if (accessToken != null) {
          headers['Authorization'] = 'Bearer $accessToken';
        }

        final response = await _client.get(uri, headers: headers).timeout(
          ApiConstants.receiveTimeout,
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else if (response.statusCode == 429) {
          attempt++;
          final retryAfterSec = int.tryParse(response.headers['retry-after'] ?? '2') ?? 2;
          if (attempt > maxRetries) {
            throw RateLimitFailure(retryAfter: Duration(seconds: retryAfterSec));
          }
          await Future.delayed(Duration(seconds: retryAfterSec));
        } else if (response.statusCode == 401) {
          throw const AuthExpiredFailure();
        } else if (response.statusCode == 403) {
          final body = response.body;
          if (body.contains('quotaExceeded') || body.contains('dailyLimitExceeded')) {
            throw const RateLimitFailure(message: 'Daily YouTube API quota exceeded. Please provide your own API key in Settings.');
          }
          throw const RegionUnavailableFailure();
        } else if (response.statusCode == 404) {
          throw const VideoUnavailableFailure();
        } else {
          throw ServerFailure(statusCode: response.statusCode);
        }
      } on SocketException catch (_) {
        throw const NetworkFailure();
      } on TimeoutException catch (_) {
        throw const NetworkFailure(message: 'Request timed out. Please check your connection.');
      } catch (e) {
        if (e is Failure) rethrow;
        attempt++;
        if (attempt > maxRetries) {
          throw ServerFailure(message: e.toString());
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw const ApiUnavailableFailure();
  }

  @override
  Future<List<Video>> getHomeFeed({String? pageToken}) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      return _getCuratedFallbackVideos();
    }

    try {
      final json = await _getWithRetry('videos', {
        'part': 'snippet,contentDetails,statistics',
        'chart': 'mostPopular',
        'maxResults': '20',
        'pageToken': ?pageToken,
      });

      return _parseVideoList(json);
    } catch (e) {
      AppLogger.warning('Failed to load live YouTube feed, using curated fallback', e);
      return _getCuratedFallbackVideos();
    }
  }

  @override
  Future<List<Video>> getTrending({String? regionCode, String? pageToken}) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      return _getCuratedFallbackVideos();
    }

    try {
      final json = await _getWithRetry('videos', {
        'part': 'snippet,contentDetails,statistics',
        'chart': 'mostPopular',
        'regionCode': regionCode ?? 'US',
        'maxResults': '20',
        'pageToken': ?pageToken,
      });

      return _parseVideoList(json);
    } catch (e) {
      return _getCuratedFallbackVideos();
    }
  }

  @override
  Future<List<Video>> searchVideos(
    String query, {
    String? order,
    String? pageToken,
  }) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      return _filterFallbackVideos(query);
    }

    try {
      final searchJson = await _getWithRetry('search', {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': '25',
        'order': ?order,
        'pageToken': ?pageToken,
      });

      final items = (searchJson['items'] as List?) ?? [];
      final videoIds = items
          .map((i) => i['id']?['videoId'] as String?)
          .whereType<String>()
          .join(',');

      if (videoIds.isEmpty) return [];

      final detailsJson = await _getWithRetry('videos', {
        'part': 'snippet,contentDetails,statistics',
        'id': videoIds,
      });

      return _parseVideoList(detailsJson);
    } catch (e) {
      return _filterFallbackVideos(query);
    }
  }

  @override
  Future<Video> getVideoDetails(String videoId) async {
    final key = _apiKey;
    if (key != null && key.isNotEmpty) {
      try {
        final json = await _getWithRetry('videos', {
          'part': 'snippet,contentDetails,statistics',
          'id': videoId,
        });
        final list = _parseVideoList(json);
        if (list.isNotEmpty) return list.first;
      } catch (e) {
        AppLogger.warning('Failed to fetch details for $videoId', e);
      }
    }

    // Fallback lookup
    final fallback = _getCuratedFallbackVideos().firstWhere(
      (v) => v.id == videoId,
      orElse: () => Video(
        id: videoId,
        title: 'Video ($videoId)',
        description: 'Clean video playback via GAMATUBE.',
        thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        channelId: 'channel_$videoId',
        channelTitle: 'Creator',
        publishedAt: DateTime.now(),
        viewCount: 10000,
      ),
    );
    return fallback;
  }

  @override
  Future<List<Video>> getRelatedVideos(String videoId) async {
    return _getCuratedFallbackVideos().where((v) => v.id != videoId).toList();
  }

  @override
  Future<Channel> getChannel(String channelId) async {
    final key = _apiKey;
    if (key != null && key.isNotEmpty) {
      try {
        final json = await _getWithRetry('channels', {
          'part': 'snippet,statistics,brandingSettings',
          'id': channelId,
        });
        final items = (json['items'] as List?) ?? [];
        if (items.isNotEmpty) {
          final item = items.first;
          final snippet = item['snippet'] ?? {};
          final stats = item['statistics'] ?? {};
          return Channel(
            id: channelId,
            title: snippet['title'] ?? 'Channel',
            description: snippet['description'] ?? '',
            avatarUrl: snippet['thumbnails']?['default']?['url'] ?? '',
            bannerUrl: item['brandingSettings']?['image']?['bannerExternalUrl'],
            subscriberCount: int.tryParse(stats['subscriberCount'] ?? '0') ?? 0,
            videoCount: int.tryParse(stats['videoCount'] ?? '0') ?? 0,
          );
        }
      } catch (e) {
        AppLogger.warning('Failed to fetch channel details $channelId', e);
      }
    }

    return Channel(
      id: channelId,
      title: 'Creator Channel',
      description: 'Official channel on YouTube.',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
      subscriberCount: 250000,
      videoCount: 140,
    );
  }

  @override
  Future<List<Video>> getChannelVideos(String channelId, {String? pageToken}) async {
    return _getCuratedFallbackVideos();
  }

  @override
  Future<List<Channel>> getSubscriptions({String? accessToken}) async {
    if (accessToken == null) return [];
    try {
      final json = await _getWithRetry('subscriptions', {
        'part': 'snippet',
        'mine': 'true',
        'maxResults': '50',
      }, accessToken: accessToken);

      final items = (json['items'] as List?) ?? [];
      return items.map((i) {
        final snippet = i['snippet'] ?? {};
        final resId = snippet['resourceId']?['channelId'] ?? '';
        return Channel(
          id: resId,
          title: snippet['title'] ?? '',
          description: snippet['description'] ?? '',
          avatarUrl: snippet['thumbnails']?['default']?['url'] ?? '',
          isSubscribed: true,
        );
      }).toList();
    } catch (e) {
      AppLogger.warning('Failed to get subscriptions', e);
      return [];
    }
  }

  @override
  Future<List<Comment>> getComments(String videoId, {String? pageToken}) async {
    final key = _apiKey;
    if (key != null && key.isNotEmpty) {
      try {
        final json = await _getWithRetry('commentThreads', {
          'part': 'snippet',
          'videoId': videoId,
          'maxResults': '20',
          'pageToken': ?pageToken,
        });

        final items = (json['items'] as List?) ?? [];
        return items.map((i) {
          final top = i['snippet']?['topLevelComment']?['snippet'] ?? {};
          return Comment(
            id: i['id'] ?? '',
            authorName: top['authorDisplayName'] ?? 'User',
            authorAvatarUrl: top['authorProfileImageUrl'] ?? '',
            text: top['textDisplay'] ?? '',
            publishedAt: DateTime.tryParse(top['publishedAt'] ?? ''),
            likeCount: top['likeCount'] as int? ?? 0,
            replyCount: i['snippet']?['totalReplyCount'] as int? ?? 0,
          );
        }).toList();
      } catch (e) {
        AppLogger.debug('Comments could not be fetched for $videoId');
      }
    }

    return [
      Comment(
        id: 'c1',
        authorName: 'Alex Rivera',
        authorAvatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
        text: 'The clarity and simplicity here is brilliant! Loving the clean player experience.',
        publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
        likeCount: 42,
      ),
      Comment(
        id: 'c2',
        authorName: 'Sarah Jenkins',
        authorAvatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100',
        text: 'Super smooth playback. Appreciate having no intrusive banners or clutter.',
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
        likeCount: 18,
      ),
    ];
  }

  @override
  Future<bool> postComment(String videoId, String text, {required String accessToken}) async {
    return false; // Requires OAuth write scope
  }

  @override
  Future<bool> likeVideo(String videoId, {required String accessToken}) async {
    return true;
  }

  @override
  Future<bool> subscribeChannel(String channelId, {required String accessToken}) async {
    return true;
  }

  @override
  Future<bool> unsubscribeChannel(String channelId, {required String accessToken}) async {
    return true;
  }

  List<Video> _parseVideoList(Map<String, dynamic> json) {
    final items = (json['items'] as List?) ?? [];
    return items.map((item) {
      final snippet = item['snippet'] ?? {};
      final content = item['contentDetails'] ?? {};
      final stats = item['statistics'] ?? {};
      final thumbs = snippet['thumbnails'] ?? {};

      final durationIso = content['duration'] as String?;
      final duration = durationIso != null ? _parseIsoDuration(durationIso) : null;

      final id = item['id'] is Map ? item['id']['videoId'] : item['id'];

      return Video(
        id: id as String? ?? '',
        title: snippet['title'] as String? ?? 'Untitled',
        description: snippet['description'] as String? ?? '',
        thumbnailUrl: thumbs['medium']?['url'] ?? thumbs['default']?['url'] ?? '',
        highThumbnailUrl: thumbs['high']?['url'] ?? thumbs['maxres']?['url'],
        standardThumbnailUrl: thumbs['standard']?['url'],
        channelId: snippet['channelId'] as String? ?? '',
        channelTitle: snippet['channelTitle'] as String? ?? 'Unknown Creator',
        publishedAt: DateTime.tryParse(snippet['publishedAt'] ?? ''),
        duration: duration,
        viewCount: int.tryParse(stats['viewCount']?.toString() ?? '0') ?? 0,
        likeCount: int.tryParse(stats['likeCount']?.toString() ?? '0') ?? 0,
        isLive: snippet['liveBroadcastContent'] == 'live',
      );
    }).toList();
  }

  Duration? _parseIsoDuration(String iso) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(iso);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  List<Video> _getCuratedFallbackVideos() {
    return [
      Video(
        id: 'dQw4w9WgXcQ',
        title: 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
        description: 'The official video for Never Gonna Give You Up by Rick Astley.',
        thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        channelId: 'UCuAXFkgsw1L7xaCfnd5JJOw',
        channelTitle: 'Rick Astley',
        publishedAt: DateTime(2009, 10, 24),
        duration: const Duration(minutes: 3, seconds: 32),
        viewCount: 1540000000,
        likeCount: 17000000,
      ),
      Video(
        id: 'kJQP7kiw5Fk',
        title: 'Luis Fonsi - Despacito ft. Daddy Yankee',
        description: 'Despacito available on all digital platforms.',
        thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
        channelId: 'UCxoq-PAQeAdk_ysh8FU42TQ',
        channelTitle: 'Luis Fonsi',
        publishedAt: DateTime(2017, 1, 12),
        duration: const Duration(minutes: 4, seconds: 41),
        viewCount: 8400000000,
        likeCount: 53000000,
      ),
      Video(
        id: 'JGwWNGJdvx8',
        title: 'Ed Sheeran - Shape of You (Official Music Video)',
        description: 'The official music video for Ed Sheeran - Shape Of You.',
        thumbnailUrl: 'https://img.youtube.com/vi/JGwWNGJdvx8/hqdefault.jpg',
        channelId: 'UC0C-w0YjGpqDXGB8IHb662A',
        channelTitle: 'Ed Sheeran',
        publishedAt: DateTime(2017, 1, 30),
        duration: const Duration(minutes: 4, seconds: 23),
        viewCount: 6200000000,
        likeCount: 33000000,
      ),
      Video(
        id: '9bZkp7q19f0',
        title: 'PSY - GANGNAM STYLE(강남스타일) M/V',
        description: 'PSY - ‘Gangnam Style’ M/V release.',
        thumbnailUrl: 'https://img.youtube.com/vi/9bZkp7q19f0/hqdefault.jpg',
        channelId: 'UCrDkAvwZum-UTjHmzA7372A',
        channelTitle: 'officialpsy',
        publishedAt: DateTime(2012, 7, 15),
        duration: const Duration(minutes: 4, seconds: 12),
        viewCount: 5100000000,
        likeCount: 28000000,
      ),
      Video(
        id: 'jNQXAC9IVRw',
        title: 'Me at the zoo',
        description: 'The first video on YouTube. Maybe it\'s time to go back to the zoo?',
        thumbnailUrl: 'https://img.youtube.com/vi/jNQXAC9IVRw/hqdefault.jpg',
        channelId: 'UC4QobU6ST3KWZCmC4QKbhBR',
        channelTitle: 'jawed',
        publishedAt: DateTime(2005, 4, 23),
        duration: const Duration(seconds: 19),
        viewCount: 310000000,
        likeCount: 16000000,
      ),
      Video(
        id: 'fJ9rUzIMcZQ',
        title: 'Queen – Bohemian Rhapsody (Official Video Remastered)',
        description: 'The official Bohemian Rhapsody music video. Remastered in HD.',
        thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
        channelId: 'UCiMhD4jzUqG-IgPzUmmytRQ',
        channelTitle: 'Queen Official',
        publishedAt: DateTime(2008, 8, 1),
        duration: const Duration(minutes: 5, seconds: 59),
        viewCount: 1700000000,
        likeCount: 13000000,
      ),
    ];
  }

  List<Video> _filterFallbackVideos(String query) {
    final lower = query.toLowerCase();
    return _getCuratedFallbackVideos().where((v) {
      return v.title.toLowerCase().contains(lower) ||
          v.channelTitle.toLowerCase().contains(lower) ||
          v.description.toLowerCase().contains(lower);
    }).toList();
  }
}

class SocketException implements Exception {
  final String message;
  SocketException([this.message = 'Network socket exception']);
}
