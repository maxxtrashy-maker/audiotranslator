import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/youtube_transcript_repository.dart';
import '../entities/youtube_subtitle_track.dart';

class ExtractYouTubeTranscript implements UseCase<({String transcript, String title, List<YouTubeSubtitleTrack> tracks}), String> {
  final YouTubeTranscriptRepository _repository;

  ExtractYouTubeTranscript(this._repository);

  @override
  ResultFuture<({String transcript, String title, List<YouTubeSubtitleTrack> tracks})> call(String params) {
    return _repository.extractTranscript(params);
  }
}
