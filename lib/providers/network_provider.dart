import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/network_info.dart';

class NetworkProvider extends ChangeNotifier {
  final NetworkInfo _networkInfo;
  NetworkStatus _status = NetworkStatus.connecting;
  StreamSubscription<NetworkStatus>? _subscription;

  NetworkProvider({required this._networkInfo}) {
    _status = _networkInfo.currentStatus;
    _subscription = _networkInfo.statusStream.listen((newStatus) {
      if (_status != newStatus) {
        _status = newStatus;
        notifyListeners();
      }
    });
  }

  NetworkStatus get status => _status;
  bool get isOnline => _status == NetworkStatus.online;
  bool get isOffline => _status == NetworkStatus.offline;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
