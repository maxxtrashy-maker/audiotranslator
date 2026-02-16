import 'dart:io';
import 'package:fpdart/fpdart.dart';
import '../errors/failures.dart';
import 'mime_detector.dart';

class FileValidator {
  /// Maximum file size for Google Cloud Speech-to-Text REST API (10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Validate an audio file for processing
  static Either<Failure, File> validate(File file) {
    // Check if file exists
    if (!file.existsSync()) {
      return Left(ServerFailure('File does not exist'));
    }

    // Check file size
    final fileSize = file.lengthSync();
    if (fileSize > maxFileSizeBytes) {
      final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      return Left(FileTooLargeFailure(
        'File too large ($sizeMB MB). Maximum size is 10 MB.'
      ));
    }

    // Check if file is empty
    if (fileSize == 0) {
      return Left(ServerFailure('File is empty'));
    }

    // Check audio format
    if (!MimeDetector.isSupportedAudioFormat(file)) {
      return Left(InvalidFormatFailure(
        'Unsupported audio format. Supported formats: MP3, WAV, M4A, FLAC, OGG'
      ));
    }

    return Right(file);
  }
}
