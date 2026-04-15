// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that holds all user-adjustable settings for the in-app console.
///
/// Every field is a [ValueNotifier] so that the UI reacts in real-time
/// without a full rebuild of the widget tree.
///
/// Settings are persisted to [SharedPreferences] automatically whenever
/// a value changes, after [load] has been awaited at least once.
///
/// ### Typical setup
/// ```dart
/// // In main(), before runApp():
/// await ConsoleSettings.instance.load();
/// ```
///
/// ### Listening to individual settings
/// ```dart
/// ValueListenableBuilder<double>(
///   valueListenable: ConsoleSettings.instance.logFontSize,
///   builder: (ctx, size, _) => Text('size: $size'),
/// )
/// ```
class ConsoleSettings {
  ConsoleSettings._();

  /// The global singleton instance.
  static final ConsoleSettings instance = ConsoleSettings._();

  // ── Storage keys ──────────────────────────────────────────────────────────
  static const _kButtonSize = 'iac_button_size';
  static const _kButtonOpacity = 'iac_button_opacity';
  static const _kLogFontSize = 'iac_log_font_size';
  static const _kConsoleBgColorIndex = 'iac_console_bg_color_index';
  static const _kConsoleBgOpacity = 'iac_console_bg_opacity';

  // ── Defaults ─────────────────────────────────────────────────────────────
  static const double defaultButtonSize = 52.0;
  static const double defaultButtonOpacity = 0.85;
  static const double defaultLogFontSize = 12.0;
  static const int defaultConsoleBgColorIndex = 0;
  static const double defaultConsoleBgOpacity = 0.95;

  /// Preset base colors for the console background (fully opaque).
  ///
  /// The actual background is rendered with [consoleBgOpacity] applied.
  static const List<int> consoleBgPresets = [
    0xFF121212, // Near-black (default)
    0xFF0D1B2A, // Dark blue
    0xFF1A0D2E, // Dark purple
    0xFF0D1A12, // Dark green
    0xFF1A1200, // Dark amber
  ];

  // ── Reactive settings ────────────────────────────────────────────────────

  /// Diameter of the floating console button, in logical pixels.
  ///
  /// Clamped to [32, 96] in the settings UI.
  final ValueNotifier<double> buttonSize = ValueNotifier(defaultButtonSize);

  /// Opacity of the floating console button [0.0, 1.0].
  ///
  /// Clamped to [0.1, 1.0] in the settings UI so the button is
  /// never fully invisible.
  final ValueNotifier<double> buttonOpacity =
      ValueNotifier(defaultButtonOpacity);

  /// Font size used for log message text in the console list.
  ///
  /// Clamped to [10, 24] in the settings UI.
  final ValueNotifier<double> logFontSize = ValueNotifier(defaultLogFontSize);

  /// Index into [consoleBgPresets] selecting the console panel background color.
  ///
  /// Preset 0 (near-black) is the default. The color is rendered at
  /// [consoleBgOpacity] so both settings work together.
  final ValueNotifier<int> consoleBgColorIndex =
      ValueNotifier(defaultConsoleBgColorIndex);

  /// Opacity of the console panel background [0.5, 1.0].
  ///
  /// Applied to both the body area and the app bar. Lower values let the
  /// app content show through behind the console overlay.
  final ValueNotifier<double> consoleBgOpacity =
      ValueNotifier(defaultConsoleBgOpacity);

  // ── State ─────────────────────────────────────────────────────────────────

  bool _loaded = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Loads persisted values from [SharedPreferences] and registers listeners
  /// that auto-save on every subsequent change.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();

    // Restore persisted values (fall back to defaults if not yet saved).
    buttonSize.value = prefs.getDouble(_kButtonSize) ?? defaultButtonSize;
    buttonOpacity.value =
        prefs.getDouble(_kButtonOpacity) ?? defaultButtonOpacity;
    logFontSize.value = prefs.getDouble(_kLogFontSize) ?? defaultLogFontSize;
    consoleBgColorIndex.value =
        prefs.getInt(_kConsoleBgColorIndex) ?? defaultConsoleBgColorIndex;
    consoleBgOpacity.value =
        prefs.getDouble(_kConsoleBgOpacity) ?? defaultConsoleBgOpacity;

    // Register auto-save listeners.
    buttonSize.addListener(
      () => prefs.setDouble(_kButtonSize, buttonSize.value),
    );
    buttonOpacity.addListener(
      () => prefs.setDouble(_kButtonOpacity, buttonOpacity.value),
    );
    logFontSize.addListener(
      () => prefs.setDouble(_kLogFontSize, logFontSize.value),
    );
    consoleBgColorIndex.addListener(
      () => prefs.setInt(_kConsoleBgColorIndex, consoleBgColorIndex.value),
    );
    consoleBgOpacity.addListener(
      () => prefs.setDouble(_kConsoleBgOpacity, consoleBgOpacity.value),
    );
  }

  /// Resets all settings to their default values.
  ///
  /// Since the [ValueNotifier] listeners auto-save, the defaults will
  /// also be written back to [SharedPreferences].
  void resetToDefaults() {
    buttonSize.value = defaultButtonSize;
    buttonOpacity.value = defaultButtonOpacity;
    logFontSize.value = defaultLogFontSize;
    consoleBgColorIndex.value = defaultConsoleBgColorIndex;
    consoleBgOpacity.value = defaultConsoleBgOpacity;
  }
}
