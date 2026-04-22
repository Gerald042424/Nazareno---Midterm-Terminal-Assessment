enum AppErrorType {
  validation,
  authentication,
  database,
  network,
  firestore,
  unknown,
}

class AppError {
  const AppError({
    required this.message,
    required this.type,
  });

  final String message;
  final AppErrorType type;
}

class AppResult<T> {
  const AppResult._({
    this.data,
    this.error,
  });

  final T? data;
  final AppError? error;

  bool get isSuccess => error == null;

  static AppResult<T> success<T>(T data) {
    return AppResult<T>._(data: data);
  }

  static AppResult<T> failure<T>(AppError error) {
    return AppResult<T>._(error: error);
  }
}
