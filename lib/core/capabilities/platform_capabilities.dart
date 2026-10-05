import 'package:flutter/foundation.dart';

enum CapabilityStatus {
  supported,
  unsupported,
  authRequired,
  temporarilyUnavailable,
}

class PlatformCapabilities {
  final bool videoSearch;
  final bool playback;
  final bool channelData;
  final bool offlineWatchLater;
  final bool offlinePlaylists;
  final bool offlineHistory;
  final bool subscriptions;
  final bool comments;
  final bool commentsWrite;
  final bool likes;
  final bool cloudHistory;
  final bool recommendations;
  final bool notifications;
  final bool downloads;
  final bool backgroundPlayback;
  final bool pictureInPicture;

  const PlatformCapabilities({
    this.videoSearch = true,
    this.playback = true,
    this.channelData = true,
    this.offlineWatchLater = true,
    this.offlinePlaylists = true,
    this.offlineHistory = true,
    this.subscriptions = true,
    this.comments = true,
    this.commentsWrite = false,
    this.likes = false,
    this.cloudHistory = false,
    this.recommendations = true,
    this.notifications = false,
    this.downloads = false,
    this.backgroundPlayback = !kIsWeb,
    this.pictureInPicture = !kIsWeb,
  });

  CapabilityStatus getStatus(String feature, {required bool isAuthenticated}) {
    switch (feature) {
      case 'video.search':
      case 'video.details':
      case 'channel.view':
        return CapabilityStatus.supported;
      case 'subscriptions.view':
        return isAuthenticated ? CapabilityStatus.supported : CapabilityStatus.authRequired;
      case 'subscriptions.modify':
      case 'video.like':
        return isAuthenticated ? CapabilityStatus.supported : CapabilityStatus.authRequired;
      case 'comments.view':
        return CapabilityStatus.supported;
      case 'comments.write':
        return isAuthenticated ? CapabilityStatus.supported : CapabilityStatus.authRequired;
      case 'downloads':
        return CapabilityStatus.unsupported;
      case 'history.cloud':
        return isAuthenticated ? CapabilityStatus.supported : CapabilityStatus.authRequired;
      case 'history.local':
      case 'playlists.local':
      case 'watchlater.local':
        return CapabilityStatus.supported;
      default:
        return CapabilityStatus.unsupported;
    }
  }

  String getExplanation(String feature) {
    switch (feature) {
      case 'downloads':
        return 'Offline video downloading is not permitted by official YouTube API terms of service. Local metadata caching is supported.';
      case 'subscriptions.modify':
      case 'video.like':
      case 'comments.write':
        return 'Requires an active Google account sign-in with official YouTube OAuth permissions.';
      case 'history.cloud':
        return 'Local watch history is available without an account. Cloud history requires signing in with Google.';
      default:
        return 'Feature is restricted by platform or API capabilities.';
    }
  }
}
