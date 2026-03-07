import 'package:fpdart/fpdart.dart';
import '../errors/failures.dart';

class RetryHelper {
  /// Retry an operation with exponential backoff.
  ///
  /// Non-retryable failures (QuotaExceeded, Timeout, InvalidFormat,
  /// FileTooLarge) are returned immediately without retry.
  static Future<Either<Failure, T>> retryOperation<T>(
    Future<Either<Failure, T>> Function() operation, {
    int maxRetries = 2,
  }) async {
    int retryCount = 0;

    while (true) {
      try {
        final result = await operation();

        return result.fold(
          (failure) {
            if (failure is QuotaExceededFailure ||
                failure is TimeoutFailure ||
                failure is InvalidFormatFailure ||
                failure is FileTooLargeFailure) {
              return Left(failure);
            }
            throw failure;
          },
          (success) => Right(success),
        );
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          if (e is Failure) return Left(e);
          return Left(ServerFailure(e.toString()));
        }
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }
}
