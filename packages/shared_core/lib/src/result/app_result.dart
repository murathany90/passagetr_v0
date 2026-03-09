sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is AppSuccess<T>;
  bool get isFailure => this is AppFailure<T>;
}

class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;
}
