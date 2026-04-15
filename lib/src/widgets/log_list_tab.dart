// Copyright (c) 2025 in_app_console authors. BSD-style license.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/console_controller.dart';
import '../models/log_entry.dart';
import 'log_item_tile.dart';

/// The "Logs" tab inside the console overlay.
///
/// Features:
/// - Real-time list of all captured [LogEntry] items.
/// - Search bar with Up/Down navigation between matches.
/// - Filter chips to show only selected [LogLevel] categories.
/// - Clear and Export/Share action buttons.
class LogListTab extends StatefulWidget {
  const LogListTab({super.key});

  @override
  State<LogListTab> createState() => _LogListTabState();
}

class _LogListTabState extends State<LogListTab> {
  // ── Controllers & notifiers ────────────────────────────────────────────────
  final _controller = ConsoleController.instance;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  final _searchQuery = ValueNotifier<String>('');
  final _activeFilters = ValueNotifier<Set<LogLevel>>(
    Set<LogLevel>.from(LogLevel.values),
  );
  // Flat list of every occurrence: (filteredListIndex, charPositionInMessage).
  final _allOccurrences = ValueNotifier<List<(int, int)>>(const []);
  // Index into _allOccurrences that is currently highlighted.
  final _currentOccurrenceIdx = ValueNotifier<int>(-1);

