import 'package:logger/logger.dart';

/// App-wide logger instance.
///
/// In debug builds every request/response is logged.
/// In release builds only warnings and errors are logged.
final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
