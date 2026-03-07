import 'dart:io';

enum PipelineStep { idle, transcribing, translating, generatingAudio, extractingTranscript, completed, error }
enum InputMode { textFile, audioFile, youTube }

class TranslationState {
  final bool isLoading;
  final String? errorMessage;
  final InputMode inputMode;
  final PipelineStep currentStep;
  final String? inputText;
  final String? transcribedText;
  final String? translatedText;
  final File? outputAudioFile;
  final double progress;
  final String sourceLanguage;
  final String targetLanguage;
  final String? statusMessage;
  final String? videoTitle;
  final List<File> savedTextFiles;

  const TranslationState({
    this.isLoading = false,
    this.errorMessage,
    this.inputMode = InputMode.audioFile,
    this.currentStep = PipelineStep.idle,
    this.inputText,
    this.transcribedText,
    this.translatedText,
    this.outputAudioFile,
    this.progress = 0.0,
    this.sourceLanguage = 'Auto-detect',
    this.targetLanguage = 'French',
    this.statusMessage,
    this.videoTitle,
    this.savedTextFiles = const [],
  });

  TranslationState copyWith({
    bool? isLoading,
    String? errorMessage,
    InputMode? inputMode,
    PipelineStep? currentStep,
    String? inputText,
    String? transcribedText,
    String? translatedText,
    File? outputAudioFile,
    double? progress,
    String? sourceLanguage,
    String? targetLanguage,
    String? statusMessage,
    String? videoTitle,
    List<File>? savedTextFiles,
  }) {
    return TranslationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      inputMode: inputMode ?? this.inputMode,
      currentStep: currentStep ?? this.currentStep,
      inputText: inputText ?? this.inputText,
      transcribedText: transcribedText ?? this.transcribedText,
      translatedText: translatedText ?? this.translatedText,
      outputAudioFile: outputAudioFile ?? this.outputAudioFile,
      progress: progress ?? this.progress,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      statusMessage: statusMessage ?? this.statusMessage,
      videoTitle: videoTitle ?? this.videoTitle,
      savedTextFiles: savedTextFiles ?? this.savedTextFiles,
    );
  }
}
