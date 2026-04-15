// flutter_in_app_console — An in-app overlay debug console for Flutter.
//
// Quick start:
//   1. In main(): await ConsoleSettings.instance.load();
//                 ConsoleController.run(() async { ... runApp(...); });
//   2. In MaterialApp: builder: InAppConsoleBuilder.builder
//   3. Log anywhere:   ConsoleController.instance.log('msg', level: LogLevel.info);
//
// See README for full usage and production-mode guidance.

// Models
export 'src/models/log_entry.dart' show LogEntry, LogLevel, LogLevelX;

// Controller
export 'src/controllers/console_controller.dart' show ConsoleController;

// Settings
export 'src/settings/console_settings.dart' show ConsoleSettings;

// Widgets
export 'src/widgets/in_app_console_builder.dart' show InAppConsoleBuilder;
export 'src/widgets/console_screen.dart' show ConsoleScreen;