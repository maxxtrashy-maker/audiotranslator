import 'package:fpdart/fpdart.dart';
import '../../domain/repositories/youtube_transcript_repository.dart';
import '../datasources/youtube_transcript_data_source.dart';
import '../../../../core/errors/failures.dart';

class YouTubeTranscriptRepositoryImpl implements YouTubeTranscriptRepository {
  final YouTubeTranscriptDataSource _dataSource;

  YouTubeTranscriptRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, ({String transcript, String title})>> extractTranscript(String videoId) async {
    return _retryOperation(
      () async {
        try {
          final result = await _dataSource.fetchTranscript(videoId);
          return Right(result);
        } catch (e) {
          if (e is Failure) return Left(e);
          return Left(ServerFailure(e.toString()));
        }
      },
      maxRetries: 2,
    );
  }

  /// Retry operation with exponential backoff
  Future<Either<Failure, T>> _retryOperation<T>(
    Future<Either<Failure, T>> Function() operation, {
    required int maxRetries,
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
