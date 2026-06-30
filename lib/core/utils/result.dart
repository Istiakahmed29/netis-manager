import '../errors/app_error.dart';

/// A simple Result monad: either a success value [T] or an [AppError].
///
/// Using Result instead of throwing forces call-sites to handle errors
/// explicitly, which makes the UI logic easier to reason about.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppError error;
}

extension ResultExtensions<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get valueOrThrow {
    return switch (this) {
      Success<T>(value: final v) => v,
      Failure<T>(error: final e) => throw e,
    };
  }

  AppError get errorOrThrow {
    return switch (this) {
      Success<T>() => throw StateError('Result is a success'),
      Failure<T>(error: final e) => e,
    };
  }

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppError error) onFailure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => onSuccess(v),
      Failure<T>(error: final e) => onFailure(e),
    };
  }
}
