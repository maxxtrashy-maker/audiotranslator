import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/youtube_transcript_repository.dart';

class ExtractYouTubeTranscript implements UseCase<({String transcript, String title}), String> {
  final YouTubeTranscriptRepository _repository;

  ExtractYouTubeTranscript(this._repository);

  @override
  ResultFuture<({String transcript, String title})> call(String params) {
    return _repository.extractTranscript(params);
  }
}
