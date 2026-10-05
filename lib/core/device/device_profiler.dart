import 'package:flutter/foundation.dart';

enum BandwidthMode {
  dataSaver,
  normal,
  highQuality,
}

class DeviceProfiler {
  final bool isLowEnd;
  final BandwidthMode bandwidthMode;
  final bool reduceAnimations;
  final int maxConcurrentRequests;

  const DeviceProfiler({
    this.isLowEnd = false,
    this.bandwidthMode = BandwidthMode.normal,
    this.reduceAnimations = false,
    this.maxConcurrentRequests = 4,
  });

  /// Factory that adapts parameters based on platform and user configuration
  factory DeviceProfiler.detect({
    bool forceLowEnd = false,
    BandwidthMode userBandwidth = BandwidthMode.normal,
  }) {
    // Web and older mobile targets adapt conservatively
    final isLow = forceLowEnd || (kIsWeb && false);
    return DeviceProfiler(
      isLowEnd: isLow,
      bandwidthMode: isLow ? BandwidthMode.dataSaver : userBandwidth,
      reduceAnimations: isLow,
      maxConcurrentRequests: isLow ? 2 : 4,
    );
  }

  /// Choose appropriate thumbnail resolution based on bandwidth and device profile
  String selectThumbnailUrl({
    required String? high,
    required String? medium,
    required String? standard,
    required String? fallback,
  }) {
    if (bandwidthMode == BandwidthMode.dataSaver || isLowEnd) {
      return standard ?? medium ?? fallback ?? '';
    }
    if (bandwidthMode == BandwidthMode.highQuality) {
      return high ?? standard ?? medium ?? fallback ?? '';
    }
    return medium ?? standard ?? high ?? fallback ?? '';
  }
}
