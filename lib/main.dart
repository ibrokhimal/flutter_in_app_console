// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_in_app_console/flutter_in_app_console.dart';

/// ============================================================
///  flutter_in_app_console — Example App
/// ============================================================
///
/// How to use:
///   1. Run the app.
///   2. Tap the green bug-icon button (draggable — move it anywhere).
///   3. The console slides up with all captured logs.
///   4. Use the search bar, filter chips, and Up/Down arrows.
///   5. Open "Settings" tab to adjust button size / opacity / font.
/// ============================================================

void main() {
  // ensureInitialized() and any async setup must run inside ConsoleController.run
  // so they share the same zone as runApp — avoids "Zone mismatch" assertion.
  ConsoleController.run(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load persisted settings (button size, opacity, font size).
    await ConsoleSettings.instance.load();

    runApp(const ExampleApp());
  });
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InAppConsole Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      // ──────────────────────────────────────────────────────────────
      // Inject the console overlay here.  A single line of code.
      // ──────────────────────────────────────────────────────────────
      builder: kDebugMode ? InAppConsoleBuilder.builder : null,
      home: const HomePage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo Home Page
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InAppConsole Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tap a button to generate a log.\n'
            'Then tap the green bug button to open the console.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 24),
          _LogButton(
            label: 'Log Verbose',
            color: Colors.grey,
            onTap: () => ConsoleController.instance.log(
              'Verbose trace: entering HomePage.build()',
              level: LogLevel.verbose,
            ),
          ),
          _LogButton(
            label: 'Log Debug (via debugPrint)',
            color: Colors.lightBlue,
            onTap: () => debugPrint('Widget rebuilt — counter updated'),
          ),
          _LogButton(
            label: 'Log Info (via print)',
            color: Colors.green,
            onTap: () => print('User tapped the Info button at ${DateTime.now()}'),
          ),
          _LogButton(
            label: 'Log Warning',
            color: Colors.orange,
            onTap: () => ConsoleController.instance.log(
              'Deprecated API call detected in WidgetX',
              level: LogLevel.warning,
            ),
          ),
          _LogButton(
            label: 'Log Error + Stack Trace',
            color: Colors.red,
            onTap: () {
              try {
                throw Exception('Simulated error: connection refused');
              } catch (e, st) {
                ConsoleController.instance.log(
                  e.toString(),
                  level: LogLevel.error,
                  stackTrace: st,
                );
              }
            },
          ),
          _LogButton(
            label: 'Log Network',
            color: Colors.purple,
            onTap: () => ConsoleController.instance.log(
              'GET /api/v1/users → 200 OK (142 ms, 4.2 KB)',
              level: LogLevel.network,
            ),
          ),
          const SizedBox(height: 24),
          _LogButton(
            label: 'Spam 20 logs',
            color: Colors.teal,
            onTap: () {
              for (var i = 1; i <= 20; i++) {
                final level = LogLevel.values[i % LogLevel.values.length];
                ConsoleController.instance.log(
                  'Bulk log entry #$i — level ${level.name}',
                  level: level,
                );
              }
            },
          ),
          _LogButton(
            label: 'Clear all logs',
            color: Colors.red.shade700,
            onTap: ConsoleController.instance.clear,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'You can also open the console programmatically:',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ConsoleScreen.show(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Console'),
          ),
        ],
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha:0.2),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha:0.6)),
          alignment: Alignment.centerLeft,
        ),
        child: Text(label),
      ),
    );
  }
}
