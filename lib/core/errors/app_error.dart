/// Typed exceptions used throughout the app.
///
/// Keeping errors typed (rather than using raw strings) lets the UI
/// display the right message and lets tests assert specific failure modes.

sealed class AppError implements Exception {
  const AppError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Router could not be found on the local network.
class RouterNotFoundError extends AppError {
  const RouterNotFoundError()
      : super(
          'Could not find the router on your network. '
          'Make sure you are connected to the router\'s Wi-Fi.',
        );
}

/// HTTP request to the router failed (timeout, connection refused, etc.)
class RouterConnectionError extends AppError {
  const RouterConnectionError(String detail)
      : super('Connection to router failed: $detail');
}

/// The username / password were rejected by the router.
class AuthenticationError extends AppError {
  const AuthenticationError()
      : super('Incorrect username or password.');
}

/// Session expired — user needs to log in again.
class SessionExpiredError extends AppError {
  const SessionExpiredError()
      : super('Session expired. Please log in again.');
}

/// Could not parse the HTML the router returned.
/// This usually means the firmware version differs from what was tested.
class ParseError extends AppError {
  const ParseError(String detail)
      : super('Could not read router response: $detail');
}

/// A feature the user tried to use is not supported by this firmware.
class UnsupportedFeatureError extends AppError {
  const UnsupportedFeatureError(String feature)
      : super('$feature is not supported by this router\'s firmware.');
}
