import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Represents the network connection status.
enum NetworkStatus {
  /// The device has a network connection (WiFi, Mobile, Ethernet, etc.).
  online,

  /// The device has no network connection.
  offline,
}

/// Interface for monitoring network connectivity.
abstract class NetworkInfo {
  /// returns true if the device is currently connected to a network.
  ///
  /// This defaults to `true` on initialization to avoid false positives
  /// until the actual status is determined.
  bool get isConnected;

  /// Stream of network status changes.
  Stream<NetworkStatus> get onStatusChange;
}

/// Implementation of [NetworkInfo] using [Connectivity].
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  // defaulting to online as per spec to avoid false positives on startup
  bool _isConnected = true;
  final _controller = StreamController<NetworkStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkInfoImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  void _init() {
    // Listen to changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);

    // Initial check (fire and forget, update status when ready)
    _connectivity.checkConnectivity().then(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If any result is not none, we are connected.
    // connectivity_plus returns [ConnectivityResult.none] if disconnected.
    // It returns a list of active connections.
    final bool newState = results.any((r) => r != ConnectivityResult.none);

    if (_isConnected != newState) {
      _isConnected = newState;
      _controller.add(newState ? NetworkStatus.online : NetworkStatus.offline);
    }
  }

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<NetworkStatus> get onStatusChange => _controller.stream;

  /// Disposes resources.
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
