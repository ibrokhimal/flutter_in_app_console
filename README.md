# flutter_in_app_console

An in-app overlay debug console for Flutter.  
Drop it into any app with **one line of code** and get a searchable, filterable, color-coded log viewer without leaving the device.

---

## Features

- **Draggable floating button** — always visible, never blocks your UI.
- **Captures everything** — intercepts `print()`, `debugPrint()`, and uncaught zone errors automatically.
- **`logger` package support** — parses `PrettyPrinter` output (emoji markers, ANSI colors, multi-line blocks) into correctly leveled entries.
- **Six log levels** — `verbose`, `debug`, `info`, `warning`, `error`, `network` — each color-coded.
- **Search** with per-occurrence navigation and green/yellow highlights.
- **Filter** by log level with checkboxes.
- **Expandable tiles** — messages collapse to 3 lines; tap or navigate to expand. Caller location shown in dim gray.
- **Export / Share** logs via the system share sheet.
- **Customizable** — button size, button opacity, console background color & opacity, log font size — all persisted across restarts.

---

## Getting started

### 1. Add the dependency

```yaml
dependencies:
  flutter_in_app_console: ^0.1.0
```

### 2. Wrap your `main()` with `ConsoleController.run`

```dart
void main() {
  ConsoleController.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ConsoleSettings.instance.load(); // load persisted settings
    runApp(const MyApp());
  });
}
```

> `ConsoleController.run` starts a `runZonedGuarded` zone so that every
> `print()` call (including output from the `logger` package) is captured
> automatically. `ensureInitialized()` and any `async` setup **must** live
> inside the callback so they run in the same zone as `runApp`.

### 3. Inject the overlay

```dart
MaterialApp(
  // Show the console only in debug builds:
  builder: kDebugMode ? InAppConsoleBuilder.builder : null,
  home: const MyHomePage(),
)
```

That's it. A green bug icon appears on screen — tap it to open the console.

---

## Usage

### Manual logging

```dart
import 'package:flutter_in_app_console/flutter_in_app_console.dart';

ConsoleController.instance.log('User signed in', level: LogLevel.info);
ConsoleController.instance.log('GET /api/users → 200 OK', level: LogLevel.network);
ConsoleController.instance.log(
  'Something broke',
  level: LogLevel.error,
  stackTrace: stackTrace,
);
```

`print()` and `debugPrint()` are captured automatically when using
`ConsoleController.run`.

### Integration with the `logger` package

Create a custom `LogOutput` in your app:

```dart
class InAppConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    ConsoleController.instance.log(
      event.lines.join('\n'),
      level: switch (event.level) {
        Level.trace   => LogLevel.verbose,
        Level.debug   => LogLevel.debug,
        Level.warning => LogLevel.warning,
        Level.error   => LogLevel.error,
        Level.fatal   => LogLevel.error,
        _             => LogLevel.info,
      },
    );
  }
}

final logger = Logger(
  output: MultiOutput([ConsoleOutput(), InAppConsoleOutput()]),
);
```

### Open the console programmatically

```dart
// From anywhere inside the Navigator tree:
ConsoleScreen.show(context);
```

### Disable in production

```dart
builder: kReleaseMode ? null : InAppConsoleBuilder.builder,
```

---

## Additional information

- **Issues / feature requests:** file them on the [GitHub issue tracker](https://github.com/ibrokhimal/flutter_in_app_console/issues).
- **Contributing:** PRs are welcome. Please open an issue first to discuss significant changes.
- **License:** BSD 3-Clause — see [LICENSE](LICENSE).
