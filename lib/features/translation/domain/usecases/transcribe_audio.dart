import 'dart:io';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/translation_repository.dart';

class TranscribeAudio implements UseCase<String, File> {
  final TranslationRepository _repository;

  TranscribeAudio(this._repository);

  @override
  ResultFuture<String> call(File params) {
    return _repository.transcribeAudio(params);
  }
}
