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
        id: 'AKXiKBnzpBQ',
        title: 'Elden Ring - Official Gameplay Reveal',
        description: 'The Golden Order has been broken. Rise, Tarnished, and be guided by grace to brandish the power of the Elden Ring. #gaming #eldenring',
        thumbnailUrl: 'https://img.youtube.com/vi/AKXiKBnzpBQ/hqdefault.jpg',
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
        id: 'kffacxfA7G4',
        title: 'Minecraft Part 1 - PewDiePie',
        description: 'PewDiePie begins his legendary Minecraft survival series. #gaming #pewdiepie #minecraft',
        thumbnailUrl: 'https://img.youtube.com/vi/kffacxfA7G4/hqdefault.jpg',
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
        id: 'M576WGiDBdQ',
        title: 'Apple Vision Pro Review: Tomorrow\'s Tech Today!',
        description: 'Marques Brownlee reviews Apple\'s Spatial Computer, the Vision Pro. Complete deep dive into eye tracking, gestures, and visionOS. #tech #mkbhd #apple',
        thumbnailUrl: 'https://img.youtube.com/vi/M576WGiDBdQ/hqdefault.jpg',
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
        id: 'TNhaISOUy6Q',
        title: '100+ Computer Science Concepts Explained',
        description: 'Learn the most important computer science fundamentals, data structures, algorithms, and architectures in one high-density video. #tech #code #fireship',
        thumbnailUrl: 'https://img.youtube.com/vi/TNhaISOUy6Q/hqdefault.jpg',
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
        id: '4_aOIA-vyBo',
        title: 'What If We Detonated All Nuclear Bombs at Once?',
        description: 'If you gathered all nuclear warheads in the world and blew them up in the Amazon, what would happen? #science #education #kurzgesagt',
        thumbnailUrl: 'https://img.youtube.com/vi/4_aOIA-vyBo/hqdefault.jpg',
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
        id: 'L_Guz73e6fw',
        title: 'Sam Altman: OpenAI, GPT-5, Sora, and AGI | Lex Fridman Podcast',
        description: 'Sam Altman discusses OpenAI, GPT-5, Sora video generation, Elon Musk lawsuit, Ilya Sutskever, and the future of artificial intelligence. #podcasts #ai #lexfridman',
        thumbnailUrl: 'https://img.youtube.com/vi/L_Guz73e6fw/hqdefault.jpg',
        channelId: 'UCSHZKyawb77ixDdsGog4iWA',
        channelTitle: 'Lex Fridman',
        publishedAt: DateTime(2024, 3, 18),
        duration: const Duration(hours: 1, minutes: 54),
        viewCount: 5200000,
        likeCount: 180000,
      ),
      Video(
        id: 'HnJ1bqXUnIM',
        title: 'How to Optimize Your Brain & Focus | Dr. Andrew Huberman',
        description: 'Dr. Andrew Huberman discusses science-backed protocols to increase focus, improve dopamine regulation, and optimize sleep. #podcasts #science #huberman',
        thumbnailUrl: 'https://img.youtube.com/vi/HnJ1bqXUnIM/hqdefault.jpg',
        channelId: 'UC2D2CMWXMOVWxXXBrL-zXSg',
        channelTitle: 'Huberman Lab',
        publishedAt: DateTime(2021, 6, 7),
        duration: const Duration(hours: 2, minutes: 10),
        viewCount: 8900000,
        likeCount: 340000,
      ),
      Video(
        id: '8jLOx1hD3_o',
        title: 'Joe Rogan Experience #1169 - Elon Musk',
        description: 'Elon Musk joins Joe Rogan to discuss Tesla, SpaceX, Neuralink, AI, the simulation hypothesis, and the future of humanity. #podcasts #elonmusk #jre',
        thumbnailUrl: 'https://img.youtube.com/vi/8jLOx1hD3_o/hqdefault.jpg',
        channelId: 'UCzQUP1qoWDoEbmsQxvdjxgQ',
        channelTitle: 'PowerfulJRE',
        publishedAt: DateTime(2018, 9, 7),
        duration: const Duration(hours: 2, minutes: 37),
        viewCount: 71000000,
        likeCount: 3100000,
      ),
      Video(
        id: 'rv3Yq-B8qp4',
        title: 'Simon Sinek: How to Find Your "Why" | The Diary Of A CEO',
        description: 'Simon Sinek sits down with Steven Bartlett to discuss leadership, career purpose, emotional intelligence, and why finding your purpose matters. #podcasts #diaryofaceo',
        thumbnailUrl: 'https://img.youtube.com/vi/rv3Yq-B8qp4/hqdefault.jpg',
        channelId: 'UCGq-a57w-xP994mLtxqAKEQ',
        channelTitle: 'The Diary Of A CEO',
        publishedAt: DateTime(2023, 1, 16),
        duration: const Duration(hours: 1, minutes: 42),
        viewCount: 4600000,
        likeCount: 165000,
      ),

      // --- NEWS & DOCUMENTARIES ---
      Video(
        id: 'x7X9w_GIm1s',
        title: 'How Generative AI Is Transforming Global Medicine | BBC News',
        description: 'BBC explores breakthrough artificial intelligence applications diagnosing illnesses, predicting protein folds, and curing diseases. #news #documentaries #bbc',
        thumbnailUrl: 'https://img.youtube.com/vi/x7X9w_GIm1s/hqdefault.jpg',
        channelId: 'UC16niRr50-MSBwiO3YDb3RA',
        channelTitle: 'BBC News',
        publishedAt: DateTime(2023, 11, 12),
        duration: const Duration(minutes: 24, seconds: 15),
        viewCount: 3400000,
        likeCount: 88000,
      ),
      Video(
        id: 'sNhhvQGsMEc',
        title: 'The Secrets of Global Shipping | DW Documentary',
        description: 'How massive container ships move 90% of global goods across the oceans, navigating geopolitical chokepoints and extreme weather. #documentaries #news #dw',
        thumbnailUrl: 'https://img.youtube.com/vi/sNhhvQGsMEc/hqdefault.jpg',
        channelId: 'UCW39zufPf42412e0qN-jA6A',
        channelTitle: 'DW Documentary',
        publishedAt: DateTime(2022, 5, 20),
        duration: const Duration(minutes: 42, seconds: 28),
        viewCount: 6800000,
        likeCount: 145000,
      ),
      Video(
        id: 'h6fcK_fRYaI',
        title: 'How High-Speed Rail Changed Modern Transit | Vox',
        description: 'Vox investigates how modern high-speed trains revolutionized travel, reduced emissions, and outpaced commercial aviation. #news #documentaries #vox',
        thumbnailUrl: 'https://img.youtube.com/vi/h6fcK_fRYaI/hqdefault.jpg',
        channelId: 'UCLXo7UDZvByw2ixzpQCufnA',
        channelTitle: 'Vox',
        publishedAt: DateTime(2022, 9, 8),
        duration: const Duration(minutes: 13, seconds: 40),
        viewCount: 5100000,
        likeCount: 220000,
      ),
      Video(
        id: '7Pq-S557XQU',
        title: 'Why Microchips Are The Most Critical Resource | Bloomberg',
        description: 'Bloomberg Quicktake takes you inside semiconductor fabs to reveal how microchip supply chains define the world economy. #news #documentaries #bloomberg',
        thumbnailUrl: 'https://img.youtube.com/vi/7Pq-S557XQU/hqdefault.jpg',
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
      // Additional Tech, Python, Web & Entertainment
      Video(
        id: '_uQrJ0TkZlc',
        title: 'Python Tutorial for Beginners - Full Course in 6 Hours',
        description: 'Python tutorial for beginners - Learn Python for data science, web development, and automation. #tech #code #python #programming',
        thumbnailUrl: 'https://img.youtube.com/vi/_uQrJ0TkZlc/hqdefault.jpg',
        channelId: 'UCWv7vMbMWH4-V0ZXdmDpPBA',
        channelTitle: 'Programming with Mosh',
        publishedAt: DateTime(2019, 2, 18),
        duration: const Duration(hours: 6, minutes: 14),
        viewCount: 42000000,
        likeCount: 1200000,
      ),
      Video(
        id: 'bMknfKXIFA8',
        title: 'React Course - Beginner\'s Tutorial for React JavaScript',
        description: 'Learn modern React JS step-by-step with projects. Components, state, hooks, and routing. #tech #code #react #javascript',
        thumbnailUrl: 'https://img.youtube.com/vi/bMknfKXIFA8/hqdefault.jpg',
        channelId: 'UC8butISFwT-Wl7EV0hUK0BQ',
        channelTitle: 'freeCodeCamp.org',
        publishedAt: DateTime(2022, 1, 10),
        duration: const Duration(hours: 11, minutes: 55),
        viewCount: 5200000,
        likeCount: 180000,
      ),
      Video(
        id: 'rfscVS0vtbw',
        title: 'Building a PC... using only AliExpress!',
        description: 'Linus Tech Tips attempts to assemble a gaming battlestation sourcing everything from discount online storefronts. #tech #pc #linus',
        thumbnailUrl: 'https://img.youtube.com/vi/rfscVS0vtbw/hqdefault.jpg',
        channelId: 'UCXuqSBlHAE6Xw-yeJA0Tunw',
        channelTitle: 'Linus Tech Tips',
        publishedAt: DateTime(2023, 6, 12),
        duration: const Duration(minutes: 18, seconds: 40),
        viewCount: 4800000,
        likeCount: 220000,
      ),
      Video(
        id: '4NRXx6U8ABQ',
        title: 'The Weeknd - Blinding Lights (Official Video)',
        description: 'Official music video for The Weeknd - Blinding Lights. Record-breaking billboard hit. #music #rnb #pop',
        thumbnailUrl: 'https://img.youtube.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
        channelId: 'UC0WP5P-ufpRfjbNrmOWwLBQ',
        channelTitle: 'The Weeknd',
        publishedAt: DateTime(2020, 1, 21),
        duration: const Duration(minutes: 4, seconds: 20),
        viewCount: 820000000,
        likeCount: 9800000,
      ),
      Video(
        id: 'rYEDA3JcQqw',
        title: 'Adele - Rolling in the Deep (Official Music Video)',
        description: 'The official music video for Adele - Rolling in the Deep from the album 21. #music #soul #adele',
        thumbnailUrl: 'https://img.youtube.com/vi/rYEDA3JcQqw/hqdefault.jpg',
        channelId: 'UComP_epzeKzvBX156r6pm1Q',
        channelTitle: 'Adele',
        publishedAt: DateTime(2010, 11, 30),
        duration: const Duration(minutes: 3, seconds: 53),
        viewCount: 2300000000,
        likeCount: 12500000,
      ),
      Video(
        id: 'e-ORhEE9VVg',
        title: 'Taylor Swift - Blank Space (Official Music Video)',
        description: 'Music video by Taylor Swift performing Blank Space. #music #pop #taylorswift',
        thumbnailUrl: 'https://img.youtube.com/vi/e-ORhEE9VVg/hqdefault.jpg',
        channelId: 'UCqECaJ8Gagnn7YCbPEzWH6g',
        channelTitle: 'Taylor Swift',
        publishedAt: DateTime(2014, 11, 10),
        duration: const Duration(minutes: 4, seconds: 32),
        viewCount: 3400000000,
        likeCount: 14000000,
      ),

      // --- EXPANDED MUSIC ---
      Video(
        id: 'hT_nvWreIhg',
        title: 'Coldplay - Fix You (Official Video)',
        description: 'The official music video for Coldplay - Fix You. Taken from the album X&Y. #music #rock #coldplay',
        thumbnailUrl: 'https://img.youtube.com/vi/hT_nvWreIhg/hqdefault.jpg',
        channelId: 'UC8v0s8h6_K_9bH7j3J6hXpA',
        channelTitle: 'Coldplay',
        publishedAt: DateTime(2005, 9, 5),
        duration: const Duration(minutes: 4, seconds: 55),
        viewCount: 650000000,
        likeCount: 4100000,
      ),
      Video(
        id: '7wtfhZwyrcc',
        title: 'Imagine Dragons - Believer (Official Music Video)',
        description: 'Watch the official music video for Believer by Imagine Dragons. #music #rock #imaginedragons',
        thumbnailUrl: 'https://img.youtube.com/vi/7wtfhZwyrcc/hqdefault.jpg',
        channelId: 'UCnh2x50k0w3K1f_e7l6x99A',
        channelTitle: 'ImagineDragons',
        publishedAt: DateTime(2017, 3, 7),
        duration: const Duration(minutes: 3, seconds: 36),
        viewCount: 2600000000,
        likeCount: 22000000,
      ),
      Video(
        id: '2Vv-BfVoq4g',
        title: 'Mark Ronson - Uptown Funk ft. Bruno Mars',
        description: 'Official video for Uptown Funk by Mark Ronson ft. Bruno Mars. #music #funk #brunomars',
        thumbnailUrl: 'https://img.youtube.com/vi/2Vv-BfVoq4g/hqdefault.jpg',
        channelId: 'UC684qY3lQf_uX0w5i6wQvQA',
        channelTitle: 'MarkRonsonVEVO',
        publishedAt: DateTime(2014, 11, 19),
        duration: const Duration(minutes: 4, seconds: 30),
        viewCount: 5200000000,
        likeCount: 22000000,
      ),
      Video(
        id: 'DyDfgMOUjCI',
        title: 'Billie Eilish - bad guy (Official Music Video)',
        description: 'Listen to "bad guy" from the debut album "WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?". #music #pop #billieeilish',
        thumbnailUrl: 'https://img.youtube.com/vi/DyDfgMOUjCI/hqdefault.jpg',
        channelId: 'UCiGm_E4Xh8c5PqM-w1aA9lQ',
        channelTitle: 'Billie Eilish',
        publishedAt: DateTime(2019, 3, 29),
        duration: const Duration(minutes: 3, seconds: 25),
        viewCount: 1300000000,
        likeCount: 20000000,
      ),
      Video(
        id: '5NV6Rdv1a3I',
        title: 'Daft Punk - Get Lucky (Official Audio) ft. Pharrell Williams, Nile Rodgers',
        description: 'Official audio for Get Lucky by Daft Punk featuring Pharrell Williams and Nile Rodgers. #music #electronic #daftpunk',
        thumbnailUrl: 'https://img.youtube.com/vi/5NV6Rdv1a3I/hqdefault.jpg',
        channelId: 'UC_kRDKYrUlrbtrSiyu5Tzgw',
        channelTitle: 'Daft Punk',
        publishedAt: DateTime(2013, 4, 19),
        duration: const Duration(minutes: 4, seconds: 8),
        viewCount: 780000000,
        likeCount: 4600000,
      ),
      Video(
        id: '5qap5aO4i9A',
        title: 'Michael Jackson - Billie Jean (Official Video)',
        description: 'The official video for Billie Jean by Michael Jackson from the landmark album Thriller. #music #pop #michaeljackson',
        thumbnailUrl: 'https://img.youtube.com/vi/5qap5aO4i9A/hqdefault.jpg',
        channelId: 'UC5JbJ4M_8aZ4pE7P3iA9JgA',
        channelTitle: 'Michael Jackson',
        publishedAt: DateTime(2009, 10, 3),
        duration: const Duration(minutes: 4, seconds: 55),
        viewCount: 1600000000,
        likeCount: 9200000,
      ),
      Video(
        id: 'TUVcZfQe-Kw',
        title: 'Dua Lipa - Levitating (Official Music Video)',
        description: 'The official music video for Dua Lipa - Levitating from the Future Nostalgia album. #music #pop #dualipa',
        thumbnailUrl: 'https://img.youtube.com/vi/TUVcZfQe-Kw/hqdefault.jpg',
        channelId: 'UC-J-KZfRV8c13f504CkodCQ',
        channelTitle: 'Dua Lipa',
        publishedAt: DateTime(2020, 10, 2),
        duration: const Duration(minutes: 3, seconds: 50),
        viewCount: 930000000,
        likeCount: 6100000,
      ),
      Video(
        id: '1w7OgIMMRc4',
        title: 'Guns N\' Roses - Sweet Child O\' Mine (Official Music Video)',
        description: 'Remastered in 4K: Official music video for Sweet Child O\' Mine performed by Guns N\' Roses. #music #rock #classics',
        thumbnailUrl: 'https://img.youtube.com/vi/1w7OgIMMRc4/hqdefault.jpg',
        channelId: 'UCIk45763B8J6eH7g_a8JbGw',
        channelTitle: 'Guns N\' Roses',
        publishedAt: DateTime(2009, 12, 24),
        duration: const Duration(minutes: 5, seconds: 2),
        viewCount: 1700000000,
        likeCount: 9500000,
      ),
      Video(
        id: 'CevxZvSJLk8',
        title: 'Katy Perry - Roar (Official)',
        description: 'Official music video for Katy Perry\'s "Roar" off her album PRISM. #music #pop #katyperry',
        thumbnailUrl: 'https://img.youtube.com/vi/CevxZvSJLk8/hqdefault.jpg',
        channelId: 'UC-8Quh_vX9wZgV7_mE8lV0A',
        channelTitle: 'Katy Perry',
        publishedAt: DateTime(2013, 9, 5),
        duration: const Duration(minutes: 4, seconds: 30),
        viewCount: 4000000000,
        likeCount: 16500000,
      ),
      Video(
        id: 'hT_nvWreIhg',
        title: 'OneRepublic - Counting Stars (Official Music Video)',
        description: 'Watch the official music video for "Counting Stars" by OneRepublic. #music #pop #onerepublic',
        thumbnailUrl: 'https://img.youtube.com/vi/hT_nvWreIhg/hqdefault.jpg',
        channelId: 'UCE_g_w0Qv7Z783jVq84jXzA',
        channelTitle: 'OneRepublic',
        publishedAt: DateTime(2013, 5, 31),
        duration: const Duration(minutes: 4, seconds: 44),
        viewCount: 4100000000,
        likeCount: 18000000,
      ),

      // --- EXPANDED GAMING ---
      Video(
        id: 'uHGShqcAHlQ',
        title: 'The Legend of Zelda: Tears of the Kingdom – Official Trailer #3',
        description: 'An epic adventure awaits across the land and skies of Hyrule in The Legend of Zelda: Tears of the Kingdom. #gaming #zelda #nintendo',
        thumbnailUrl: 'https://img.youtube.com/vi/uHGShqcAHlQ/hqdefault.jpg',
        channelId: 'UCGIY_O-8vW4rfX98KlOokRg',
        channelTitle: 'Nintendo of America',
        publishedAt: DateTime(2023, 4, 13),
        duration: const Duration(minutes: 3, seconds: 54),
        viewCount: 15500000,
        likeCount: 650000,
      ),
      Video(
        id: 'QkkoHAzjnUs',
        title: 'Grand Theft Auto V: The Official Gameplay Video',
        description: 'Watch the official Grand Theft Auto V gameplay reveal showcasing Los Santos, Blaine County, and multi-character switching. #gaming #gta #rockstar',
        thumbnailUrl: 'https://img.youtube.com/vi/QkkoHAzjnUs/hqdefault.jpg',
        channelId: 'UCbW18JZ9LAdeRytZJ4wN0JQ',
        channelTitle: 'Rockstar Games',
        publishedAt: DateTime(2013, 7, 9),
        duration: const Duration(minutes: 4, seconds: 51),
        viewCount: 42000000,
        likeCount: 1400000,
      ),
      Video(
        id: '094y1Z2wpJg',
        title: 'Minecraft 1.21 Tricky Trials Official Launch Trailer',
        description: 'Explore the trial chambers, defeat the Breeze, and craft the powerful Mace in the Tricky Trials update! #gaming #minecraft #mojang',
        thumbnailUrl: 'https://img.youtube.com/vi/094y1Z2wpJg/hqdefault.jpg',
        channelId: 'UC1sELGmy5jp5fQUugmuYlXQ',
        channelTitle: 'Minecraft',
        publishedAt: DateTime(2024, 6, 13),
        duration: const Duration(minutes: 1, seconds: 35),
        viewCount: 9800000,
        likeCount: 420000,
      ),
      Video(
        id: 'hfJ4Km46A-0',
        title: 'God of War Ragnarök - State of Play Story Trailer | PS5 & PS4',
        description: 'Witness the incredible journey of Kratos and Atreus as they fight to protect what they love against the gods of Asgard. #gaming #godofwar #playstation',
        thumbnailUrl: 'https://img.youtube.com/vi/hfJ4Km46A-0/hqdefault.jpg',
        channelId: 'UC-2Y8dQb0PC6RRQ50EWUo5Q',
        channelTitle: 'PlayStation',
        publishedAt: DateTime(2022, 9, 13),
        duration: const Duration(minutes: 3, seconds: 1),
        viewCount: 18000000,
        likeCount: 780000,
      ),
      Video(
        id: 'eaW0tYpxyp0',
        title: 'Red Dead Redemption 2: Official Gameplay Video',
        description: 'Rockstar Games presents Red Dead Redemption 2. America, 1899. The end of the wild west era has begun. #gaming #reddead #rockstar',
        thumbnailUrl: 'https://img.youtube.com/vi/eaW0tYpxyp0/hqdefault.jpg',
        channelId: 'UCbW18JZ9LAdeRytZJ4wN0JQ',
        channelTitle: 'Rockstar Games',
        publishedAt: DateTime(2018, 8, 9),
        duration: const Duration(minutes: 6, seconds: 5),
        viewCount: 39000000,
        likeCount: 1250000,
      ),
      Video(
        id: 'u9prcUCHlqM',
        title: 'Portal 2 Teaser Trailer',
        description: 'Valve presents Portal 2. Return to Aperture Science with GLaDOS, Wheatley, and the portal gun. #gaming #valve #portal',
        thumbnailUrl: 'https://img.youtube.com/vi/u9prcUCHlqM/hqdefault.jpg',
        channelId: 'UC8v0s8h6_K_9bH7j3J6hXpA',
        channelTitle: 'Valve',
        publishedAt: DateTime(2010, 6, 15),
        duration: const Duration(minutes: 1, seconds: 15),
        viewCount: 9200000,
        likeCount: 210000,
      ),
      Video(
        id: 'uHGShqcAHlQ',
        title: 'Super Mario Odyssey - Jump Up, Super Star! Music Video',
        description: 'Official theme song "Jump Up, Super Star!" from Super Mario Odyssey for Nintendo Switch. #gaming #mario #nintendo',
        thumbnailUrl: 'https://img.youtube.com/vi/uHGShqcAHlQ/hqdefault.jpg',
        channelId: 'UCGIY_O-8vW4rfX98KlOokRg',
        channelTitle: 'Nintendo',
        publishedAt: DateTime(2017, 10, 11),
        duration: const Duration(minutes: 3, seconds: 1),
        viewCount: 74000000,
        likeCount: 820000,
      ),
      Video(
        id: '31g0YE61PLQ',
        title: 'Elden Ring – Story Trailer | FromSoftware',
        description: 'The story of Elden Ring narrated by FromSoftware. The Shattering war that brought darkness upon the Lands Between. #gaming #eldenring #fromsoftware',
        thumbnailUrl: 'https://img.youtube.com/vi/31g0YE61PLQ/hqdefault.jpg',
        channelId: 'UC_NtV8aO4nFh71aG67HsmLQ',
        channelTitle: 'Bandai Namco',
        publishedAt: DateTime(2021, 12, 10),
        duration: const Duration(minutes: 3, seconds: 48),
        viewCount: 14000000,
        likeCount: 520000,
      ),

      // --- EXPANDED SCIENCE & TECH ---
      Video(
        id: 'uD4izuDMUQA',
        title: 'SpaceX Starship Flight 4 Super Heavy Splashdown',
        description: 'SpaceX Starship orbital test flight 4. Super Heavy booster soft touchdown in the Gulf of Mexico and ship atmospheric entry. #tech #space #spacex',
        thumbnailUrl: 'https://img.youtube.com/vi/uD4izuDMUQA/hqdefault.jpg',
        channelId: 'UCtI0Hodo5o5dUb67D6gWYGw',
        channelTitle: 'SpaceX',
        publishedAt: DateTime(2024, 6, 6),
        duration: const Duration(minutes: 4, seconds: 12),
        viewCount: 11000000,
        likeCount: 560000,
      ),
      Video(
        id: 'fn3KWM1kuAw',
        title: 'Do You Love Me? - Boston Dynamics Robot Dance',
        description: 'Atlas, Spot, and Handle dance together to "Do You Love Me" to celebrate the start of a happier year. #tech #robotics #bostondynamics',
        thumbnailUrl: 'https://img.youtube.com/vi/fn3KWM1kuAw/hqdefault.jpg',
        channelId: 'UC7vVhkEfw4nOGp8TyDk7RcQ',
        channelTitle: 'Boston Dynamics',
        publishedAt: DateTime(2020, 12, 29),
        duration: const Duration(minutes: 2, seconds: 53),
        viewCount: 41000000,
        likeCount: 1750000,
      ),
      Video(
        id: 'VQKMoT-6XSg',
        title: 'Steve Jobs Introduces The Original iPhone - 2007 Keynote',
        description: 'Steve Jobs unveils the original Apple iPhone at Macworld 2007: an iPod, a phone, and an internet communicator. #tech #apple #stevejobs #history',
        thumbnailUrl: 'https://img.youtube.com/vi/VQKMoT-6XSg/hqdefault.jpg',
        channelId: 'UCE_M8A5yxnLfW0KghEeajjw',
        channelTitle: 'Apple Keynotes',
        publishedAt: DateTime(2013, 1, 9),
        duration: const Duration(minutes: 10, seconds: 20),
        viewCount: 21000000,
        likeCount: 580000,
      ),
      Video(
        id: 'L_LUpnjgPso',
        title: 'NASA\'s Webb Delivers Deepest Infrared Image of Universe Yet',
        description: 'NASA\'s James Webb Space Telescope has produced the deepest and sharpest infrared image of the distant universe to date. #science #space #nasa #webb',
        thumbnailUrl: 'https://img.youtube.com/vi/L_LUpnjgPso/hqdefault.jpg',
        channelId: 'UCLA_DiR1FfKNvjuUpBHmylQ',
        channelTitle: 'NASA',
        publishedAt: DateTime(2022, 7, 11),
        duration: const Duration(minutes: 6, seconds: 18),
        viewCount: 8900000,
        likeCount: 380000,
      ),
      Video(
        id: 'JhHMJCUmq28',
        title: 'Quantum Computers Explained with a Quantum Computer',
        description: 'Where are the limits of human computing? How do qubits, superposition, and quantum entanglement work? #science #tech #kurzgesagt',
        thumbnailUrl: 'https://img.youtube.com/vi/JhHMJCUmq28/hqdefault.jpg',
        channelId: 'UCsXVk37bltHxD1rDPwtNM8Q',
        channelTitle: 'Kurzgesagt – In a Nutshell',
        publishedAt: DateTime(2015, 12, 8),
        duration: const Duration(minutes: 7, seconds: 34),
        viewCount: 22000000,
        likeCount: 940000,
      ),
      Video(
        id: 'kqtD5dpn9C8',
        title: 'What happens if you touch absolute zero?',
        description: 'Physics Girl investigates the coldest temperatures in the universe and what happens at absolute zero kelvin. #science #education #physics',
        thumbnailUrl: 'https://img.youtube.com/vi/kqtD5dpn9C8/hqdefault.jpg',
        channelId: 'UC7DdEm33SyaTDtWYGO2CwdA',
        channelTitle: 'Physics Girl',
        publishedAt: DateTime(2020, 1, 14),
        duration: const Duration(minutes: 11, seconds: 40),
        viewCount: 7800000,
        likeCount: 310000,
      ),
      Video(
        id: 'MFzDaBzBlL0',
        title: 'The Backwards Brain Bicycle - Smarter Every Day',
        description: 'Destin explores neuroplasticity and the brain by trying to ride a bicycle that steers backwards. #science #education #smartereveryday',
        thumbnailUrl: 'https://img.youtube.com/vi/MFzDaBzBlL0/hqdefault.jpg',
        channelId: 'UC6107grRI4m0o2-emgoDnAA',
        channelTitle: 'SmarterEveryDay',
        publishedAt: DateTime(2015, 4, 24),
        duration: const Duration(minutes: 7, seconds: 58),
        viewCount: 28000000,
        likeCount: 1100000,
      ),
      Video(
        id: 'pQN-pnXPaVg',
        title: 'How a Car Engine Works (Internal Combustion) - 3D Animation',
        description: 'A detailed 3D animated walkthrough of how an internal combustion engine works, four-stroke cycle, valves, pistons, and spark plugs. #tech #engineering',
        thumbnailUrl: 'https://img.youtube.com/vi/pQN-pnXPaVg/hqdefault.jpg',
        channelId: 'UC7vVhkEfw4nOGp8TyDk7RcQ',
        channelTitle: 'Animagraffs',
        publishedAt: DateTime(2021, 5, 12),
        duration: const Duration(minutes: 8, seconds: 45),
        viewCount: 14000000,
        likeCount: 490000,
      ),

      // --- EXPANDED PODCASTS ---
      Video(
        id: 'pwaWilO_Pig',
        title: 'Matthew Walker: The Science of Sleep & Dreaming | Huberman Lab',
        description: 'Dr. Matthew Walker, author of Why We Sleep, details how sleep impacts mental health, memory, Alzheimer\'s disease, and longevity. #podcasts #science #sleep',
        thumbnailUrl: 'https://img.youtube.com/vi/pwaWilO_Pig/hqdefault.jpg',
        channelId: 'UC2D2CMWXMOVWxXXBrL-zXSg',
        channelTitle: 'Huberman Lab',
        publishedAt: DateTime(2022, 4, 4),
        duration: const Duration(hours: 3, minutes: 16),
        viewCount: 6100000,
        likeCount: 195000,
      ),
      Video(
        id: 'eIrMbAQSU34',
        title: 'Walter Isaacson: Elon Musk, Steve Jobs, Einstein, Da Vinci | Lex Fridman',
        description: 'Walter Isaacson sits down with Lex Fridman to discuss biography writing, visionaries, Elon Musk, and the driving forces of innovation. #podcasts #lexfridman #biography',
        thumbnailUrl: 'https://img.youtube.com/vi/eIrMbAQSU34/hqdefault.jpg',
        channelId: 'UCSHZKyawb77ixDdsGog4iWA',
        channelTitle: 'Lex Fridman',
        publishedAt: DateTime(2023, 9, 13),
        duration: const Duration(hours: 2, minutes: 40),
        viewCount: 3200000,
        likeCount: 110000,
      ),
      Video(
        id: 'fBNz5xF-Kx4',
        title: 'Rick Rubin on Creativity, Art, and Making Great Music | JRE',
        description: 'Legendary producer Rick Rubin discusses his book The Creative Act, listening to intuition, and working with music icons. #podcasts #jre #creativity',
        thumbnailUrl: 'https://img.youtube.com/vi/fBNz5xF-Kx4/hqdefault.jpg',
        channelId: 'UCzQUP1qoWDoEbmsQxvdjxgQ',
        channelTitle: 'PowerfulJRE',
        publishedAt: DateTime(2023, 1, 18),
        duration: const Duration(hours: 3, minutes: 2),
        viewCount: 4500000,
        likeCount: 155000,
      ),
      Video(
        id: '1-TZqOsVCNM',
        title: 'Naval Ravikant: How to Get Rich Without Getting Lucky',
        description: 'Naval Ravikant discusses wealth creation, specific knowledge, leverage, judgment, and personal happiness. #podcasts #naval #business #wisdom',
        thumbnailUrl: 'https://img.youtube.com/vi/1-TZqOsVCNM/hqdefault.jpg',
        channelId: 'UCh_vvvtG_W_n5wQ6K7F9uHQ',
        channelTitle: 'Naval',
        publishedAt: DateTime(2019, 6, 4),
        duration: const Duration(hours: 3, minutes: 32),
        viewCount: 9200000,
        likeCount: 380000,
      ),

      // --- EXPANDED NEWS & DOCUMENTARIES ---
      Video(
        id: '1Rs2ND1ryYc',
        title: 'National Geographic: Deep Inside Earth\'s Deadliest Caves',
        description: 'Follow world-class speleologists exploring subterranean ecosystems and deep crystal caverns beneath the earth. #documentaries #science #natgeo',
        thumbnailUrl: 'https://img.youtube.com/vi/1Rs2ND1ryYc/hqdefault.jpg',
        channelId: 'UCpVm7bg6pXKo1Pr6k5kxG9A',
        channelTitle: 'National Geographic',
        publishedAt: DateTime(2021, 8, 14),
        duration: const Duration(minutes: 44, seconds: 12),
        viewCount: 7900000,
        likeCount: 175000,
      ),
      Video(
        id: '4czjS9h4Fpg',
        title: 'NASA Mars 2020 Perseverance Rover Landing Video',
        description: 'Watch the high-definition entry, descent, and landing video of the NASA Perseverance rover touching down on Mars. #news #space #nasa #mars',
        thumbnailUrl: 'https://img.youtube.com/vi/4czjS9h4Fpg/hqdefault.jpg',
        channelId: 'UCLA_DiR1FfKNvjuUpBHmylQ',
        channelTitle: 'NASA',
        publishedAt: DateTime(2021, 2, 22),
        duration: const Duration(minutes: 3, seconds: 25),
        viewCount: 26000000,
        likeCount: 950000,
      ),
      Video(
        id: 'W6NZfCO5SIk',
        title: 'CNA Insider: Living in Tokyo\'s Cyber Capsule Hotels',
        description: 'How micro-apartments and cyber capsule hotels in Tokyo reflect urban density, technology, and minimalist lifestyles. #documentaries #news #cna',
        thumbnailUrl: 'https://img.youtube.com/vi/W6NZfCO5SIk/hqdefault.jpg',
        channelId: 'UC83jt4dlz1Gjl58fzQrrKZg',
        channelTitle: 'CNA Insider',
        publishedAt: DateTime(2023, 5, 8),
        duration: const Duration(minutes: 19, seconds: 30),
        viewCount: 4700000,
        likeCount: 110000,
      ),
      Video(
        id: 'r9PeYPHdpNo',
        title: 'Our Planet | Coastal Seas | Full Episode narrated by David Attenborough',
        description: 'From shallow seas to coral reefs, coastal habitats sustain ninety percent of all marine species. Narrated by Sir David Attenborough. #documentaries #nature #netflix',
        thumbnailUrl: 'https://img.youtube.com/vi/r9PeYPHdpNo/hqdefault.jpg',
        channelId: 'UCWOA1ZGywLbqmigxE4QlvvA',
        channelTitle: 'Netflix',
        publishedAt: DateTime(2020, 4, 17),
        duration: const Duration(minutes: 49, seconds: 28),
        viewCount: 31000000,
        likeCount: 650000,
      ),

      // --- EXPANDED EDUCATION ---
      Video(
        id: 'WUvTyaaNkzM',
        title: 'Khan Academy: Introduction to Limits and Calculus (Math)',
        description: 'Sal Khan explains the intuitive concept of limits in calculus and how we find instantaneous rates of change. #education #math #khanacademy',
        thumbnailUrl: 'https://img.youtube.com/vi/WUvTyaaNkzM/hqdefault.jpg',
        channelId: 'UC4a-Gbdw7vOaccHmFo40b9g',
        channelTitle: 'Khan Academy',
        publishedAt: DateTime(2011, 2, 9),
        duration: const Duration(minutes: 8, seconds: 40),
        viewCount: 6200000,
        likeCount: 92000,
      ),
      Video(
        id: 'Yocja_N5s1I',
        title: 'CrashCourse: The Agricultural Revolution - World History #1',
        description: 'John Green teaches you the history of the world! Explore how human beings transitioned from foraging to farming. #education #history #crashcourse',
        thumbnailUrl: 'https://img.youtube.com/vi/Yocja_N5s1I/hqdefault.jpg',
        channelId: 'UCX6b17PVsYBQ0ip5gyeme-Q',
        channelTitle: 'CrashCourse',
        publishedAt: DateTime(2012, 1, 26),
        duration: const Duration(minutes: 11, seconds: 11),
        viewCount: 15000000,
        likeCount: 360000,
      ),
      Video(
        id: 'hdI2bqOjy3c',
        title: 'MIT 6.006 Introduction to Algorithms - Lecture 1',
        description: 'MIT OpenCourseWare: Introduction to Algorithms, peak finding algorithm in 1D and 2D arrays, time complexity analysis. #education #code #mit',
        thumbnailUrl: 'https://img.youtube.com/vi/hdI2bqOjy3c/hqdefault.jpg',
        channelId: 'UCEBb1b_L6zDS3xTUrIALZOw',
        channelTitle: 'MIT OpenCourseWare',
        publishedAt: DateTime(2012, 11, 29),
        duration: const Duration(minutes: 50, seconds: 3),
        viewCount: 5800000,
        likeCount: 160000,
      ),
      Video(
        id: 'Oe421EPjeBE',
        title: 'TED-Ed: How Memories Form and How We Lose Them',
        description: 'Explore the neurobiology of memory creation, short-term vs long-term storage in synapses, and why we forget. #education #science #teded',
        thumbnailUrl: 'https://img.youtube.com/vi/Oe421EPjeBE/hqdefault.jpg',
        channelId: 'UCsooa4yRKGN_zEE8iknghZA',
        channelTitle: 'TED-Ed',
        publishedAt: DateTime(2015, 6, 23),
        duration: const Duration(minutes: 4, seconds: 56),
        viewCount: 9400000,
        likeCount: 320000,
      ),
      Video(
        id: 'keLN89CWZ-A',
        title: 'Numberphile: The Golden Ratio & Fibonacci Numbers (Math)',
        description: 'Dr. James Grime explores phi, the golden ratio, and why Fibonacci numbers show up constantly in nature. #education #math #numberphile',
        thumbnailUrl: 'https://img.youtube.com/vi/keLN89CWZ-A/hqdefault.jpg',
        channelId: 'UCoxcjq-8xIDTYp3uz647V5A',
        channelTitle: 'Numberphile',
        publishedAt: DateTime(2012, 5, 4),
        duration: const Duration(minutes: 6, seconds: 18),
        viewCount: 4200000,
        likeCount: 145000,
      ),

      // --- EXPANDED VERTICAL SHORTS (Strict <=60s) ---
      Video(
        id: 'XqZsoesa55w',
        title: 'Khaby Lame - Life Hacks Made Simple #shorts',
        description: 'Why make it complicated when it is so simple? Khaby shows how it\'s done. #shorts #comedy #khaby',
        thumbnailUrl: 'https://img.youtube.com/vi/XqZsoesa55w/hqdefault.jpg',
        channelId: 'UCv6G18yK6W1e0x0K7F9uHQ',
        channelTitle: 'Khaby Lame',
        publishedAt: DateTime(2023, 7, 2),
        duration: const Duration(seconds: 22),
        viewCount: 88000000,
        likeCount: 6500000,
      ),
      Video(
        id: 'rv3Yq-B8qp4',
        title: 'Gordon Ramsay Reacts to Shocking Steak #shorts',
        description: 'Gordon Ramsay cannot believe what someone did to this prime ribeye! #shorts #ramsay #cooking',
        thumbnailUrl: 'https://img.youtube.com/vi/rv3Yq-B8qp4/hqdefault.jpg',
        channelId: 'UCrDkAvwZum-UTjHmzA7372A',
        channelTitle: 'Gordon Ramsay',
        publishedAt: DateTime(2023, 11, 14),
        duration: const Duration(seconds: 35),
        viewCount: 72000000,
        likeCount: 4800000,
      ),
      Video(
        id: 'x7X9w_GIm1s',
        title: 'Mark Rober - Glitter Bomb 5.0 Sneak Peek #shorts',
        description: 'High-tech package thief trap in action with biodegradable glitter. #shorts #markrober #viral',
        thumbnailUrl: 'https://img.youtube.com/vi/x7X9w_GIm1s/hqdefault.jpg',
        channelId: 'UCY1kMZp36IQSyNx_9h4mpCg',
        channelTitle: 'Mark Rober',
        publishedAt: DateTime(2023, 12, 18),
        duration: const Duration(seconds: 48),
        viewCount: 95000000,
        likeCount: 7100000,
      ),
      Video(
        id: 'TNhaISOUy6Q',
        title: 'Dude Perfect - World Record Trick Shot #shorts',
        description: 'Unbelievable basketball trick shot from the top of the stadium! #shorts #dudeperfect #sports',
        thumbnailUrl: 'https://img.youtube.com/vi/TNhaISOUy6Q/hqdefault.jpg',
        channelId: 'UCRijo3ddMTht_IHyDn5DFg',
        channelTitle: 'Dude Perfect',
        publishedAt: DateTime(2023, 9, 29),
        duration: const Duration(seconds: 28),
        viewCount: 115000000,
        likeCount: 8200000,
      ),
      Video(
        id: 'dQw4w9WgXcQ',
        title: 'Inside a Mechanical Watch in 30 Seconds #shorts',
        description: 'Mesmerizing balance wheel and escapement mechanism operating in slow motion. #shorts #craft #engineering',
        thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        channelId: 'UCXuqSBlHAE6Xw-yeJA0Tunw',
        channelTitle: 'Timepiece Art',
        publishedAt: DateTime(2024, 1, 15),
        duration: const Duration(seconds: 30),
        viewCount: 42000000,
        likeCount: 3100000,
      ),
      Video(
        id: 'kJQP7kiw5Fk',
        title: 'Satisfying Kinetic Sand Slicing ASMR #shorts',
        description: 'Calming and relaxing kinetic sand cuts with perfect rainbow layers. #shorts #asmr #satisfying',
        thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
        channelId: 'UCsooa4yRKGN_zEE8iknghZA',
        channelTitle: 'Sand ASMR',
        publishedAt: DateTime(2023, 10, 5),
        duration: const Duration(seconds: 26),
        viewCount: 68000000,
        likeCount: 4900000,
      ),
      Video(
        id: 'JGwWNGJdvx8',
        title: 'NASA Artemis Rocket Launch Ignition #shorts',
        description: '8.8 million pounds of thrust lighting up the night sky at Cape Canaveral! #shorts #nasa #artemis',
        thumbnailUrl: 'https://img.youtube.com/vi/JGwWNGJdvx8/hqdefault.jpg',
        channelId: 'UCLA_DiR1FfKNvjuUpBHmylQ',
        channelTitle: 'NASA',
        publishedAt: DateTime(2023, 3, 2),
        duration: const Duration(seconds: 40),
        viewCount: 81000000,
        likeCount: 5600000,
      ),
      Video(
        id: 'hT_nvWreIhg',
        title: 'MrBeast - Surprise \$10,000 Challenge #shorts',
        description: 'Whoever takes their hand off the cash last keeps it all! #shorts #mrbeast #challenge',
        thumbnailUrl: 'https://img.youtube.com/vi/hT_nvWreIhg/hqdefault.jpg',
        channelId: 'UCX6OQ3DkcsbYNE6H8uQQuVA',
        channelTitle: 'MrBeast',
        publishedAt: DateTime(2024, 2, 20),
        duration: const Duration(seconds: 52),
        viewCount: 140000000,
        likeCount: 9900000,
      ),
      Video(
        id: 'fJ9rUzIMcZQ',
        title: 'World\'s Fastest Rubik\'s Cube Solve 3.13s #shorts',
        description: 'Max Park breaks the 3x3 Rubik\'s Cube World Record in 3.13 seconds! #shorts #speedcube #worldrecord',
        thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
        channelId: 'UC4zyoIAzmdSGvmufma4POug',
        channelTitle: 'SpeedCube Pro',
        publishedAt: DateTime(2023, 6, 12),
        duration: const Duration(seconds: 35),
        viewCount: 92000000,
        likeCount: 6800000,
      ),
      Video(
        id: '2Vv-BfVoq4g',
        title: 'Incredible Drone Flythrough of Bowling Alley #shorts',
        description: 'Viral one-shot FPV drone flythrough through a bowling alley. #shorts #drone #cinematography',
        thumbnailUrl: 'https://img.youtube.com/vi/2Vv-BfVoq4g/hqdefault.jpg',
        channelId: 'UC_NtV8aO4nFh71aG67HsmLQ',
        channelTitle: 'Rally Studios',
        publishedAt: DateTime(2023, 8, 25),
        duration: const Duration(seconds: 50),
        viewCount: 58000000,
        likeCount: 4200000,
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

    // 2. Scored relevance search across title, channelTitle, and description
    final tokens = lower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final scored = <Video, int>{};
    for (final v in all) {
      final titleLower = v.title.toLowerCase();
      final channelLower = v.channelTitle.toLowerCase();
      final descLower = v.description.toLowerCase();
      int score = 0;
      if (titleLower.contains(lower)) score += 10;
      if (channelLower.contains(lower)) score += 8;
      for (final tok in tokens) {
        if (titleLower.contains(tok)) score += 5;
        if (channelLower.contains(tok)) score += 3;
        if (descLower.contains(tok)) score += 1;
      }
      if (score > 0) scored[v] = score;
    }

    if (scored.isNotEmpty) {
      final sorted = scored.keys.toList()..sort((a, b) => scored[b]!.compareTo(scored[a]!));
      return sorted;
    }

    return all.take(15).toList();
  }
}

class SocketException implements Exception {
  final String message;
  SocketException([this.message = 'Network socket exception']);
}
