import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../domain/usecases/generate_speech.dart';
import '../../domain/usecases/transcribe_audio.dart';
import '../../domain/usecases/translate_text.dart';
import '../../domain/usecases/extract_youtube_transcript.dart';
import '../../data/datasources/speech_to_text_data_source.dart';
import '../../data/datasources/translation_data_source.dart';
import '../../data/datasources/tts_data_source.dart';
import '../../data/datasources/youtube_transcript_data_source.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../data/repositories/youtube_transcript_repository_impl.dart';

// --- Core ---

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final apiConfigProvider = Provider<ApiConfig>((ref) {
  return ApiConfig();
});

// --- DataSources ---

final sttDataSourceProvider = Provider<SpeechToTextDataSource>((ref) {
  return GroqSpeechToTextDataSourceImpl(
    ref.watch(httpClientProvider),
    ref.watch(apiConfigProvider),
  );
});

final translationDataSourceProvider = Provider<TranslationDataSource>((ref) {
  return DeeplTranslationDataSourceImpl(
    ref.watch(httpClientProvider),
    ref.watch(apiConfigProvider),
  );
});

final ttsDataSourceProvider = Provider<TtsDataSource>((ref) {
  return TtsDataSourceImpl(
    ref.watch(httpClientProvider),
    ref.watch(apiConfigProvider),
  );
});

final youTubeTranscriptDataSourceProvider = Provider<YouTubeTranscriptDataSource>((ref) {
  return YouTubeTranscriptDataSourceImpl(
    ref.watch(httpClientProvider),
    ref.watch(apiConfigProvider),
  );
});

// --- Repositories ---

final translationRepositoryProvider = Provider((ref) {
  return TranslationRepositoryImpl(
    ref.watch(sttDataSourceProvider),
    ref.watch(translationDataSourceProvider),
    ref.watch(ttsDataSourceProvider),
  );
});

final youTubeTranscriptRepositoryProvider = Provider((ref) {
  return YouTubeTranscriptRepositoryImpl(
    ref.watch(youTubeTranscriptDataSourceProvider),
  );
});

// --- UseCases ---

final generateSpeechUseCaseProvider = Provider((ref) {
  return GenerateSpeech(ref.watch(translationRepositoryProvider));
});

final transcribeAudioUseCaseProvider = Provider((ref) {
  return TranscribeAudio(ref.watch(translationRepositoryProvider));
});

final translateTextUseCaseProvider = Provider((ref) {
  return TranslateText(ref.watch(translationRepositoryProvider));
});

final extractYouTubeTranscriptUseCaseProvider = Provider((ref) {
  return ExtractYouTubeTranscript(ref.watch(youTubeTranscriptRepositoryProvider));
});
