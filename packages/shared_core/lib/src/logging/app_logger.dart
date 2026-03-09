import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(String message) {
    debugPrint('[PASSAGETR][INFO] $message');
  }

  static void warning(String message) {
    debugPrint('[PASSAGETR][WARN] $message');
  }
}
