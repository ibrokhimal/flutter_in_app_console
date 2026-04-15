// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'package:flutter/material.dart';

import '../settings/console_settings.dart';

/// The Settings tab shown inside the console overlay.
///
/// All changes are reflected instantly in the UI via [ValueNotifier] and
/// automatically persisted to [SharedPreferences].
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ConsoleSettings.instance;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Floating Button section ──────────────────────────────────────────
        const _SectionHeader(title: 'Floating Button'),
        const SizedBox(height: 8),
        _SliderTile<double>(
          label: 'Button Size',
          notifier: s.buttonSize,
          min: 32,
          max: 96,
          divisions: 32,
          valueLabel: (v) => '${v.round()} px',
        ),
        const SizedBox(height: 4),
        _SliderTile<double>(
          label: 'Button Opacity',
          notifier: s.buttonOpacity,
          min: 0.1,
          max: 1.0,
          divisions: 18,
          valueLabel: (v) => '${(v * 100).round()}%',
        ),

        const SizedBox(height: 20),

        // ── Console Background section ───────────────────────────────────────
        const _SectionHeader(title: 'Console Background'),
        const SizedBox(height: 8),
        _ColorPresetPicker(
          label: 'Background Color',
          notifier: s.consoleBgColorIndex,
          presets: ConsoleSettings.consoleBgPresets,
        ),
        const SizedBox(height: 4),
        _SliderTile<double>(
          label: 'Background Opacity',
          notifier: s.consoleBgOpacity,
          min: 0.5,
          max: 1.0,
          divisions: 10,
          valueLabel: (v) => '${(v * 100).round()}%',
        ),

        const SizedBox(height: 20),

        // ── Console Log section ──────────────────────────────────────────────
        const _SectionHeader(title: 'Console Log'),
        const SizedBox(height: 8),
        _SliderTile<double>(
          label: 'Log Font Size',
          notifier: s.logFontSize,
          min: 10,
          max: 24,
          divisions: 14,
          valueLabel: (v) => '${v.round()} sp',
        ),

        const SizedBox(height: 32),

        // ── Live preview ─────────────────────────────────────────────────────
        const _SectionHeader(title: 'Button Preview'),
        const SizedBox(height: 12),
        const _ButtonPreview(),

        const SizedBox(height: 32),

        // ── Reset button ─────────────────────────────────────────────────────
        Center(
          child: OutlinedButton.icon(
            onPressed: s.resetToDefaults,
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Defaults'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// A row of color swatches that sets a preset index on a [ValueNotifier<int>].
class _ColorPresetPicker extends StatelessWidget {
  const _ColorPresetPicker({
    required this.label,
    required this.notifier,
    required this.presets,
  });

  final String label;
  final ValueNotifier<int> notifier;
  final List<int> presets;

  static const _names = ['Black', 'Blue', 'Purple', 'Green', 'Amber'];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, selected, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(presets.length, (i) {
                final color = Color(presets[i]);
                final isSelected = i == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => notifier.value = i,
                    child: Tooltip(
                      message: _names[i],
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.greenAccent
                                : Colors.white24,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withValues(
                                        alpha: 0.4),
                                    blurRadius: 6,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.greenAccent)
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

/// A labeled slider that is bound to a [ValueNotifier<double>].
///
/// Changes the notifier value in real-time as the user drags.
class _SliderTile<T> extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.notifier,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
  });

  final String label;
  final ValueNotifier<double> notifier;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) valueLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  valueLabel(value),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.greenAccent.shade400,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.greenAccent,
                overlayColor: Colors.greenAccent.withValues(alpha:0.2),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: (v) => notifier.value = v,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Live preview of the floating button as settings change.
class _ButtonPreview extends StatelessWidget {
  const _ButtonPreview();

  @override
  Widget build(BuildContext context) {
    final s = ConsoleSettings.instance;

    return Center(
      child: ValueListenableBuilder<double>(
        valueListenable: s.buttonOpacity,
        builder: (context, opacity, _) {
          return Opacity(
            opacity: opacity,
            child: ValueListenableBuilder<double>(
              valueListenable: s.buttonSize,
              builder: (context, size, _) {
                return Material(
                  elevation: 6,
                  shape: const CircleBorder(),
                  color: const Color(0xFF1E1E1E),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Icon(
                      Icons.bug_report,
                      color: Colors.greenAccent,
                      size: size * 0.5,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
