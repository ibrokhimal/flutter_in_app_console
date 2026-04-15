// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'package:flutter/material.dart';

import '../settings/console_settings.dart';
import 'console_screen.dart';

/// Wraps the [MaterialApp] builder to inject a draggable debug console
/// button as a persistent overlay across all screens.
///
/// ## Recommended setup
///
/// ```dart
/// // 1. In main(), before runApp():
/// await ConsoleSettings.instance.load();
/// ConsoleController.instance.initialize(); // or use ConsoleController.run(…)
///
/// // 2. Inside MaterialApp:
/// MaterialApp(
///   builder: InAppConsoleBuilder.builder,
///   home: MyHomePage(),
/// );
/// ```
///
/// You can also nest it with your own builder:
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     // Your own wrapping …
///     return InAppConsoleBuilder(child: child);
///   },
/// );
/// ```
///
/// ## Disabling in production
///
/// Wrap the builder assignment in a `kReleaseMode` guard:
/// ```dart
/// builder: kReleaseMode ? null : InAppConsoleBuilder.builder,
/// ```
class InAppConsoleBuilder extends StatefulWidget {
  const InAppConsoleBuilder({super.key, this.child});

  /// The widget subtree provided by [MaterialApp] — typically a [Navigator].
  final Widget? child;

  /// A [TransitionBuilder]-compatible static factory.
  ///
  /// Pass directly to [MaterialApp.builder]:
  /// ```dart
  /// MaterialApp(builder: InAppConsoleBuilder.builder)
  /// ```
  static Widget builder(BuildContext context, Widget? child) {
    return InAppConsoleBuilder(child: child);
  }

  @override
  State<InAppConsoleBuilder> createState() => _InAppConsoleBuilderState();
}

class _InAppConsoleBuilderState extends State<InAppConsoleBuilder> {
  bool _consoleOpen = false;

  void _toggleConsole() => setState(() => _consoleOpen = !_consoleOpen);
  void _closeConsole() => setState(() => _consoleOpen = false);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-size child (the app's Navigator / page stack).
        if (widget.child != null) Positioned.fill(child: widget.child!),
        // Inline console overlay — shown without a Navigator so it works
        // correctly from the MaterialApp.builder context.
        if (_consoleOpen)
          Positioned.fill(
            child: _InlineConsoleOverlay(onClose: _closeConsole),
          ),
        // Floating debug button — always on top.
        _DraggableConsoleButton(onTap: _toggleConsole),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline console overlay (no Navigator required)
// ─────────────────────────────────────────────────────────────────────────────

/// A full-screen overlay that hosts [ConsoleScreen] without relying on a
/// [Navigator].  Shown directly inside the [InAppConsoleBuilder] [Stack] so
/// that it works correctly even though the builder context sits above the
/// app's [Navigator].
class _InlineConsoleOverlay extends StatelessWidget {
  const _InlineConsoleOverlay({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Wrap in Overlay so that Tooltip, Scaffold internals, etc. can find
    // an OverlayState even though we're sitting above the app's Navigator.
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (_) => Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Scrim — tapping it closes the console.
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onClose,
                    child: const ColoredBox(color: Colors.black54),
                  ),
                ),
                // Console sheet — full constraints so DraggableScrollableSheet
                // can calculate its fraction-based height correctly.
                Positioned.fill(
                  child: ConsoleScreen(onClose: onClose),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draggable floating button
// ─────────────────────────────────────────────────────────────────────────────

/// A freely draggable floating button that opens [ConsoleScreen] on tap.
///
/// The button stays within the screen boundaries. Its size and opacity
/// respond in real-time to [ConsoleSettings].
///
/// Drag behavior:
/// - A short press (< 8 px of movement) is treated as a **tap** → opens the
///   console.
/// - Dragging (≥ 8 px) repositions the button without opening the console.
class _DraggableConsoleButton extends StatefulWidget {
  const _DraggableConsoleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DraggableConsoleButton> createState() =>
      _DraggableConsoleButtonState();
}

class _DraggableConsoleButtonState extends State<_DraggableConsoleButton> {
  /// Button's top-left corner relative to the [Stack]'s coordinate space.
  final _position = ValueNotifier<Offset>(const Offset(16, 120));

  // Drag state
  double _totalDragDistance = 0;
  bool _isDragging = false;

  // Threshold (in logical pixels) to distinguish tap from drag.
  static const double _dragThreshold = 8.0;

  void _onPanStart(DragStartDetails _) {
    _totalDragDistance = 0;
    _isDragging = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _totalDragDistance += details.delta.distance;

    if (_totalDragDistance >= _dragThreshold) {
      _isDragging = true;
    }

    if (_isDragging) {
      final size = MediaQuery.of(context).size;
      final btnSize = ConsoleSettings.instance.buttonSize.value;
      final current = _position.value;
      _position.value = Offset(
        (current.dx + details.delta.dx).clamp(0.0, size.width - btnSize),
        (current.dy + details.delta.dy).clamp(0.0, size.height - btnSize),
      );
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_isDragging) {
      // Treat as tap — delegate to the parent state to open the console.
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _position,
      builder: (context, offset, _) {
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: ValueListenableBuilder<double>(
            valueListenable: ConsoleSettings.instance.buttonOpacity,
            builder: (context, opacity, _) {
              return Opacity(
                opacity: opacity,
                child: ValueListenableBuilder<double>(
                  valueListenable: ConsoleSettings.instance.buttonSize,
                  builder: (context, btnSize, _) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: _ButtonFace(size: btnSize),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// The visual face of the floating console button.
class _ButtonFace extends StatelessWidget {
  const _ButtonFace({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: const Color(0xFF1A1A1A),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.bug_report,
              color: Colors.greenAccent,
              size: size * 0.48,
            ),
            // Subtle ring
            SizedBox.fromSize(
              size: Size(size, size),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha:0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
