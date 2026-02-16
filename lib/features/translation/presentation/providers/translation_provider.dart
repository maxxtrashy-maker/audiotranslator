import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../domain/usecases/transcribe_audio.dart';
import '../../domain/usecases/translate_text.dart';
import '../../domain/usecases/generate_speech.dart';
import '../../data/datasources/gemini_data_source.dart';
import '../../data/datasources/tts_data_source.dart';
import '../../data/repositories/translation_repository_impl.dart';

// Dependencies
final geminiDataSourceProvider = Provider<GeminiDataSource>((ref) {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'dummy_key');
  final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);
  return GeminiDataSourceImpl(model);
});

final ttsDataSourceProvider = Provider<TtsDataSource>((ref) {
  return TtsDataSourceImpl(FlutterTts());
});

final translationRepositoryProvider = Provider((ref) {
  return TranslationRepositoryImpl(
    ref.watch(geminiDataSourceProvider),
    ref.watch(ttsDataSourceProvider),
  );
});

final transcribeAudioUseCaseProvider = Provider((ref) {
  return TranscribeAudio(ref.watch(translationRepositoryProvider));
});

final translateTextUseCaseProvider = Provider((ref) {
  return TranslateText(ref.watch(translationRepositoryProvider));
});

final generateSpeechUseCaseProvider = Provider((ref) {
  return GenerateSpeech(ref.watch(translationRepositoryProvider));
});

// State
class TranslationState {
  final bool isLoading;
  final String? errorMessage;
  final String? transcription;
  final String? translation;
  final File? audioFile;
  final double progress; // 0.0 to 1.0

  const TranslationState({
    this.isLoading = false,
    this.errorMessage,
    this.transcription,
    this.translation,
    this.audioFile,
    this.progress = 0.0,
  });

  TranslationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? transcription,
    String? translation,
    File? audioFile,
    double? progress,
  }) {
    return TranslationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      transcription: transcription ?? this.transcription,
      translation: translation ?? this.translation,
      audioFile: audioFile ?? this.audioFile,
      progress: progress ?? this.progress,
    );
  }
}

class TranslationNotifier extends StateNotifier<TranslationState> {
  final TranscribeAudio _transcribeAudio;
  final TranslateText _translateText;
  final GenerateSpeech _generateSpeech;

  TranslationNotifier(
    this._transcribeAudio,
    this._translateText,
    this._generateSpeech,
  ) : super(const TranslationState());

  Future<void> processAudio(File file) async {
    state = state.copyWith(isLoading: true, progress: 0.1, errorMessage: null);

    // 1. Transcribe
    final transcribeResult = await _transcribeAudio(file);

    await transcribeResult.fold(
      (failure) async {
         state = state.copyWith(isLoading: false, errorMessage: failure.message, progress: 0);
      },
      (transcription) async {
        state = state.copyWith(transcription: transcription, progress: 0.4);

        // 2. Translate
        final translateResult = await _translateText(TranslateTextParams(text: transcription, targetLanguage: 'French'));

        await translateResult.fold(
          (failure) async {
            state = state.copyWith(isLoading: false, errorMessage: failure.message, progress: 0);
          },
          (translation) async {
             state = state.copyWith(translation: translation, progress: 0.7);

             // 3. TTS
             final ttsResult = await _generateSpeech(GenerateSpeechParams(text: translation, language: 'fr-FR'));

             ttsResult.fold(
               (failure) {
                 state = state.copyWith(isLoading: false, errorMessage: failure.message, progress: 0);
               },
               (audioFile) {
                 state = state.copyWith(isLoading: false, audioFile: audioFile, progress: 1.0);
               }
             );
          }
        );
      }
    );
  }

  void reset() {
    state = const TranslationState();
  }
}

final translationProvider = StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  return TranslationNotifier(
    ref.watch(transcribeAudioUseCaseProvider),
    ref.watch(translateTextUseCaseProvider),
    ref.watch(generateSpeechUseCaseProvider),
  );
});
