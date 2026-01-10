import 'package:dart_acdc/src/network_info/network_info.dart';
import 'package:dio/dio.dart';

/// Extensions for accessing [NetworkInfo] from a [Dio] client instance.
extension AcdcClientExtensions on Dio {
  /// Retrieves the [NetworkInfo] associated with this client.
  ///
  /// Returns `null` if the client was not configured with offline detection support
  /// (though `AcdcClientBuilder` adds it by default).
  NetworkInfo? get networkInfo {
    return options.extra['_acdc_network_info'] as NetworkInfo?;
  }

  /// Closes the client and disposes associated resources including [NetworkInfo].
  ///
  /// This is a convenience method to properly clean up resources that [Dio.close]
  /// doesn't know about, such as the network monitoring stream.
  void closeAcdc({bool force = false}) {
    close(force: force);
    networkInfo?.dispose();
  }
}
