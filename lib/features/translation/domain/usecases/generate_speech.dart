import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/translation_repository.dart';

class GenerateSpeechParams extends Equatable {
  final String text;
  final String language;

  const GenerateSpeechParams({required this.text, required this.language});

  @override
  List<Object?> get props => [text, language];
}

class GenerateSpeech implements UseCase<File, GenerateSpeechParams> {
  final TranslationRepository _repository;

  GenerateSpeech(this._repository);

  @override
  ResultFuture<File> call(GenerateSpeechParams params) {
    return _repository.generateSpeech(params.text, params.language);
  }
}