  bool _confirmingClear = false;
  bool _searchPending = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller.logs.addListener(_onLogsChanged);
    _searchQuery.addListener(_rebuildMatches);
    _activeFilters.addListener(_onFiltersChanged);
    _currentOccurrenceIdx.addListener(_onOccurrenceChanged);
  }

  @override
  void dispose() {
    _controller.logs.removeListener(_onLogsChanged);
    _searchQuery.removeListener(_rebuildMatches);
    _activeFilters.removeListener(_onFiltersChanged);
    _currentOccurrenceIdx.removeListener(_onOccurrenceChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchQuery.dispose();
    _activeFilters.dispose();
    _allOccurrences.dispose();
    _currentOccurrenceIdx.dispose();
    super.dispose();
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  List<LogEntry> _filteredLogs() {
    final query = _searchQuery.value.toLowerCase();
    final filters = _activeFilters.value;
    return _controller.logs.value.where((e) {
      if (!filters.contains(e.level)) return false;
      if (query.isEmpty) return true;
      return e.message.toLowerCase().contains(query);
    }).toList();
  }

  /// Immediately applies the current text field value as the search query.
  void _applySearch() {
    _debounceTimer?.cancel();
    _searchQuery.value = _searchController.text;
    if (_searchPending) setState(() => _searchPending = false);
  }

  /// Called on every keystroke — starts/restarts the 1.5 s debounce timer.
  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    if (!_searchPending) setState(() => _searchPending = true);
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _searchQuery.value = text;
      if (mounted) setState(() => _searchPending = false);
    });
  }

  void _onLogsChanged() {
    if (mounted) setState(() {});
    _rebuildMatches();
  }

  void _onFiltersChanged() {
    if (mounted) setState(() {});
    _rebuildMatches();
  }

  void _onOccurrenceChanged() {
    if (mounted) setState(() {});
  }

  /// Builds a flat list of every query occurrence across all filtered entries.
  /// Each element is (filteredListIndex, charPositionInMessage).
  void _rebuildMatches() {
    if (!mounted) return;
    final query = _searchQuery.value.toLowerCase();
    if (query.isEmpty) {
      _allOccurrences.value = const [];
      _currentOccurrenceIdx.value = -1;
      return;
    }

    final filtered = _filteredLogs();
    final occs = <(int, int)>[];

    for (var i = 0; i < filtered.length; i++) {
      final msg = filtered[i].message.toLowerCase();
      var start = 0;
      while (true) {
        final pos = msg.indexOf(query, start);
        if (pos == -1) break;
        occs.add((i, pos));
        start = pos + query.length;
      }
    }

    _allOccurrences.value = occs;
    if (occs.isEmpty) {
      _currentOccurrenceIdx.value = -1;
    } else {
      _currentOccurrenceIdx.value = 0;
      _scrollToIndex(occs[0].$1);
    }
  }

  void _navigateMatch(int delta) {
    final occs = _allOccurrences.value;
    if (occs.isEmpty) return;
    final next =
        (_currentOccurrenceIdx.value + delta).clamp(0, occs.length - 1);
    _currentOccurrenceIdx.value = next;
    _scrollToIndex(occs[next].$1);
  }

  /// Scrolls to [index] in the filtered list using [Scrollable.ensureVisible]
  /// so variable-height items are handled correctly.
  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final filtered = _filteredLogs();
    if (index >= filtered.length) return;

    final key = GlobalObjectKey(filtered[index].id);

    void ensureVisible() {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.5, // centre the item in the viewport
      );
    }

    // If the item is already rendered, scroll to it directly.
    if (key.currentContext != null) {
      ensureVisible();
      return;
    }

    // Item is outside the rendered window — jump to a rough position first
    // so ListView builds the item, then fine-tune with ensureVisible.
    const estimatedItemHeight = 64.0;
    _scrollController.jumpTo(
      (index * estimatedItemHeight)
          .clamp(0.0, _scrollController.position.maxScrollExtent),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ensureVisible());
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _clearLogs() {
    setState(() => _confirmingClear = true);
  }

  void _confirmClear() {
    setState(() => _confirmingClear = false);
    _controller.clear();
  }

  void _cancelClear() {
    setState(() => _confirmingClear = false);
  }

  Future<void> _exportLogs() async {
    final logs = _filteredLogs();
    if (logs.isEmpty) return;

    final buffer = StringBuffer(
      '=== InAppConsole Export — ${DateTime.now().toIso8601String()} ===\n\n',
    );
    for (final entry in logs) {
      buffer
        ..writeln(entry.toExportString())
        ..writeln();
    }

    try {
      await Share.share(
        buffer.toString(),
        subject: 'App Logs ${DateTime.now().toIso8601String()}',
      );
    } catch (_) {
      // Fallback: copy to clipboard when share sheet is unavailable.
      await _copyLogsToClipboard(buffer.toString());
    }
  }

  Future<void> _copyLogsToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Logs copied to clipboard');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs();

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        _SearchBar(
          controller: _searchController,
          allOccurrences: _allOccurrences,
          currentOccurrenceIdx: _currentOccurrenceIdx,
          onChanged: _onSearchChanged,
          onSearch: _applySearch,
          searchPending: _searchPending,
          onClear: () {
            _debounceTimer?.cancel();
            _searchController.clear();
            _searchQuery.value = '';
            if (_searchPending) setState(() => _searchPending = false);
          },
          onUp: () => _navigateMatch(-1),
          onDown: () => _navigateMatch(1),
        ),

        // ── Filter checkboxes ───────────────────────────────────────────────
        _FilterCheckboxes(activeFilters: _activeFilters),

        const Divider(height: 1, color: Colors.white12),

        // ── Log list ─────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final curIdx = _currentOccurrenceIdx.value;
                    final occs = _allOccurrences.value;
                    int? activeCharPos;
                    if (curIdx >= 0 &&
                        curIdx < occs.length &&
                        occs[curIdx].$1 == index) {
                      activeCharPos = occs[curIdx].$2;
                    }
                    return LogItemTile(
                      key: GlobalObjectKey(filtered[index].id),
                      entry: filtered[index],
                      highlightQuery: _searchQuery.value,
                      activeMatchCharPos: activeCharPos,
                    );
                  },
                ),
        ),

        const Divider(height: 1, color: Colors.white12),

        // ── Clear confirmation / Action bar ──────────────────────────────────
        if (_confirmingClear)
          _ClearConfirmBar(onConfirm: _confirmClear, onCancel: _cancelClear)
        else
          _ActionBar(
            logCount: filtered.length,
            onClear: _clearLogs,
            onExport: _exportLogs,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Search input with match count and Up / Down navigation.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.allOccurrences,
    required this.currentOccurrenceIdx,
    required this.onChanged,
    required this.onSearch,
    required this.searchPending,
    required this.onClear,
    required this.onUp,
    required this.onDown,
  });

  final TextEditingController controller;
  final ValueNotifier<List<(int, int)>> allOccurrences;
  final ValueNotifier<int> currentOccurrenceIdx;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearch;
  final bool searchPending;
  final VoidCallback onClear;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSearch(),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search logs…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white38),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: Colors.white38,
                        onPressed: onClear,
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha:0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Search button
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            color: Colors.greenAccent,
            tooltip: 'Search',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onSearch,
          ),
          // Match count + navigation
          ValueListenableBuilder<List<(int, int)>>(
            valueListenable: allOccurrences,
            builder: (context, occs, _) {
              if (occs.isEmpty) return const SizedBox.shrink();
              return ValueListenableBuilder<int>(
                valueListenable: currentOccurrenceIdx,
                builder: (context, current, _) {
                  return Row(
                    children: [
                      const SizedBox(width: 6),
                      Text(
                        '${current + 1}/${occs.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                        color: Colors.white54,
                        onPressed: onUp,
                        tooltip: 'Previous match',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        color: Colors.white54,
                        onPressed: onDown,
                        tooltip: 'Next match',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
        ),
        // Progress indicator while debounce timer is running
        SizedBox(
          height: 2,
          child: searchPending
              ? const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: Colors.greenAccent,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Horizontal row of [LogLevel] filter checkboxes.
class _FilterCheckboxes extends StatelessWidget {
  const _FilterCheckboxes({required this.activeFilters});

  final ValueNotifier<Set<LogLevel>> activeFilters;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<LogLevel>>(
      valueListenable: activeFilters,
      builder: (context, active, _) {
        final allSelected = active.length == LogLevel.values.length;
        return SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              // "ALL" toggle
              _CheckItem(
                label: 'ALL',
                color: Colors.white70,
                checked: allSelected,
                onTap: () {
                  activeFilters.value = allSelected
                      ? {}
                      : Set<LogLevel>.from(LogLevel.values);
                },
              ),
              const _Divider(),
              // Per-level checkboxes
              ...LogLevel.values.map((level) {
                final isActive = active.contains(level);
                return _CheckItem(
                  label: level.label,
                  color: logLevelColor(level),
                  checked: isActive,
                  onTap: () {
                    final next = Set<LogLevel>.from(active);
                    isActive ? next.remove(level) : next.add(level);
                    activeFilters.value = next;
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.color,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                activeColor: color,
                checkColor: Colors.black,
                side: BorderSide(
                  color: checked ? color : Colors.white24,
                  width: 1.5,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: checked ? color : Colors.white38,
                fontWeight: checked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.only(right: 10),
      color: Colors.white12,
    );
  }
}

/// Bottom action bar: log count, Clear, and Export buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.logCount,
    required this.onClear,
    required this.onExport,
  });

  final int logCount;
  final VoidCallback onClear;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 6, 12, 6 + bottomInset),
      child: Row(
        children: [
          Text(
            '$logCount ${logCount == 1 ? 'entry' : 'entries'}',
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade300,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: logCount > 0 ? onExport : null,
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Export'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.greenAccent,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline confirmation bar shown instead of the action bar when the user
/// taps "Clear". Avoids [showDialog] which requires a [Navigator] ancestor.
class _ClearConfirmBar extends StatelessWidget {
  const _ClearConfirmBar({required this.onConfirm, required this.onCancel});

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF2A1A1A),
      padding: EdgeInsets.fromLTRB(12, 6, 12, 6 + bottomInset),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Clear all logs?',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white54,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: onConfirm,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade300,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Shown when the filtered log list is empty.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terminal, size: 48, color: Colors.white12),
          SizedBox(height: 12),
          Text(
            'No logs yet',
            style: TextStyle(color: Colors.white24, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Use debugPrint(), print(), or\nConsoleController.instance.log()',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white12, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
