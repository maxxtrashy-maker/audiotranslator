import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/language_mapper.dart';
import '../../../../core/utils/transcript_saver.dart';
import '../../domain/usecases/generate_speech.dart';
import '../../domain/usecases/transcribe_audio.dart';
import '../../domain/usecases/translate_text.dart';
import '../../domain/usecases/extract_youtube_transcript.dart';
import 'translation_di_providers.dart';
import 'translation_state.dart';

class TranslationNotifier extends StateNotifier<TranslationState> {
  final GenerateSpeech _generateSpeech;
  final TranscribeAudio _transcribeAudio;
  final TranslateText _translateText;
  final ExtractYouTubeTranscript _extractYouTubeTranscript;

  TranslationNotifier(
    this._generateSpeech,
    this._transcribeAudio,
    this._translateText,
    this._extractYouTubeTranscript,
  ) : super(const TranslationState());

  void setSourceLanguage(String language) {
    state = state.copyWith(sourceLanguage: language);
  }

  void setTargetLanguage(String language) {
    state = state.copyWith(targetLanguage: language);
  }

  void setInputMode(InputMode mode) {
    state = TranslationState(
      inputMode: mode,
      sourceLanguage: state.sourceLanguage,
      targetLanguage: state.targetLanguage,
    );
  }

  /// Text file flow: text -> TTS (existing behavior)
  Future<void> processTextFile(File file) async {
    try {
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
        currentStep: PipelineStep.generatingAudio,
        statusMessage: 'Pr\u00e9paration...',
      );

      final languageCode = LanguageMapper.toGoogleTtsCode(state.targetLanguage);
      final ttsResult = await _generateSpeech(
        GenerateSpeechParams(
          text: text,
          language: languageCode,
          onProgress: (message) {
            state = state.copyWith(statusMessage: message);
          },
        ),
      );

      ttsResult.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
            currentStep: PipelineStep.error,
            statusMessage: null,
          );
        },
        (audioFile) {
          state = state.copyWith(
            isLoading: false,
            outputAudioFile: audioFile,
            progress: 1.0,
            currentStep: PipelineStep.completed,
            statusMessage: 'Termin\u00e9 !',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors de la lecture du fichier: ${e.toString()}',
        currentStep: PipelineStep.error,
        statusMessage: null,
      );
    }
  }

  /// Audio file flow: STT -> Translation -> TTS
  Future<void> processAudioFile(File file) async {
    try {
      // Step 1: Transcription
      state = state.copyWith(
        isLoading: true,
        progress: 0.05,
        errorMessage: null,
        currentStep: PipelineStep.transcribing,
        statusMessage: 'Transcription en cours...',
      );

      final sttResult = await _transcribeAudio(file);

      final transcribedText = sttResult.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
            currentStep: PipelineStep.error,
            statusMessage: null,
          );
          return null;
        },
        (text) => text,
      );

      if (transcribedText == null) return;

      // Save transcription .txt
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      File? transcriptionFile;
      try {
        transcriptionFile = await TranscriptSaver.save(
          text: transcribedText,
          label: 'transcription_$dateStr',
        );
        debugPrint('[Save] Transcription saved: ${transcriptionFile.path}');
      } catch (e) {
        debugPrint('[Save] Failed to save transcription: $e');
      }

      state = state.copyWith(
        transcribedText: transcribedText,
        inputText: transcribedText,
        savedTextFiles: [if (transcriptionFile != null) transcriptionFile],
        progress: 0.33,
        currentStep: PipelineStep.translating,
        statusMessage: 'Traduction en cours...',
      );

      // Step 2: Translation
      final deeplCode = LanguageMapper.toDeeplCode(state.targetLanguage);
      final translateResult = await _translateText(
        TranslateTextParams(text: transcribedText, targetLanguage: deeplCode),
      );

      final translatedText = translateResult.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
            currentStep: PipelineStep.error,
            statusMessage: null,
          );
          return null;
        },
        (text) => text,
      );

      if (translatedText == null) return;

      // Save translation .txt
      File? translationFile;
      try {
        translationFile = await TranscriptSaver.save(
          text: translatedText,
          label: 'traduction_$dateStr',
        );
        debugPrint('[Save] Translation saved: ${translationFile.path}');
      } catch (e) {
        debugPrint('[Save] Failed to save translation: $e');
      }

      state = state.copyWith(
        translatedText: translatedText,
        savedTextFiles: [
          ...state.savedTextFiles,
          if (translationFile != null) translationFile,
        ],
        progress: 0.66,
        currentStep: PipelineStep.generatingAudio,
        statusMessage: 'G\u00e9n\u00e9ration audio...',
      );

      // Step 3: TTS
      final languageCode = LanguageMapper.toGoogleTtsCode(state.targetLanguage);
      final ttsResult = await _generateSpeech(
        GenerateSpeechParams(
          text: translatedText,
          language: languageCode,
          onProgress: (message) {
            state = state.copyWith(statusMessage: message);
          },
        ),
      );

      ttsResult.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
            currentStep: PipelineStep.error,
            statusMessage: null,
          );
        },
        (audioFile) {
          state = state.copyWith(
            isLoading: false,
            outputAudioFile: audioFile,
            progress: 1.0,
            currentStep: PipelineStep.completed,
            statusMessage: 'Termin\u00e9 !',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors du traitement: ${e.toString()}',
        currentStep: PipelineStep.error,
        statusMessage: null,
      );
    }
  }

  /// YouTube flow: extract subtitles only
  Future<void> processYouTubeUrl(String videoId) async {
    try {
      state = state.copyWith(
        isLoading: true,
        progress: 0.1,
        errorMessage: null,
        currentStep: PipelineStep.extractingTranscript,
        statusMessage: 'Extraction des sous-titres...',
      );

      final result = await _extractYouTubeTranscript(videoId);

      await result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
            currentStep: PipelineStep.error,
            statusMessage: null,
          );
        },
        (data) async {
          File? savedFile;
          try {
            savedFile = await TranscriptSaver.save(
              text: data.transcript,
              label: data.title,
            );
            debugPrint('[Save] YouTube transcript saved: ${savedFile.path}');
          } catch (e) {
            debugPrint('[Save] Failed to save transcript: $e');
          }

          state = state.copyWith(
            isLoading: false,
            transcribedText: data.transcript,
            videoTitle: data.title,
            savedTextFiles: savedFile != null ? [savedFile] : [],
            progress: 1.0,
            currentStep: PipelineStep.completed,
            statusMessage: 'Terminé !',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors de l\'extraction : ${e.toString()}',
        currentStep: PipelineStep.error,
        statusMessage: null,
      );
    }
  }

  void reset() {
    state = TranslationState(
      inputMode: state.inputMode,
      sourceLanguage: state.sourceLanguage,
      targetLanguage: state.targetLanguage,
    );
  }
}

// --- Provider ---

final translationProvider =
    StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  return TranslationNotifier(
    ref.watch(generateSpeechUseCaseProvider),
    ref.watch(transcribeAudioUseCaseProvider),
    ref.watch(translateTextUseCaseProvider),
    ref.watch(extractYouTubeTranscriptUseCaseProvider),
  );
});
