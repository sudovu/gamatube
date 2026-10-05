import 'package:flutter_test/flutter_test.dart';
import 'package:gamatube/core/capabilities/platform_capabilities.dart';

void main() {
  group('PlatformCapabilities Tests', () {
    test('Default capabilities reflect privacy and API compliance', () {
      const caps = PlatformCapabilities();

      expect(caps.videoSearch, true);
      expect(caps.playback, true);
      expect(caps.channelData, true);
      expect(caps.offlineWatchLater, true);
      expect(caps.offlinePlaylists, true);
      expect(caps.downloads, false); // Compliance: no unauthorized downloading
    });

    test('Capability status distinguishes authenticated and public endpoints', () {
      const caps = PlatformCapabilities();

      expect(caps.getStatus('video.search', isAuthenticated: false), CapabilityStatus.supported);
      expect(caps.getStatus('subscriptions.view', isAuthenticated: false), CapabilityStatus.authRequired);
      expect(caps.getStatus('subscriptions.view', isAuthenticated: true), CapabilityStatus.supported);
      expect(caps.getStatus('downloads', isAuthenticated: true), CapabilityStatus.unsupported);
    });

    test('Provides clear user-facing explanations for restrictions', () {
      const caps = PlatformCapabilities();
      final explanation = caps.getExplanation('downloads');
      expect(explanation, contains('not permitted by official YouTube API terms'));
    });
  });
}
