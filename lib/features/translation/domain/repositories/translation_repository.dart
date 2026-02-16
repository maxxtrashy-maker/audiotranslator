import 'dart:io';
import '../../../../core/utils/typedefs.dart';

abstract class TranslationRepository {
  ResultFuture<String> transcribeAudio(File audioFile);
  ResultFuture<String> translateText(String text, String targetLanguage);
  ResultFuture<File> generateSpeech(String text, String language);
}
