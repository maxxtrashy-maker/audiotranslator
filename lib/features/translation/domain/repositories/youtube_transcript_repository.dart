import '../../../../core/utils/typedefs.dart';
import '../entities/youtube_subtitle_track.dart';

abstract class YouTubeTranscriptRepository {
  ResultFuture<({String transcript, String title, List<YouTubeSubtitleTrack> tracks})> extractTranscript(String videoId);
}
