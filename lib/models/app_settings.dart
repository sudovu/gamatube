import 'package:flutter/material.dart';
import '../core/device/device_profiler.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  amoled,
}

class AppSettings {
  final AppThemeMode themeMode;
  final bool highContrast;
  final bool reduceMotion;
  final BandwidthMode bandwidthMode;
  final bool forceLowEndMode;
  final bool autoplay;
  final double playbackSpeed;
  final String defaultQuality;
  final bool enableCaptions;
  final int maxCacheSizeMb;
  final bool historyPaused;
  final bool analyticsOptIn;
  final bool crashReportingOptIn;
  final bool notificationsEnabled;
  final String? customApiKey;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.highContrast = false,
    this.reduceMotion = false,
    this.bandwidthMode = BandwidthMode.normal,
    this.forceLowEndMode = false,
    this.autoplay = true,
    this.playbackSpeed = 1.0,
    this.defaultQuality = 'Auto',
    this.enableCaptions = false,
    this.maxCacheSizeMb = 250,
    this.historyPaused = false,
    this.analyticsOptIn = false,
    this.crashReportingOptIn = false,
    this.notificationsEnabled = false,
    this.customApiKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'highContrast': highContrast,
      'reduceMotion': reduceMotion,
      'bandwidthMode': bandwidthMode.name,
      'forceLowEndMode': forceLowEndMode,
      'autoplay': autoplay,
      'playbackSpeed': playbackSpeed,
      'defaultQuality': defaultQuality,
      'enableCaptions': enableCaptions,
      'maxCacheSizeMb': maxCacheSizeMb,
      'historyPaused': historyPaused,
      'analyticsOptIn': analyticsOptIn,
      'crashReportingOptIn': crashReportingOptIn,
      'notificationsEnabled': notificationsEnabled,
      'customApiKey': customApiKey,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    AppThemeMode parseTheme(String? val) {
      return AppThemeMode.values.firstWhere(
        (e) => e.name == val,
        orElse: () => AppThemeMode.system,
      );
    }

    BandwidthMode parseBandwidth(String? val) {
      return BandwidthMode.values.firstWhere(
        (e) => e.name == val,
        orElse: () => BandwidthMode.normal,
      );
    }

    return AppSettings(
      themeMode: parseTheme(json['themeMode'] as String?),
      highContrast: json['highContrast'] as bool? ?? false,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      bandwidthMode: parseBandwidth(json['bandwidthMode'] as String?),
      forceLowEndMode: json['forceLowEndMode'] as bool? ?? false,
      autoplay: json['autoplay'] as bool? ?? true,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultQuality: json['defaultQuality'] as String? ?? 'Auto',
      enableCaptions: json['enableCaptions'] as bool? ?? false,
      maxCacheSizeMb: json['maxCacheSizeMb'] as int? ?? 250,
      historyPaused: json['historyPaused'] as bool? ?? false,
      analyticsOptIn: json['analyticsOptIn'] as bool? ?? false,
      crashReportingOptIn: json['crashReportingOptIn'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      customApiKey: json['customApiKey'] as String?,
    );
  }

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? highContrast,
    bool? reduceMotion,
    BandwidthMode? bandwidthMode,
    bool? forceLowEndMode,
    bool? autoplay,
    double? playbackSpeed,
    String? defaultQuality,
    bool? enableCaptions,
    int? maxCacheSizeMb,
    bool? historyPaused,
    bool? analyticsOptIn,
    bool? crashReportingOptIn,
    bool? notificationsEnabled,
    String? customApiKey,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      bandwidthMode: bandwidthMode ?? this.bandwidthMode,
      forceLowEndMode: forceLowEndMode ?? this.forceLowEndMode,
      autoplay: autoplay ?? this.autoplay,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      enableCaptions: enableCaptions ?? this.enableCaptions,
      maxCacheSizeMb: maxCacheSizeMb ?? this.maxCacheSizeMb,
      historyPaused: historyPaused ?? this.historyPaused,
      analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
      crashReportingOptIn: crashReportingOptIn ?? this.crashReportingOptIn,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      customApiKey: customApiKey ?? this.customApiKey,
    );
  }
}
