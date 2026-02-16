import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

class QuotaExceededFailure extends Failure {
  const QuotaExceededFailure(super.message);
}

class InvalidFormatFailure extends Failure {
  const InvalidFormatFailure(super.message);
}

class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure(super.message);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message);
}

