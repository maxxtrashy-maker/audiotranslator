import '../utils/typedefs.dart';

abstract class UseCase<T, Params> {
  ResultFuture<T> call(Params params);
}

class NoParams {}
