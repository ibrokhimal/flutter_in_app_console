// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'dart:async';

import '../models/log_entry.dart';

/// Minimal pure-Dart notifier — same API as Flutter's [ValueNotifier] but
/// with no Flutter dependency, so [ConsoleController] stays framework-agnostic.
class LogsNotifier {
  List<LogEntry> _value = const [];
  final _listeners = <void Function()>[];

  List<LogEntry> get value => _value;

  set value(List<LogEntry> newValue) {
    _value = newValue;
    for (final fn in List<void Function()>.from(_listeners)) {
      fn();
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void dispose() => _listeners.clear();
}

/// Singleton controller that captures log entries and exposes them to the UI.
///
/// ## Recommended setup — zone interception
/// Wraps the app in [runZonedGuarded] so that every `print()` call
/// (including output from the `logger` package) is captured:
///
/// ```dart
/// void main() {
///   ConsoleController.run(() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     await ConsoleSettings.instance.load();
///     runApp(const MyApp());
///   });
/// }
/// ```
///
/// ## Manual logging from anywhere in your app
/// ```dart
/// ConsoleController.instance.log('User signed in', level: LogLevel.info);
/// ConsoleController.instance.log('404 /api/data', level: LogLevel.network);
/// ConsoleController.instance.log('Something broke',
///     level: LogLevel.error, stackTrace: stackTrace);
/// ```
///
/// ## Integration with the `logger` package
/// Create a custom `LogOutput` subclass in your app:
/// ```dart
/// class InAppConsoleOutput extends LogOutput {
///   @override
///   void output(OutputEvent event) {
///     ConsoleController.instance.log(
///       event.lines.join('\n'),
///       level: switch (event.level) {
///         Level.trace   => LogLevel.verbose,
///         Level.debug   => LogLevel.debug,
///         Level.warning => LogLevel.warning,
///         Level.error   => LogLevel.error,
///         Level.fatal   => LogLevel.error,
///         _             => LogLevel.info,
///       },
///     );
///   }
/// }
///
/// final logger = Logger(output: MultiOutput([ConsoleOutput(), InAppConsoleOutput()]));
/// ```
class ConsoleController {
  ConsoleController._();

  /// The global singleton instance.
  static final ConsoleController instance = ConsoleController._();

  /// Maximum number of entries kept in memory at any one time.
  ///
  /// Oldest entries are discarded once this limit is exceeded.
  static const int maxLogCount = 1000;

  /// Reactive list of all captured [LogEntry] instances.
  ///
  /// Subscribe with [addListener] / [removeListener] to be notified of changes.
  final logs = LogsNotifier();

  // Buffer for logger PrettyPrinter multi-line blocks (┌ … └).
  // null  = not inside a block
  // list  = accumulating lines of the current block
  List<String>? _prettyBuffer;

  // -------------------------------------------------------------------------
  // Initialization
  // -------------------------------------------------------------------------

  /// Marks the controller as initialized.
  ///
  /// When using [run], this is called automatically.
  /// When NOT using [run], call this before [runApp] if you only want manual
  /// logging via [log] / [addLog].
  void initialize() {}

  /// Convenience entry-point that combines [initialize] with
  /// [dart:async.runZonedGuarded] so that bare `print()` calls are also
  /// captured.
  ///
  /// **Important:** call `WidgetsFlutterBinding.ensureInitialized()` and any
  /// async setup *inside* [body] so they run in the same zone as `runApp`:
  ///
  /// ```dart
  /// void main() {
  ///   ConsoleController.run(() async {
  ///     WidgetsFlutterBinding.ensureInitialized();
  ///     await ConsoleSettings.instance.load();
  ///     runApp(const MyApp());
  ///   });
  /// }
  /// ```
  ///
  /// Zone errors are automatically logged at [LogLevel.error].
  static void run(FutureOr<void> Function() body) {
    instance.initialize();
    runZonedGuarded<FutureOr<void>>(
      body,
      instance._onZoneError,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          parent.print(zone, line); // keep terminal output intact
          instance._handleZonePrint(line);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Adds a [LogEntry] to the console.
  ///
  /// Trims the oldest entries when [maxLogCount] is exceeded.
  void addLog(LogEntry entry) {
    final next = List<LogEntry>.from(logs.value)..add(entry);
    if (next.length > maxLogCount) {
      next.removeRange(0, next.length - maxLogCount);
    }
    logs.value = next;
  }

  /// Convenience wrapper around [addLog] for application code.
  ///
  /// ```dart
  /// ConsoleController.instance.log('Loaded profile', level: LogLevel.info);
  /// ```
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    StackTrace? stackTrace,
  }) {
    addLog(LogEntry(level: level, message: message, stackTrace: stackTrace));
  }

  /// Removes all captured log entries.
  void clear() => logs.value = const [];

  void dispose() => logs.dispose();

  // -------------------------------------------------------------------------
  // Zone print handler — groups PrettyPrinter blocks into one LogEntry
  // -------------------------------------------------------------------------

  /// Handles a single line arriving from the zone's `print` interceptor.
  ///
  /// Lines that are part of a `logger` [PrettyPrinter] block (`┌ … └`) are
  /// buffered and emitted as a **single** [LogEntry] when the closing `└`
  /// line arrives. All other lines are emitted immediately.
  void _handleZonePrint(String raw) {
    final s = _stripAnsi(raw).trim();

    // ── PrettyPrinter block start ─────────────────────────────────────────
    if (s.startsWith('┌')) {
      _prettyBuffer = [];
      return;
    }

    // ── PrettyPrinter block end → flush ──────────────────────────────────
    if (s.startsWith('└')) {
      _flushPrettyBuffer();
      return;
    }

    // ── Inside a block ────────────────────────────────────────────────────
    if (_prettyBuffer != null) {
      if (s.startsWith('├')) {
        _prettyBuffer!.add('\x00'); // separator sentinel
      } else if (s.startsWith('│')) {
        _prettyBuffer!.add(s.substring(1).trim());
      }
      return;
    }

    // ── Regular (non-logger) print ────────────────────────────────────────
    final clean = s.isEmpty ? raw.trim() : s;
    if (clean.isEmpty) return;
    addLog(LogEntry(level: _detectLevel(clean), message: clean));
  }

  /// Flushes the accumulated PrettyPrinter block as a single [LogEntry].
  void _flushPrettyBuffer() {
    final buf = _prettyBuffer;
    _prettyBuffer = null;
    if (buf == null || buf.isEmpty) return;

    final lastSep = buf.lastIndexOf('\x00');

    final List<String> contextLines;
    final String rawMessage;

    if (lastSep >= 0) {
      contextLines =
          buf.sublist(0, lastSep).where((l) => l != '\x00').toList();
      rawMessage = buf.sublist(lastSep + 1).join('\n').trim();
    } else {
      contextLines = [];
      rawMessage = buf.join('\n').trim();
    }

    if (rawMessage.isEmpty) return;

    final level = _detectLevel(rawMessage, defaultLevel: LogLevel.verbose);
    final message = _stripEmojiPrefix(rawMessage);

    StackTrace? stackTrace;
    final frameLines = contextLines.where((l) => l.startsWith('#')).toList();
    if (frameLines.isNotEmpty) {
      stackTrace = StackTrace.fromString(frameLines.join('\n'));
    }

    addLog(LogEntry(
      level: level,
      message: message.isEmpty ? rawMessage : message,
      stackTrace: stackTrace,
    ));
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  void _onZoneError(Object error, StackTrace stack) {
    addLog(LogEntry(
      level: LogLevel.error,
      message: error.toString(),
      stackTrace: stack,
    ));
  }

  // -------------------------------------------------------------------------
  // Static helpers
  // -------------------------------------------------------------------------

  /// Strips ANSI escape codes from [text].
  static String _stripAnsi(String text) =>
      text.replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKHF]'), '').trim();

  /// Removes a leading emoji level-marker prepended by [PrettyPrinter].
  static String _stripEmojiPrefix(String message) {
    const markers = [
      '⛔', '🚨', '❌', '🔴',
      '⚠️', '🟡', '🔶',
      '🐛', '🔵',
      '💡', 'ℹ️', '🟢',
      '🐾', '📝', '⬛',
      '👾', '🤬',
    ];
    for (final emoji in markers) {
      if (message.startsWith(emoji)) {
        return message.substring(emoji.length).trim();
      }
    }
    return message;
  }

  /// Best-effort level detection from common `logger` package output formats.
  static LogLevel _detectLevel(String raw,
      {LogLevel defaultLevel = LogLevel.info}) {
    final s = _stripAnsi(raw);

    // 1. Emoji markers (PrettyPrinter)
    if (s.startsWith('⛔') || s.startsWith('🚨') ||
        s.startsWith('❌') || s.startsWith('🔴')) {
      return LogLevel.error;
    }
    if (s.startsWith('⚠️') || s.startsWith('🟡') || s.startsWith('🔶')) {
      return LogLevel.warning;
    }
    if (s.startsWith('🐛') || s.startsWith('🔵')) { return LogLevel.debug; }
    if (s.startsWith('💡') || s.startsWith('ℹ️') || s.startsWith('🟢')) {
      return LogLevel.info;
    }
    if (s.startsWith('🐾') || s.startsWith('📝') || s.startsWith('⬛')) {
      return LogLevel.verbose;
    }
    if (s.startsWith('👾') || s.startsWith('🤬')) { return LogLevel.error; }

    // 2. ANSI color codes
    if (raw.contains('\x1B[31m')) { return LogLevel.error; }
    if (raw.contains('\x1B[33m')) { return LogLevel.warning; }
    if (raw.contains('\x1B[36m')) { return LogLevel.debug; }
    if (raw.contains('\x1B[35m')) { return LogLevel.verbose; }

    // 3. SimplePrinter bracket prefixes
    if (s.startsWith('[E]') || s.startsWith('[WTF]')) { return LogLevel.error; }
    if (s.startsWith('[W]')) { return LogLevel.warning; }
    if (s.startsWith('[D]')) { return LogLevel.debug; }
    if (s.startsWith('[V]')) { return LogLevel.verbose; }
    if (s.startsWith('[I]')) { return LogLevel.info; }

    // 4. Level keyword at start
    final lower = s.toLowerCase();
    if (lower.startsWith('error') || lower.startsWith('wtf') ||
        lower.startsWith('fatal')) {
      return LogLevel.error;
    }
    if (lower.startsWith('warning') || lower.startsWith('warn')) {
      return LogLevel.warning;
    }
    if (lower.startsWith('debug')) { return LogLevel.debug; }
    if (lower.startsWith('verbose') || lower.startsWith('trace')) {
      return LogLevel.verbose;
    }

    return defaultLevel;
  }
}
