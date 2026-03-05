/// Base exception for application-level errors.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when an authenticated session is required but not available.
class AuthMissingException extends AppException {
  const AuthMissingException([
    super.message = 'Auth session yok. Lutfen tekrar deneyin.',
  ]);
}

/// Thrown on transient or permanent network failures.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Ag baglantisi kurulamadi.',
  ]);
}
