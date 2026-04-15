// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'package:flutter/foundation.dart';

/// The severity level of a [LogEntry].
///
/// Used to color-code log items in the console UI and to drive
/// filter chips in the log list.
enum LogLevel {
  /// Highly detailed trace messages — lowest priority.
  verbose,

  /// Standard debug messages originating from [debugPrint].
  debug,

  /// General informational messages.
  info,

  /// Non-critical warnings that may need attention.
  warning,

  /// Runtime errors or caught exceptions.
  error,

  /// HTTP / WebSocket request and response traces.
  network,
}

/// Extension helpers on [LogLevel].
extension LogLevelX on LogLevel {
  /// A short, human-readable label used in the console UI.
  String get label => switch (this) {
        LogLevel.verbose => 'VRB',
        LogLevel.debug => 'DBG',
        LogLevel.info => 'INF',
        LogLevel.warning => 'WRN',
        LogLevel.error => 'ERR',
        LogLevel.network => 'NET',
      };
}

/// An immutable snapshot of a single captured log message.
///
/// Instances are created by [ConsoleController.addLog] (internal) and
/// [ConsoleController.log] (public API). You should never need to
/// construct one directly in application code.
@immutable
class LogEntry {
  /// Unique identifier — stable within one app session.
  final String id;

  /// Severity level of this entry.
  final LogLevel level;

  /// The captured message text.
  final String message;

  /// Wall-clock time when this entry was captured.
  final DateTime timestamp;

  /// Optional stack trace, typically attached to [LogLevel.error] entries.
  final StackTrace? stackTrace;

  // Monotonic counter used to generate unique IDs without a UUID package.
  static int _counter = 0;

  /// Creates a [LogEntry].
  ///
  /// [timestamp] defaults to [DateTime.now()] if omitted.
  LogEntry({
    required this.level,
    required this.message,
    DateTime? timestamp,
    this.stackTrace,
  })  : id = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
        timestamp = timestamp ?? DateTime.now();

  /// A one-line representation suitable for display in the log list.
  ///
  /// Format: `HH:mm:ss.mmm [LVL] message`
  String toDisplayString() {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms [${level.label}] $message';
  }

  /// Full ISO-8601 export string, including optional stack trace.
  String toExportString() {
    final buf = StringBuffer(
      '${timestamp.toIso8601String()} [${level.name.toUpperCase()}] $message',
    );
    if (stackTrace != null) {
      buf
        ..writeln()
        ..write(stackTrace.toString());
    }
    return buf.toString();
  }
}
