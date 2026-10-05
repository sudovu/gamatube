import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  static final RegExp _sensitivePattern = RegExp(
    r'(ya29\.[a-zA-Z0-9_\-]+|bearer\s+[a-zA-Z0-9_\-\.]+|refresh_token=[^&\s]+|client_secret=[^&\s]+|key=[a-zA-Z0-9_\-]+)',
    caseSensitive: false,
  );

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, 'DEBUG', message, error, stackTrace);
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, 'INFO', message, error, stackTrace);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, 'WARN', message, error, stackTrace);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, 'ERROR', message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.index < minLevel.index) return;

    final scrubbedMessage = _scrub(message);
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$tag] $scrubbedMessage';

    debugPrint(logLine);
    if (error != null) {
      debugPrint('  Error: ${_scrub(error.toString())}');
    }
    if (stackTrace != null && level == LogLevel.error) {
      debugPrint('  Stack: $stackTrace');
    }
  }

  static String _scrub(String text) {
    return text.replaceAllMapped(_sensitivePattern, (match) => '[REDACTED_SECRET]');
  }
}
