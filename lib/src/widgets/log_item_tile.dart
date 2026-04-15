// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/log_entry.dart';
import '../settings/console_settings.dart';

/// Maps a [LogLevel] to the accent color used in the console UI.
Color logLevelColor(LogLevel level) => switch (level) {
      LogLevel.verbose => Colors.grey.shade500,
      LogLevel.debug => Colors.lightBlue.shade400,
      LogLevel.info => Colors.green.shade400,
      LogLevel.warning => Colors.orange.shade400,
      LogLevel.error => Colors.red.shade400,
      LogLevel.network => Colors.purple.shade300,
    };

/// A single row in the log [ListView].
///
/// - Displays a colored level badge, a timestamp, and the message.
/// - Truncates message to 3 lines when collapsed; expands on tap.
/// - Auto-expands when [activeMatchCharPos] is non-null (active search match).
/// - Shows caller location (first stack frame) in dim gray below message.
/// - Long-press copies the entry text to the clipboard.
/// - The font size responds to [ConsoleSettings.logFontSize] in real-time.
class LogItemTile extends StatefulWidget {
  const LogItemTile({
    super.key,
    required this.entry,
    this.highlightQuery = '',
    this.activeMatchCharPos,
  });

  /// The log entry to display.
  final LogEntry entry;

  /// Text that should be highlighted in the message body.
  ///
  /// Pass an empty string (the default) when no search is active.
  final String highlightQuery;

  /// Character position of the currently active (green) match within
  /// [entry.message]. All other matches are shown in yellow.
  /// `null` means no active match in this entry.
  final int? activeMatchCharPos;

  @override
  State<LogItemTile> createState() => _LogItemTileState();
}

class _LogItemTileState extends State<LogItemTile> {
  /// Explicitly expanded/collapsed by the user via tap.
  bool _userExpanded = false;

  /// True when the tile should be in expanded state — either user expanded
  /// or the active search match is in this entry.
  bool get _isExpanded => _userExpanded || widget.activeMatchCharPos != null;

  void _toggleExpand() => setState(() => _userExpanded = !_userExpanded);

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(
      ClipboardData(text: widget.entry.toExportString()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log entry copied to clipboard'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  /// Extracts the first meaningful frame from a [StackTrace] string.
  ///
  /// Returns something like `MyClass.method (file.dart:42)` or `null`.
  String? _extractCallerLine(StackTrace? stackTrace) {
    if (stackTrace == null) return null;
    final lines = stackTrace.toString().split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') && trimmed.isNotEmpty) {
        // Strip leading "#N  " prefix (e.g. "#0  ")
        final withoutNum = trimmed.replaceFirst(RegExp(r'^#\d+\s+'), '');
        if (withoutNum.isNotEmpty) return withoutNum;
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(LogItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the active match moves to this tile, reset user-expanded so
    // the tile collapses again if the match later moves away.
    if (oldWidget.activeMatchCharPos != widget.activeMatchCharPos &&
        widget.activeMatchCharPos == null) {
      _userExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final color = logLevelColor(entry.level);
    final callerLine = _extractCallerLine(entry.stackTrace);
    final isExpanded = _isExpanded;

    return ValueListenableBuilder<double>(
      valueListenable: ConsoleSettings.instance.logFontSize,
      builder: (context, fontSize, _) {
        return GestureDetector(
          onTap: _toggleExpand,
          onLongPress: _copyToClipboard,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              border: Border(left: BorderSide(color: color, width: 3)),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Single line: badge  timestamp  message ───────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level badge
                    Text(
                      entry.level.label,
                      style: TextStyle(
                        fontSize: fontSize - 1,
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Timestamp
                    Text(
                      _formatTime(entry.timestamp),
                      style: TextStyle(
                        fontSize: fontSize - 1,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Message — takes all remaining space; max 3 lines when collapsed
                    Expanded(
                      child: _HighlightedText(
                        text: entry.message,
                        query: widget.highlightQuery,
                        activeMatchCharPos: widget.activeMatchCharPos,
                        maxLines: isExpanded ? null : 3,
                        style: TextStyle(
                          fontSize: fontSize - 1,
                          color: Colors.white.withValues(alpha: 0.87),
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ),
                    // Expand / collapse indicator — always visible
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
                // ── Caller location ──────────────────────────────────────────
                if (callerLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      callerLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize - 2,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                // ── Full stack trace (expanded) ──────────────────────────────
                if (isExpanded && entry.stackTrace != null)
                  Container(
                    margin: const EdgeInsetsGeometry.symmetric(vertical: 4),
                    padding: const EdgeInsetsGeometry.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        entry.stackTrace.toString(),
                        style: TextStyle(
                          fontSize: fontSize - 2,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helper: renders text with inline search-query highlights.
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.activeMatchCharPos,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle style;
  final int? activeMatchCharPos;

  /// When non-null, clips to this many lines with ellipsis overflow.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      final isActive = activeMatchCharPos == index;
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: isActive
              ? Colors.greenAccent.withValues(alpha: 0.7)
              : Colors.yellow.shade700.withValues(alpha: 0.5),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}
