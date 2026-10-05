import 'package:flutter_test/flutter_test.dart';
import 'package:gamatube/models/video.dart';
import 'package:gamatube/models/app_settings.dart';
import 'package:gamatube/models/playlist.dart';

void main() {
  group('Video Model Tests', () {
    test('formattedViews formats thousands, millions, and billions correctly', () {
      const v1 = Video(
        id: '1',
        title: 'Test 1',
        description: 'Desc',
        thumbnailUrl: '',
        channelId: 'c1',
        channelTitle: 'C1',
        viewCount: 1540000000,
      );
      expect(v1.formattedViews, '1.5B views');

      const v2 = Video(
        id: '2',
        title: 'Test 2',
        description: 'Desc',
        thumbnailUrl: '',
        channelId: 'c2',
        channelTitle: 'C2',
        viewCount: 2400000,
      );
      expect(v2.formattedViews, '2.4M views');

      const v3 = Video(
        id: '3',
        title: 'Test 3',
        description: 'Desc',
        thumbnailUrl: '',
        channelId: 'c3',
        channelTitle: 'C3',
        viewCount: 4200,
      );
      expect(v3.formattedViews, '4.2K views');
    });

    test('formattedDuration handles minutes and hours properly', () {
      const v = Video(
        id: '1',
        title: 'Test',
        description: 'Desc',
        thumbnailUrl: '',
        channelId: 'c',
        channelTitle: 'C',
        duration: Duration(hours: 1, minutes: 12, seconds: 45),
      );
      expect(v.formattedDuration, '1:12:45');

      const vShort = Video(
        id: '2',
        title: 'Short',
        description: 'Desc',
        thumbnailUrl: '',
        channelId: 'c',
        channelTitle: 'C',
        duration: Duration(minutes: 3, seconds: 22),
      );
      expect(vShort.formattedDuration, '3:22');
    });

    test('Video toJson and fromJson symmetry', () {
      final now = DateTime.now();
      final video = Video(
        id: 'vid123',
        title: 'JSON Test',
        description: 'Testing serialization',
        thumbnailUrl: 'https://img.youtube.com/vi/vid123/default.jpg',
        channelId: 'chan456',
        channelTitle: 'Test Channel',
        publishedAt: now,
        duration: const Duration(minutes: 5),
        viewCount: 10000,
      );

      final json = video.toJson();
      final reconstructed = Video.fromJson(json);

      expect(reconstructed.id, video.id);
      expect(reconstructed.title, video.title);
      expect(reconstructed.channelTitle, video.channelTitle);
      expect(reconstructed.viewCount, video.viewCount);
    });
  });

  group('AppSettings Tests', () {
    test('Default values are correct and safe', () {
      const settings = AppSettings();
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.maxCacheSizeMb, 250);
      expect(settings.analyticsOptIn, false);
      expect(settings.crashReportingOptIn, false);
      expect(settings.historyPaused, false);
    });

    test('Serialization round-trip preserves custom values', () {
      const settings = AppSettings(
        themeMode: AppThemeMode.amoled,
        highContrast: true,
        maxCacheSizeMb: 500,
        analyticsOptIn: true,
      );
      final json = settings.toJson();
      final fromJson = AppSettings.fromJson(json);
      expect(fromJson.themeMode, AppThemeMode.amoled);
      expect(fromJson.highContrast, true);
      expect(fromJson.maxCacheSizeMb, 500);
      expect(fromJson.analyticsOptIn, true);
    });
  });

  group('Playlist Tests', () {
    test('Playlist creation and items management', () {
      final p = Playlist(
        id: 'pl1',
        title: 'Favorites',
        createdAt: DateTime.now(),
        items: [],
      );
      expect(p.isLocal, true);
      expect(p.videoCount, 0);

      const vid = Video(
        id: 'v1',
        title: 'Video 1',
        description: '',
        thumbnailUrl: '',
        channelId: 'c1',
        channelTitle: 'C1',
      );
      final updated = p.copyWith(items: [vid], videoCount: 1);
      expect(updated.items.length, 1);
      expect(updated.videoCount, 1);
    });
  });
}
