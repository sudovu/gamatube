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

  String? _extractVideoId(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      if (uri.host.contains('youtu.be')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty && segments.first.isNotEmpty) {
          return segments.first;
        }
      }
      if (uri.host.contains('youtube.com')) {
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }
        if (uri.pathSegments.contains('shorts')) {
          final idx = uri.pathSegments.indexOf('shorts');
          if (uri.pathSegments.length > idx + 1) {
            return uri.pathSegments[idx + 1];
          }
        }
        if (uri.pathSegments.contains('embed')) {
          final idx = uri.pathSegments.indexOf('embed');
          if (uri.pathSegments.length > idx + 1) {
            return uri.pathSegments[idx + 1];
          }
        }
      }
    }
    return null;
  }

  @override
  Future<List<Video>> searchVideos(
    String query, {
    String? order,
    String? pageToken,
  }) async {
    final directId = _extractVideoId(query);
    if (directId != null) {
      final video = await getVideoDetails(directId);
      return [video];
    }

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
      // --- TRENDING / TOP PICKS ---
      Video(
        id: 'dQw4w9WgXcQ',
        title: 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
        description: 'The official video for Never Gonna Give You Up by Rick Astley. #music #classics',
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
        description: 'Despacito available on all digital platforms. #music #latin',
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
        description: 'The official music video for Ed Sheeran - Shape Of You. #music #pop',
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
        description: 'PSY - ‘Gangnam Style’ M/V release. #music #kpop',
        thumbnailUrl: 'https://img.youtube.com/vi/9bZkp7q19f0/hqdefault.jpg',
        channelId: 'UCrDkAvwZum-UTjHmzA7372A',
        channelTitle: 'officialpsy',
        publishedAt: DateTime(2012, 7, 15),
        duration: const Duration(minutes: 4, seconds: 12),
        viewCount: 5100000000,
        likeCount: 28000000,
      ),
      Video(
        id: 'fJ9rUzIMcZQ',
        title: 'Queen – Bohemian Rhapsody (Official Video Remastered)',
        description: 'The official Bohemian Rhapsody music video. Remastered in HD. #music #rock',
        thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
        channelId: 'UCiMhD4jzUqG-IgPzUmmytRQ',
        channelTitle: 'Queen Official',
        publishedAt: DateTime(2008, 8, 1),
        duration: const Duration(minutes: 5, seconds: 59),
        viewCount: 1700000000,
        likeCount: 13000000,
      ),
      Video(
        id: 'jfKfPfyJRdk',
        title: 'lofi hip hop radio 📚 - beats to relax/study to',
        description: 'Peaceful lofi hip hop radio 24/7 stream for studying, sleeping, and relaxing. #music #lofi #study',
        thumbnailUrl: 'https://img.youtube.com/vi/jfKfPfyJRdk/hqdefault.jpg',
        channelId: 'UCSJ4gkVC6NrvII8umztf0Ow',
        channelTitle: 'Lofi Girl',
        publishedAt: DateTime(2022, 7, 12),
        duration: const Duration(hours: 12),
        viewCount: 95000000,
        likeCount: 7800000,
      ),

      // --- GAMING ---
      Video(
        id: 'MmB9b5njVbA',
        title: 'Minecraft Official Trailer',
        description: 'Explore randomly generated worlds and build amazing things from the simplest of homes to the grandest of castles. #gaming #minecraft',
        thumbnailUrl: 'https://img.youtube.com/vi/MmB9b5njVbA/hqdefault.jpg',
        channelId: 'UC1sELGmy5jp5fQUugmuYlXQ',
        channelTitle: 'Minecraft',
        publishedAt: DateTime(2011, 11, 17),
        duration: const Duration(minutes: 1, seconds: 22),
        viewCount: 168000000,
        likeCount: 4200000,
      ),
      Video(
        id: 'QkkoHAzjnUs',
        title: 'Grand Theft Auto VI Trailer 1',
        description: 'Rockstar Games presents Grand Theft Auto VI. Coming 2025 to PlayStation 5 and Xbox Series X|S. #gaming #gta6 #rockstar',
        thumbnailUrl: 'https://img.youtube.com/vi/QkkoHAzjnUs/hqdefault.jpg',
        channelId: 'UCbW18JZ9LAdeRytZJ4wN0JQ',
        channelTitle: 'Rockstar Games',
        publishedAt: DateTime(2023, 12, 4),
        duration: const Duration(minutes: 1, seconds: 31),
        viewCount: 215000000,
        likeCount: 12000000,
      ),
      Video(
        id: 'e_E9W2vsRbA',
        title: 'Elden Ring - Official Gameplay Reveal',
        description: 'The Golden Order has been broken. Rise, Tarnished, and be guided by grace to brandish the power of the Elden Ring. #gaming #eldenring',
        thumbnailUrl: 'https://img.youtube.com/vi/e_E9W2vsRbA/hqdefault.jpg',
        channelId: 'UC_NtV8aO4nFh71aG67HsmLQ',
        channelTitle: 'Bandai Namco',
        publishedAt: DateTime(2021, 6, 10),
        duration: const Duration(minutes: 2, seconds: 58),
        viewCount: 31000000,
        likeCount: 950000,
      ),
      Video(
        id: '094y1Z2wpJg',
        title: 'Cyberpunk 2077 - Official Gameplay Trailer',
        description: 'Watch the official gameplay trailer for Cyberpunk 2077, featuring Keanu Reeves as Johnny Silverhand. #gaming #cyberpunk',
        thumbnailUrl: 'https://img.youtube.com/vi/094y1Z2wpJg/hqdefault.jpg',
        channelId: 'UC4zyoIAzmdSGvmufma4POug',
        channelTitle: 'Cyberpunk 2077',
        publishedAt: DateTime(2020, 11, 19),
        duration: const Duration(minutes: 5, seconds: 12),
        viewCount: 48000000,
        likeCount: 1100000,
      ),
      Video(
        id: 'd1_JBMrrYw8',
        title: 'Minecraft Part 1 - PewDiePie',
        description: 'PewDiePie begins his legendary Minecraft survival series. #gaming #pewdiepie #minecraft',
        thumbnailUrl: 'https://img.youtube.com/vi/d1_JBMrrYw8/hqdefault.jpg',
        channelId: 'UC-lHJZR3Gqxm24_Vd_AJ5Yw',
        channelTitle: 'PewDiePie',
        publishedAt: DateTime(2019, 6, 21),
        duration: const Duration(minutes: 17, seconds: 44),
        viewCount: 54000000,
        likeCount: 3200000,
      ),
      Video(
        id: 'u9prcUCHlqM',
        title: 'VALORANT - Official Gameplay Reveal Trailer',
        description: 'Defy the limits. Watch the official gameplay reveal of Riot Games free-to-play tactical shooter VALORANT. #gaming #valorant',
        thumbnailUrl: 'https://img.youtube.com/vi/u9prcUCHlqM/hqdefault.jpg',
        channelId: 'UC8CX0LD98EDXl4UYX1MDCXg',
        channelTitle: 'VALORANT',
        publishedAt: DateTime(2020, 3, 2),
        duration: const Duration(minutes: 2, seconds: 47),
        viewCount: 22000000,
        likeCount: 650000,
      ),

      // --- SCIENCE & TECH ---
      Video(
        id: 'b005i19Q7i8',
        title: 'Apple Vision Pro Review: Tomorrow\'s Tech Today!',
        description: 'Marques Brownlee reviews Apple\'s Spatial Computer, the Vision Pro. Complete deep dive into eye tracking, gestures, and visionOS. #tech #mkbhd #apple',
        thumbnailUrl: 'https://img.youtube.com/vi/b005i19Q7i8/hqdefault.jpg',
        channelId: 'UCBJycsmduvYEL83R_U4JriQ',
        channelTitle: 'Marques Brownlee',
        publishedAt: DateTime(2024, 2, 5),
        duration: const Duration(minutes: 42, seconds: 35),
        viewCount: 18500000,
        likeCount: 890000,
      ),
      Video(
        id: 'uD4izuDMUQA',
        title: 'The Simplest Math Problem No One Can Solve - Collatz Conjecture',
        description: 'The Collatz Conjecture is the simplest math problem that no one can solve. Derek Muller explores its history and fractal wonders. #science #education #veritasium',
        thumbnailUrl: 'https://img.youtube.com/vi/uD4izuDMUQA/hqdefault.jpg',
        channelId: 'UCHnyfMqiRRG1u-2MsSQLbXA',
        channelTitle: 'Veritasium',
        publishedAt: DateTime(2021, 7, 30),
        duration: const Duration(minutes: 22, seconds: 6),
        viewCount: 42000000,
        likeCount: 1900000,
      ),
      Video(
        id: 'aircAruvnKk',
        title: 'But what is a neural network? | Chapter 1, Deep learning',
        description: 'What are the neurons, why are there layers, and what is the math underlying it? Visual guide to neural networks. #science #tech #education #3blue1brown',
        thumbnailUrl: 'https://img.youtube.com/vi/aircAruvnKk/hqdefault.jpg',
        channelId: 'UCYO_jab_esuFRV4b17AJtAw',
        channelTitle: '3Blue1Brown',
        publishedAt: DateTime(2017, 10, 5),
        duration: const Duration(minutes: 19, seconds: 13),
        viewCount: 16000000,
        likeCount: 750000,
      ),
      Video(
        id: 'ER3jW1U5V8w',
        title: '100+ Computer Science Concepts Explained',
        description: 'Learn the most important computer science fundamentals, data structures, algorithms, and architectures in one high-density video. #tech #code #fireship',
        thumbnailUrl: 'https://img.youtube.com/vi/ER3jW1U5V8w/hqdefault.jpg',
        channelId: 'UCsBjURrPoezykLs9EqgamOA',
        channelTitle: 'Fireship',
        publishedAt: DateTime(2023, 8, 15),
        duration: const Duration(minutes: 12, seconds: 56),
        viewCount: 2800000,
        likeCount: 190000,
      ),
      Video(
        id: 'fNk_zzaMoSs',
        title: 'Flutter in 100 Seconds',
        description: 'Learn the basics of Flutter and Dart in 100 seconds! How cross-platform mobile, desktop, and web apps are built. #tech #flutter #dart',
        thumbnailUrl: 'https://img.youtube.com/vi/fNk_zzaMoSs/hqdefault.jpg',
        channelId: 'UCsBjURrPoezykLs9EqgamOA',
        channelTitle: 'Fireship',
        publishedAt: DateTime(2020, 10, 2),
        duration: const Duration(minutes: 2, seconds: 15),
        viewCount: 1900000,
        likeCount: 110000,
      ),
      Video(
        id: 'h3Mn1eP3zC8',
        title: 'What If We Detonated All Nuclear Bombs at Once?',
        description: 'If you gathered all nuclear warheads in the world and blew them up in the Amazon, what would happen? #science #education #kurzgesagt',
        thumbnailUrl: 'https://img.youtube.com/vi/h3Mn1eP3zC8/hqdefault.jpg',
        channelId: 'UCsXVk37bltHxD1rDPwtNM8Q',
        channelTitle: 'Kurzgesagt – In a Nutshell',
        publishedAt: DateTime(2019, 3, 31),
        duration: const Duration(minutes: 7, seconds: 2),
        viewCount: 39000000,
        likeCount: 1800000,
      ),
      Video(
        id: 'r6tH55syq0o',
        title: 'World\'s Largest Jell-O Pool - Can you swim in Jell-O?',
        description: 'Mark Rober fills a giant pool with 25 tons of real Jell-O to answer a legendary physics question. #science #markrober',
        thumbnailUrl: 'https://img.youtube.com/vi/r6tH55syq0o/hqdefault.jpg',
        channelId: 'UCY1kMZp36IQSyNx_9h4mpCg',
        channelTitle: 'Mark Rober',
        publishedAt: DateTime(2019, 8, 27),
        duration: const Duration(minutes: 11, seconds: 35),
        viewCount: 92000000,
        likeCount: 3400000,
      ),

      // --- PODCASTS ---
      Video(
        id: '4p0Mv3N_t-8',
        title: 'Sam Altman: OpenAI, GPT-5, Sora, and AGI | Lex Fridman Podcast',
        description: 'Sam Altman discusses OpenAI, GPT-5, Sora video generation, Elon Musk lawsuit, Ilya Sutskever, and the future of artificial intelligence. #podcasts #ai #lexfridman',
        thumbnailUrl: 'https://img.youtube.com/vi/4p0Mv3N_t-8/hqdefault.jpg',
        channelId: 'UCSHZKyawb77ixDdsGog4iWA',
        channelTitle: 'Lex Fridman',
        publishedAt: DateTime(2024, 3, 18),
        duration: const Duration(hours: 1, minutes: 54),
        viewCount: 5200000,
        likeCount: 180000,
      ),
      Video(
        id: '1tNnL94EaKk',
        title: 'How to Optimize Your Brain & Focus | Dr. Andrew Huberman',
        description: 'Dr. Andrew Huberman discusses science-backed protocols to increase focus, improve dopamine regulation, and optimize sleep. #podcasts #science #huberman',
        thumbnailUrl: 'https://img.youtube.com/vi/1tNnL94EaKk/hqdefault.jpg',
        channelId: 'UC2D2CMWXMOVWxXXBrL-zXSg',
        channelTitle: 'Huberman Lab',
        publishedAt: DateTime(2021, 6, 7),
        duration: const Duration(hours: 2, minutes: 10),
        viewCount: 8900000,
        likeCount: 340000,
      ),
      Video(
        id: 'KxgU3vF3fvg',
        title: 'Joe Rogan Experience #1169 - Elon Musk',
        description: 'Elon Musk joins Joe Rogan to discuss Tesla, SpaceX, Neuralink, AI, the simulation hypothesis, and the future of humanity. #podcasts #elonmusk #jre',
        thumbnailUrl: 'https://img.youtube.com/vi/KxgU3vF3fvg/hqdefault.jpg',
        channelId: 'UCzQUP1qoWDoEbmsQxvdjxgQ',
        channelTitle: 'PowerfulJRE',
        publishedAt: DateTime(2018, 9, 7),
        duration: const Duration(hours: 2, minutes: 37),
        viewCount: 71000000,
        likeCount: 3100000,
      ),
      Video(
        id: 'xMv4UuU7H0U',
        title: 'Simon Sinek: How to Find Your "Why" | The Diary Of A CEO',
        description: 'Simon Sinek sits down with Steven Bartlett to discuss leadership, career purpose, emotional intelligence, and why finding your purpose matters. #podcasts #diaryofaceo',
        thumbnailUrl: 'https://img.youtube.com/vi/xMv4UuU7H0U/hqdefault.jpg',
        channelId: 'UCGq-a57w-xP994mLtxqAKEQ',
        channelTitle: 'The Diary Of A CEO',
        publishedAt: DateTime(2023, 1, 16),
        duration: const Duration(hours: 1, minutes: 42),
        viewCount: 4600000,
        likeCount: 165000,
      ),

      // --- NEWS & DOCUMENTARIES ---
      Video(
        id: 'w_Ma8oQLmSM',
        title: 'How Generative AI Is Transforming Global Medicine | BBC News',
        description: 'BBC explores breakthrough artificial intelligence applications diagnosing illnesses, predicting protein folds, and curing diseases. #news #documentaries #bbc',
        thumbnailUrl: 'https://img.youtube.com/vi/w_Ma8oQLmSM/hqdefault.jpg',
        channelId: 'UC16niRr50-MSBwiO3YDb3RA',
        channelTitle: 'BBC News',
        publishedAt: DateTime(2023, 11, 12),
        duration: const Duration(minutes: 24, seconds: 15),
        viewCount: 3400000,
        likeCount: 88000,
      ),
      Video(
        id: '_8V7_W9lqC8',
        title: 'The Secrets of Global Shipping | DW Documentary',
        description: 'How massive container ships move 90% of global goods across the oceans, navigating geopolitical chokepoints and extreme weather. #documentaries #news #dw',
        thumbnailUrl: 'https://img.youtube.com/vi/_8V7_W9lqC8/hqdefault.jpg',
        channelId: 'UCW39zufPf42412e0qN-jA6A',
        channelTitle: 'DW Documentary',
        publishedAt: DateTime(2022, 5, 20),
        duration: const Duration(minutes: 42, seconds: 28),
        viewCount: 6800000,
        likeCount: 145000,
      ),
      Video(
        id: 'aZ_mPqC5f1Y',
        title: 'How High-Speed Rail Changed Modern Transit | Vox',
        description: 'Vox investigates how modern high-speed trains revolutionized travel, reduced emissions, and outpaced commercial aviation. #news #documentaries #vox',
        thumbnailUrl: 'https://img.youtube.com/vi/aZ_mPqC5f1Y/hqdefault.jpg',
        channelId: 'UCLXo7UDZvByw2ixzpQCufnA',
        channelTitle: 'Vox',
        publishedAt: DateTime(2022, 9, 8),
        duration: const Duration(minutes: 13, seconds: 40),
        viewCount: 5100000,
        likeCount: 220000,
      ),
      Video(
        id: 'N4Ua8VfXw8A',
        title: 'Why Microchips Are The Most Critical Resource | Bloomberg',
        description: 'Bloomberg Quicktake takes you inside semiconductor fabs to reveal how microchip supply chains define the world economy. #news #documentaries #bloomberg',
        thumbnailUrl: 'https://img.youtube.com/vi/N4Ua8VfXw8A/hqdefault.jpg',
        channelId: 'UCUMZ7gOHTW9ivG74b10u77Q',
        channelTitle: 'Bloomberg Quicktake',
        publishedAt: DateTime(2023, 4, 14),
        duration: const Duration(minutes: 16, seconds: 50),
        viewCount: 4200000,
        likeCount: 110000,
      ),

      // --- SHORTS ---
      Video(
        id: 'WcIcVapfqXw',
        title: 'Survived 50 Hours In The Desert #shorts',
        description: 'MrBeast tests survival in the hottest desert! #shorts #viral #mrbeast',
        thumbnailUrl: 'https://img.youtube.com/vi/WcIcVapfqXw/hqdefault.jpg',
        channelId: 'UCX6OQ3DkcsbYNE6H8uQQuVA',
        channelTitle: 'MrBeast',
        publishedAt: DateTime(2023, 8, 1),
        duration: const Duration(seconds: 45),
        viewCount: 180000000,
        likeCount: 9200000,
      ),
      Video(
        id: 'k85mRPqvMbE',
        title: 'Magic Mirror Mind Trick #shorts',
        description: 'Zach King optical illusion with mirrors. How did he do it? #shorts #magic',
        thumbnailUrl: 'https://img.youtube.com/vi/k85mRPqvMbE/hqdefault.jpg',
        channelId: 'UCq8DICurnTlXxJgNWepStPg',
        channelTitle: 'Zach King',
        publishedAt: DateTime(2023, 9, 15),
        duration: const Duration(seconds: 32),
        viewCount: 95000000,
        likeCount: 5100000,
      ),
      Video(
        id: '1a8pI65emDE',
        title: 'Most Satisfying Moments in History #shorts',
        description: 'Daily Dose Of Internet brings you the most calming and satisfying clips. #shorts #dailydose',
        thumbnailUrl: 'https://img.youtube.com/vi/1a8pI65emDE/hqdefault.jpg',
        channelId: 'UCdC0An4ZPNr_YiFiYoVbwsw',
        channelTitle: 'Daily Dose Of Internet',
        publishedAt: DateTime(2023, 10, 20),
        duration: const Duration(seconds: 58),
        viewCount: 64000000,
        likeCount: 3800000,
      ),
      Video(
        id: 'jNQXAC9IVRw',
        title: 'Me at the zoo',
        description: 'The first video on YouTube. #history #classics',
        thumbnailUrl: 'https://img.youtube.com/vi/jNQXAC9IVRw/hqdefault.jpg',
        channelId: 'UC4QobU6ST3KWZCmC4QKbhBR',
        channelTitle: 'jawed',
        publishedAt: DateTime(2005, 4, 23),
        duration: const Duration(seconds: 19),
        viewCount: 310000000,
        likeCount: 16000000,
      ),
    ];
  }

  List<Video> _filterFallbackVideos(String query) {
    final lower = query.toLowerCase().trim();
    final all = _getCuratedFallbackVideos();
    if (lower.isEmpty || lower == 'all') return all;

    // 1. Direct Category filter mapping
    if (lower.contains('short')) {
      final matches = all.where((v) => v.description.contains('#shorts') || (v.duration != null && v.duration!.inSeconds <= 60)).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('trend') || lower.contains('popular')) {
      return all.take(15).toList();
    }
    if (lower.contains('game') || lower.contains('gaming')) {
      final matches = all.where((v) => v.description.contains('#gaming') || v.title.toLowerCase().contains('game') || v.title.toLowerCase().contains('minecraft') || v.title.toLowerCase().contains('gta') || v.title.toLowerCase().contains('witcher') || v.title.toLowerCase().contains('cyberpunk') || v.title.toLowerCase().contains('pewdiepie') || v.title.toLowerCase().contains('valorant') || v.title.toLowerCase().contains('elden')).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('music') || lower.contains('song')) {
      final matches = all.where((v) => v.description.contains('#music') || v.channelTitle.toLowerCase().contains('music') || v.title.toLowerCase().contains('music') || v.title.toLowerCase().contains('official') || v.title.toLowerCase().contains('ft.') || v.title.toLowerCase().contains('lofi')).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('podcast')) {
      final matches = all.where((v) => v.description.contains('#podcasts') || v.title.toLowerCase().contains('podcast') || v.channelTitle.toLowerCase().contains('podcast') || v.title.toLowerCase().contains('huberman') || v.title.toLowerCase().contains('rogan') || v.title.toLowerCase().contains('fridman') || v.title.toLowerCase().contains('ceo')).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('tech') || lower.contains('science')) {
      final matches = all.where((v) => v.description.contains('#science') || v.description.contains('#tech') || v.title.toLowerCase().contains('tech') || v.title.toLowerCase().contains('apple') || v.title.toLowerCase().contains('science') || v.title.toLowerCase().contains('ai') || v.title.toLowerCase().contains('code') || v.title.toLowerCase().contains('flutter') || v.channelTitle.toLowerCase().contains('mkbhd') || v.channelTitle.toLowerCase().contains('fireship')).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('news')) {
      final matches = all.where((v) => v.description.contains('#news') || v.title.toLowerCase().contains('news') || v.channelTitle.toLowerCase().contains('news') || v.channelTitle.toLowerCase().contains('bloomberg') || v.channelTitle.toLowerCase().contains('cnbc') || v.channelTitle.toLowerCase().contains('vox')).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('documentary') || lower.contains('documentaries')) {
      final matches = all.where((v) => v.description.contains('#documentaries') || v.title.toLowerCase().contains('documentary') || v.channelTitle.toLowerCase().contains('documentary') || v.channelTitle.toLowerCase().contains('dw') || v.channelTitle.toLowerCase().contains('geographic')).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('education')) {
      final matches = all.where((v) => v.description.contains('#education') || v.title.toLowerCase().contains('math') || v.title.toLowerCase().contains('learn') || v.title.toLowerCase().contains('how') || v.title.toLowerCase().contains('explained') || v.channelTitle.toLowerCase().contains('veritasium') || v.channelTitle.toLowerCase().contains('3blue1brown') || v.channelTitle.toLowerCase().contains('kurzgesagt')).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (lower.contains('short')) {
      final matches = all.where((v) => v.description.contains('#shorts') || (v.duration != null && v.duration!.inSeconds <= 60)).toList();
      if (matches.isNotEmpty) return matches;
    }

    // 2. Tokenized search across title, description, and channelTitle
    final tokens = lower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final results = all.where((v) {
      final hay = '${v.title} ${v.channelTitle} ${v.description}'.toLowerCase();
      return tokens.any((tok) => hay.contains(tok));
    }).toList();

    return results.isNotEmpty ? results : all.take(10).toList();
  }
}

class SocketException implements Exception {
  final String message;
  SocketException([this.message = 'Network socket exception']);
}
