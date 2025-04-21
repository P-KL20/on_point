import 'package:logger/logger.dart';

/// A service for logging messages with different severity levels.
/// This service uses the [Logger] package to provide a simple interface
/// for logging messages. It supports different log levels such as debug,
/// info, warning, and error. The log messages are printed to the console
/// with the corresponding log level.
class LoggerService {
  static final Logger _logger = Logger();

  static void debug(dynamic message) {
    _logger.d(message);
  }

  static void info(dynamic message) {
    _logger.i(message);
  }

  static void warning(dynamic message) {
    _logger.w(message);
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
