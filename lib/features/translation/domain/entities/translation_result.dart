import 'dart:io';
import 'package:equatable/equatable.dart';

class TranslationResult extends Equatable {
  final String originalText;
  final String translatedText;
  final File audioFile;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.audioFile,
  });

  @override
  List<Object?> get props => [originalText, translatedText, audioFile];
}
