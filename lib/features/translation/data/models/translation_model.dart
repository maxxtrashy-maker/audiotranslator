import 'dart:io';
import '../../domain/entities/translation_result.dart';

class TranslationModel extends TranslationResult {
  const TranslationModel({
    required super.originalText,
    required super.translatedText,
    required super.audioFile,
  });

  // Example factory for JSON serialization if needed
  factory TranslationModel.fromJson(Map<String, dynamic> json) {
    return TranslationModel(
      originalText: json['originalText'] as String,
      translatedText: json['translatedText'] as String,
      audioFile: File(json['audioFilePath'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'originalText': originalText,
      'translatedText': translatedText,
      'audioFilePath': audioFile.path,
    };
  }
}
