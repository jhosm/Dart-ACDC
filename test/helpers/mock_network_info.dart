import 'dart:async';
import 'package:dart_acdc/src/network_info/network_info.dart';

class MockNetworkInfo implements NetworkInfo {
  bool _disposed = false;

  @override
  bool get isConnected => true;

  @override
  Stream<NetworkStatus> get onStatusChange => const Stream.empty();

  @override
  void dispose() {
    _disposed = true;
  }

  bool get isDisposed => _disposed;
}
