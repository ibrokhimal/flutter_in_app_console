## 0.1.0

Initial release.

### Features

- **Overlay button** — draggable floating bug-icon button injected via `MaterialApp.builder`; tap to open/close the console, drag to reposition.
- **Log capture** — intercepts `print()` and `debugPrint()` calls via `runZonedGuarded`; zone errors are captured automatically at `LogLevel.error`.
- **`logger` package integration** — parses `PrettyPrinter` multi-line blocks (┌/│/├/└) into single entries with correct level detection via emoji markers, ANSI codes, and bracket prefixes (`[E]`, `[W]`, `[D]`, …).
- **Six log levels** — `verbose`, `debug`, `info`, `warning`, `error`, `network` — each color-coded in the UI.
- **Search** — real-time search with 1.5 s debounce, immediate trigger on button tap or keyboard Enter/Done. Per-occurrence navigation (↑/↓) with green/yellow highlights. Match count shown as `current/total`.
- **Filter checkboxes** — toggle individual log levels or ALL at once.
- **Log item tile** — level badge + timestamp + message on one line; collapses to 3 lines, expands on tap or when it contains the active search match; shows caller location (first stack frame) in dim gray; long-press copies the entry to clipboard.
- **Export / Share** — shares all visible (filtered) logs via `share_plus`; falls back to clipboard when share sheet is unavailable.
- **Settings tab** — live-adjustable, persisted via `SharedPreferences`:
  - Floating button size (32–96 px) and opacity (10–100 %).
  - Console background color (5 presets) and opacity (50–100 %).
  - Log font size (10–24 sp).
  - "Reset to Defaults" button.
- **`ConsoleScreen.show(context)`** — open the console programmatically from anywhere inside the Navigator tree.
