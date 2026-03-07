import 'package:fpdart/fpdart.dart';
import '../../domain/repositories/youtube_transcript_repository.dart';
import '../datasources/youtube_transcript_data_source.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/retry_helper.dart';

class YouTubeTranscriptRepositoryImpl implements YouTubeTranscriptRepository {
  final YouTubeTranscriptDataSource _dataSource;

  YouTubeTranscriptRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, ({String transcript, String title})>> extractTranscript(String videoId) async {
    return RetryHelper.retryOperation(() async {
      try {
        final result = await _dataSource.fetchTranscript(videoId);
        return Right(result);
      } catch (e) {
        if (e is Failure) return Left(e);
        return Left(ServerFailure(e.toString()));
      }
    });
  }
}
