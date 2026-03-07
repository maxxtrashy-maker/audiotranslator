import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:audiotranslator/core/errors/failures.dart';
import 'package:audiotranslator/core/utils/retry_helper.dart';

void main() {
  group('RetryHelper.retryOperation', () {
    test('returns Right on immediate success', () async {
      final result = await RetryHelper.retryOperation(
        () async => const Right('ok'),
      );

      expect(result, isA<Right>());
      result.fold((_) => fail('should be Right'), (v) => expect(v, 'ok'));
    });

    test('does not retry QuotaExceededFailure', () async {
      var calls = 0;
      final result = await RetryHelper.retryOperation(() async {
        calls++;
        return const Left(QuotaExceededFailure('quota'));
      });

      expect(result, isA<Left>());
      expect(calls, 1);
    });

    test('does not retry TimeoutFailure', () async {
      var calls = 0;
      final result = await RetryHelper.retryOperation(() async {
        calls++;
        return const Left(TimeoutFailure('timeout'));
      });

      expect(result, isA<Left>());
      expect(calls, 1);
    });

    test('does not retry FileTooLargeFailure', () async {
      var calls = 0;
      final result = await RetryHelper.retryOperation(() async {
        calls++;
        return const Left(FileTooLargeFailure('too large'));
      });

      expect(result, isA<Left>());
      expect(calls, 1);
    });

    test('does not retry InvalidFormatFailure', () async {
      var calls = 0;
      final result = await RetryHelper.retryOperation(() async {
        calls++;
        return const Left(InvalidFormatFailure('invalid'));
      });

      expect(result, isA<Left>());
      expect(calls, 1);
    });

    test('retries ServerFailure and succeeds on 2nd attempt', () async {
      var calls = 0;
      final result = await RetryHelper.retryOperation(() async {
        calls++;
        if (calls == 1) return const Left(ServerFailure('transient'));
        return const Right('recovered');
      });

      expect(result, isA<Right>());
      expect(calls, 2);
    });

    test('returns Left after maxRetries exceeded', () async {
      var calls = 0;
      final result = await RetryHelper.retryOperation(
        () async {
          calls++;
          return const Left(ServerFailure('persistent'));
        },
        maxRetries: 2,
      );

      expect(result, isA<Left>());
      // 1 initial + 2 retries = 3
      expect(calls, 3);
    });

    test('wraps non-Failure exceptions as ServerFailure', () async {
      final result = await RetryHelper.retryOperation(
        () async => throw Exception('boom'),
        maxRetries: 0,
      );

      expect(result, isA<Left>());
      result.fold(
        (f) {
          expect(f, isA<ServerFailure>());
          expect(f.message, contains('boom'));
        },
        (_) => fail('should be Left'),
      );
    });

    test('respects custom maxRetries', () async {
      var calls = 0;
      final result = await RetryHelper.retryOperation(
        () async {
          calls++;
          return const Left(ServerFailure('fail'));
        },
        maxRetries: 1,
      );

      expect(result, isA<Left>());
      // 1 initial + 1 retry = 2
      expect(calls, 2);
    });
  });
}
