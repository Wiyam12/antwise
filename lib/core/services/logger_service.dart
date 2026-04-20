import 'package:flutter/foundation.dart';

/// Lightweight logging; swap implementation or add remote logging later.
abstract class LoggerService {
  void d(String message, [Object? error, StackTrace? stackTrace]);
}

class DebugLoggerService implements LoggerService {
  @override
  void d(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[D] $message');
    if (error != null) {
      debugPrint('$error');
    }
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }
}
