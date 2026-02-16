import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../domain/usecases/generate_speech.dart';
import '../../data/datasources/tts_data_source.dart';
import '../../data/repositories/translation_repository_impl.dart';

// Dependencies
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final apiConfigProvider = Provider<ApiConfig>((ref) {
  return ApiConfig();
});

final ttsDataSourceProvider = Provider<TtsDataSource>((ref) {
  return TtsDataSourceImpl(
    ref.watch(httpClientProvider),
    ref.watch(apiConfigProvider),
  );
});

final translationRepositoryProvider = Provider((ref) {
  return TranslationRepositoryImpl(
    ref.watch(ttsDataSourceProvider),
  );
});

final generateSpeechUseCaseProvider = Provider((ref) {
  return GenerateSpeech(ref.watch(translationRepositoryProvider));
});

// State
class TtsState {
  final bool isLoading;
  final String? errorMessage;
  final String? inputText;
  final File? audioFile;
  final double progress; // 0.0 to 1.0
  final String targetLanguage; // Target language for TTS
  final String? statusMessage; // Current status message

  const TtsState({
    this.isLoading = false,
    this.errorMessage,
    this.inputText,
    this.audioFile,
    this.progress = 0.0,
    this.targetLanguage = 'French',
    this.statusMessage,
  });

  TtsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? inputText,
    File? audioFile,
    double? progress,
    String? targetLanguage,
    String? statusMessage,
  }) {
    return TtsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      inputText: inputText ?? this.inputText,
      audioFile: audioFile ?? this.audioFile,
      progress: progress ?? this.progress,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class TtsNotifier extends StateNotifier<TtsState> {
  final GenerateSpeech _generateSpeech;

  TtsNotifier(this._generateSpeech) : super(const TtsState());

  void setTargetLanguage(String language) {
    state = state.copyWith(targetLanguage: language);
  }

  Future<void> processTextFile(File file) async {
    try {
      // Read text file
      final text = await file.readAsString();
      
      if (text.trim().isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Le fichier texte est vide',
          progress: 0,
        );
        return;
      }

      state = state.copyWith(
        isLoading: true,
        progress: 0.1,
        errorMessage: null,
        inputText: text,
        statusMessage: 'Préparation...',
      );

      // Generate speech with progress callback
      final languageCode = _getLanguageCode(state.targetLanguage);
      final ttsResult = await _generateSpeech(
        GenerateSpeechParams(
          text: text,
          language: languageCode,
          onProgress: (message) {
            // Update status message in real-time
            state = state.copyWith(statusMessage: message);
          },
        ),
      );

      ttsResult.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
            statusMessage: null,
          );
        },
        (audioFile) {
          state = state.copyWith(
            isLoading: false,
            audioFile: audioFile,
            progress: 1.0,
            statusMessage: 'Terminé !',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors de la lecture du fichier: ${e.toString()}',
        statusMessage: null,
      );
    }
  }

  void reset() {
    state = TtsState(targetLanguage: state.targetLanguage);
  }

  /// Convert language name to language code for TTS
  String _getLanguageCode(String language) {
    final languageMap = {
      'French': 'fr-FR',
      'English': 'en-US',
      'Spanish': 'es-ES',
      'German': 'de-DE',
      'Italian': 'it-IT',
      'Portuguese': 'pt-BR',
      'Japanese': 'ja-JP',
      'Chinese': 'zh-CN',
      'Korean': 'ko-KR',
      'Arabic': 'ar-XA',
    };
    
    return languageMap[language] ?? 'en-US';
  }
}

final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  return TtsNotifier(
    ref.watch(generateSpeechUseCaseProvider),
  );
});
