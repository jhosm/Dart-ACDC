import 'package:dart_acdc/src/exceptions/acdc_auth_exception.dart';
import 'package:dart_acdc/src/exceptions/acdc_exception.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcException Equality', () {
    test('Exceptions with same properties are equal', () {
      final requestOptions = RequestOptions(path: '/test');

      final e1 = AcdcException(
        requestOptions: requestOptions,
        message: 'Error message',
        statusCode: 400,
        requestUrl: 'https://api.example.com/test',
        responseData: {'error': 'bad request'},
      );

      final e2 = AcdcException(
        requestOptions: requestOptions,
        message: 'Error message',
        statusCode: 400,
        requestUrl: 'https://api.example.com/test',
        responseData: {'error': 'bad request'},
      );

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
    });

    test('Exceptions with different properties are not equal', () {
      final requestOptions = RequestOptions(path: '/test');

      final e1 = AcdcException(
        requestOptions: requestOptions,
        message: 'Error 1',
      );

      final e2 = AcdcException(
        requestOptions: requestOptions,
        message: 'Error 2',
      );

      expect(e1, isNot(equals(e2)));
    });

    test('Different exception types are not equal even with same message', () {
      final requestOptions = RequestOptions(path: '/test');

      final e1 = AcdcException(
        requestOptions: requestOptions,
        message: 'Auth error',
      );

      final e2 = AcdcAuthException(
        requestOptions: requestOptions,
        message: 'Auth error',
      );

      expect(e1, isNot(equals(e2)));
    });

    test('Complex responseData equality works via toString', () {
      final requestOptions = RequestOptions(path: '/test');

      final e1 = AcdcException(
        requestOptions: requestOptions,
        message: 'Error',
        responseData: {'key': 'value'},
      );

      final e2 = AcdcException(
        requestOptions: requestOptions,
        message: 'Error',
        responseData: {'key': 'value'},
      );

      expect(e1, equals(e2));
    });
  });
}
