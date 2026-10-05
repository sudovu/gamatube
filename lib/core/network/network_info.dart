import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../logging/app_logger.dart';

enum NetworkStatus {
  online,
  offline,
  limited,
  connecting,
}

abstract class NetworkInfo {
  Future<bool> get isConnected;
  NetworkStatus get currentStatus;
  Stream<NetworkStatus> get statusStream;
  void dispose();
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;
  final StreamController<NetworkStatus> _controller = StreamController<NetworkStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _status = NetworkStatus.connecting;

  NetworkInfoImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e, st) {
      AppLogger.warning('Failed to check initial connectivity', e, st);
      _status = NetworkStatus.online; // Optimistic fallback
      _controller.add(_status);
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);

    if (hasConnection) {
      _status = NetworkStatus.online;
    } else if (results.contains(ConnectivityResult.none)) {
      _status = NetworkStatus.offline;
    } else {
      _status = NetworkStatus.limited;
    }

    AppLogger.debug('Network status updated: $_status');
    _controller.add(_status);
  }

  @override
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
    } catch (e) {
      return true;
    }
  }

  @override
  NetworkStatus get currentStatus => _status;

  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
