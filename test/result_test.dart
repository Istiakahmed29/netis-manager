import 'package:flutter_test/flutter_test.dart';
import 'package:netis_manager/core/errors/app_error.dart';
import 'package:netis_manager/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Success.isSuccess is true', () {
      const result = Success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('Failure.isFailure is true', () {
      final result = Failure<int>(const RouterNotFoundError());
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('Success.valueOrThrow returns value', () {
      const result = Success('hello');
      expect(result.valueOrThrow, equals('hello'));
    });

    test('Failure.valueOrThrow throws the error', () {
      final result = Failure<String>(const AuthenticationError());
      expect(() => result.valueOrThrow, throwsA(isA<AuthenticationError>()));
    });

    test('fold calls onSuccess for Success', () {
      const result = Success(10);
      final out = result.fold(
        onSuccess: (v) => 'got $v',
        onFailure: (_) => 'error',
      );
      expect(out, equals('got 10'));
    });

    test('fold calls onFailure for Failure', () {
      final result = Failure<int>(const AuthenticationError());
      final out = result.fold(
        onSuccess: (v) => 'ok',
        onFailure: (e) => e.message,
      );
      expect(out, equals('Incorrect username or password.'));
    });
  });
}
