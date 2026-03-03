import '../../../../core/utils/typedefs.dart';

abstract class YouTubeTranscriptRepository {
  ResultFuture<({String transcript, String title})> extractTranscript(String videoId);
}
