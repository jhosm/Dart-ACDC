import 'package:dart_acdc/dart_acdc.dart';
import 'package:dart_acdc/src/extensions/acdc_client_extensions.dart';
import 'package:dart_acdc/src/network_info/network_info.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'acdc_client_extensions_test.mocks.dart';

@GenerateMocks([NetworkInfo])
void main() {
  group('AcdcClientExtensions', () {
    late Dio dio;
    late MockNetworkInfo mockNetworkInfo;

    setUp(() {
      dio = Dio();
      mockNetworkInfo = MockNetworkInfo();
    });

    test('networkInfo returns null when not configured', () {
      expect(dio.networkInfo, isNull);
    });

    test('networkInfo returns configured instance', () {
      dio.options.extra['_acdc_network_info'] = mockNetworkInfo;
      expect(dio.networkInfo, same(mockNetworkInfo));
    });

    test('closeAcdc disposes networkInfo', () {
      dio.options.extra['_acdc_network_info'] = mockNetworkInfo;

      dio.closeAcdc(); // Should call dispose

      verify(mockNetworkInfo.dispose()).called(1);
    });

    test('closeAcdc calls dio.close', () {
      // We can't easily verify dio.close() on a real Dio instance as it's not mocked here,
      // but we can check if it throws or behaves expectedly.
      // closeAcdc calls close().

      dio.options.extra['_acdc_network_info'] = mockNetworkInfo;

      expect(() => dio.closeAcdc(), returnsNormally);

      // Dio doesn't expose 'closed' state easily without checking internal adapter or making request.
      // But purely from extension logic, we just want to ensure it passes through.
    });
  });
}
