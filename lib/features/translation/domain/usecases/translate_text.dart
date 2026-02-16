import 'package:equatable/equatable.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/translation_repository.dart';

class TranslateTextParams extends Equatable {
  final String text;
  final String targetLanguage;

  const TranslateTextParams({required this.text, required this.targetLanguage});

  @override
  List<Object?> get props => [text, targetLanguage];
}

class TranslateText implements UseCase<String, TranslateTextParams> {
  final TranslationRepository _repository;

  TranslateText(this._repository);

  @override
  ResultFuture<String> call(TranslateTextParams params) {
    return _repository.translateText(params.text, params.targetLanguage);
  }
}
