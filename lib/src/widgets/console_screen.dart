// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'package:flutter/material.dart';

import '../settings/console_settings.dart';
import 'log_list_tab.dart';
import 'settings_tab.dart';

/// The full console overlay screen.
///
/// Displayed as a bottom sheet that can be dragged to full screen.
/// Contains two tabs:
///   - **Logs** ([LogListTab]) — the captured log stream.
///   - **Settings** ([SettingsTab]) — live-adjustable UI preferences.
///
/// Open it programmatically with [ConsoleScreen.show]:
/// ```dart
/// ConsoleScreen.show(context);
/// ```
///
/// When used inline (outside of a Navigator), supply an [onClose] callback
/// that will be called instead of [Navigator.pop]:
/// ```dart
/// ConsoleScreen(onClose: () => setState(() => _open = false))
/// ```
class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key, this.onClose});

  /// Called when the user taps the close button.
  ///
  /// If `null`, [Navigator.of(context).pop()] is used — requires a
  /// [Navigator] ancestor (i.e. the widget must live inside the navigator
  /// tree, not in a [MaterialApp.builder] overlay).
  final VoidCallback? onClose;

  /// Shows the console as a [DraggableScrollableSheet] bottom sheet.
  ///
  /// The sheet starts at 90% of screen height and can be expanded to
  /// full-screen by dragging upward.
  ///
  /// [context] must have a [Navigator] ancestor (i.e. be called from inside
  /// the normal widget tree, not from a [MaterialApp.builder] overlay).
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const ConsoleScreen(),
    );
  }

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      snap: true,
      snapSizes: const [0.5, 0.9, 1.0],
      builder: (context, _) => _ConsoleShell(
        tabController: _tabController,
        onClose: widget.onClose,
      ),
    );
  }
}

/// Inner shell that hosts the [Scaffold] with tabs.
///
/// Kept separate from [ConsoleScreen] so the [DraggableScrollableSheet]
/// callback signature stays clean.
class _ConsoleShell extends StatelessWidget {
  const _ConsoleShell({required this.tabController, this.onClose});

  final TabController tabController;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final s = ConsoleSettings.instance;
    return ValueListenableBuilder<int>(
      valueListenable: s.consoleBgColorIndex,
      builder: (context, colorIdx, _) {
        return ValueListenableBuilder<double>(
          valueListenable: s.consoleBgOpacity,
          builder: (context, opacity, _) {
            final baseColor = Color(
              ConsoleSettings.consoleBgPresets[
                  colorIdx.clamp(0, ConsoleSettings.consoleBgPresets.length - 1)
              ],
            );
            final bgColor = baseColor.withValues(alpha: opacity);
            // AppBar: same color preset, slightly darker, same opacity.
            final appBarColor = Color.fromARGB(
              (opacity * 255).round(),
              (baseColor.r * 0.75).round(),
              (baseColor.g * 0.75).round(),
              (baseColor.b * 0.75).round(),
            );
            return _buildShell(context, bgColor, appBarColor);
          },
        );
      },
    );
  }

  Widget _buildShell(BuildContext context, Color bgColor, Color appBarColor) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          automaticallyImplyLeading: false,
          titleSpacing: 12,
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.greenAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'InApp Console',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              tooltip: 'Close console',
              onPressed: () =>
                onClose != null ? onClose!() : Navigator.of(context).pop(),
            ),
          ],
          bottom: TabBar(
            controller: tabController,
            indicatorColor: Colors.greenAccent,
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.terminal, size: 16),
                    SizedBox(width: 6),
                    Text('Logs', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 16),
                    SizedBox(width: 6),
                    Text('Settings', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: tabController,
          children: const [
            LogListTab(),
            SettingsTab(),
          ],
        ),
      ),
    );
  }
}
