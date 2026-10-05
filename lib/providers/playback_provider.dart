import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../repositories/history_repository.dart';
import '../repositories/settings_repository.dart';

class PlaybackProvider extends ChangeNotifier {
  final HistoryRepository _historyRepository;
  final SettingsRepository _settingsRepository;

  Video? _currentVideo;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _captionsEnabled = false;
  String _currentQuality = 'Auto';
  Duration? _savedResumePosition;
  Timer? _positionSaveTimer;

  PlaybackProvider({
    required this._historyRepository,
    required this._settingsRepository,
  });

  Video? get currentVideo => _currentVideo;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get playbackSpeed => _playbackSpeed;
  bool get isMuted => _isMuted;
  bool get isFullscreen => _isFullscreen;
  bool get captionsEnabled => _captionsEnabled;
  String get currentQuality => _currentQuality;
  Duration? get savedResumePosition => _savedResumePosition;

  Future<void> loadVideo(Video video) async {
    _currentVideo = video;
    _currentPosition = Duration.zero;
    _totalDuration = video.duration ?? const Duration(minutes: 5);
    _isPlaying = true;
    _savedResumePosition = null;

    // Check for saved resume position
    final item = await _historyRepository.getHistoryItem(video.id);
    if (item != null && item.position.inSeconds > 5 && item.completionPercentage < 0.95) {
      _savedResumePosition = item.position;
    }

    notifyListeners();

    // Start periodic position recorder
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentPosition();
    });
  }

  void updatePosition(Duration position, [Duration? duration]) {
    _currentPosition = position;
    if (duration != null && duration.inSeconds > 0) {
      _totalDuration = duration;
    }
    notifyListeners();
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void seekTo(Duration position) {
    _currentPosition = position;
    notifyListeners();
    _saveCurrentPosition();
  }

  void seekForward([int seconds = 10]) {
    final next = _currentPosition + Duration(seconds: seconds);
    seekTo(next > _totalDuration ? _totalDuration : next);
  }

  void seekRewind([int seconds = 10]) {
    final prev = _currentPosition - Duration(seconds: seconds);
    seekTo(prev < Duration.zero ? Duration.zero : prev);
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    notifyListeners();
  }

  void toggleCaptions() {
    _captionsEnabled = !_captionsEnabled;
    notifyListeners();
  }

  void setQuality(String quality) {
    _currentQuality = quality;
    notifyListeners();
  }

  void clearResumePrompt() {
    _savedResumePosition = null;
    notifyListeners();
  }

  Future<void> _saveCurrentPosition() async {
    if (_currentVideo == null) return;
    final settings = await _settingsRepository.getSettings();
    if (settings.historyPaused) return;

    if (_currentPosition.inSeconds > 2) {
      await _historyRepository.addToHistory(
        _currentVideo!,
        _currentPosition,
        _totalDuration,
      );
    }
  }

  @override
  void dispose() {
    _positionSaveTimer?.cancel();
    super.dispose();
  }
}
