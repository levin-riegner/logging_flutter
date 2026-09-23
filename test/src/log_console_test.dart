import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging_flutter/logging_flutter.dart';

Widget neutralApp(Widget home) => WidgetsApp(
  color: const Color(0xFF263238),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  home: home,
);

void main() {
  void resetWith(String text) {
    LogConsole.add(OutputEvent(Level.INFO, [text]), bufferSize: 1);
  }

  Future<String?> copyLogs(WidgetTester tester) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();
    return copied;
  }

  testWidgets('shows entries added while the console is open', (tester) async {
    resetWith('Initial');
    await tester.pumpWidget(neutralApp(LogConsole()));
    expect(find.textContaining('Initial'), findsOneWidget);

    LogConsole.add(OutputEvent(Level.WARNING, ['FreshEntry']));
    await tester.pump();

    expect(find.textContaining('FreshEntry'), findsOneWidget);
  });

  testWidgets('copies every filtered row with original case', (tester) async {
    resetWith('Case000');
    for (var index = 1; index < 80; index++) {
      LogConsole.add(
        OutputEvent(Level.INFO, ['Case${index.toString().padLeft(3, '0')}']),
        bufferSize: 100,
      );
    }
    await tester.pumpWidget(neutralApp(LogConsole()));

    final copied = await copyLogs(tester);

    expect(copied?.split('\n'), hasLength(80));
    expect(copied, contains('Case000'));
    expect(copied, contains('Case079'));
  });

  testWidgets('search applies to copied and displayed rows', (tester) async {
    resetWith('InfoAlpha');
    LogConsole.add(OutputEvent(Level.WARNING, ['WarningBeta']));
    LogConsole.add(OutputEvent(Level.INFO, ['InfoGamma']));
    await tester.pumpWidget(neutralApp(LogConsole()));

    await tester.enterText(find.byType(EditableText), 'BETA');
    await tester.pump();

    expect(find.textContaining('WarningBeta'), findsOneWidget);
    expect(find.textContaining('InfoAlpha'), findsNothing);
    expect(await copyLogs(tester), 'WarningBeta');
  });

  testWidgets('level filter and clear update the open console', (tester) async {
    resetWith('InfoOnly');
    LogConsole.add(OutputEvent(Level.WARNING, ['WarningOnly']));
    await tester.pumpWidget(neutralApp(LogConsole()));

    await tester.tap(find.text('DEBUG'));
    await tester.pump();
    await tester.tap(find.text('WARNING'));
    await tester.pump();

    expect(find.textContaining('InfoOnly'), findsNothing);
    expect(find.textContaining('WarningOnly'), findsOneWidget);
    expect(await copyLogs(tester), 'WarningOnly');

    LogConsole.clear();
    await tester.pump();
    expect(find.textContaining('WarningOnly'), findsNothing);
    expect(await copyLogs(tester), isEmpty);

    await tester.pumpWidget(const SizedBox());
    LogConsole.add(OutputEvent(Level.INFO, ['after dispose']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the buffer keeps only the requested number of entries', (
    tester,
  ) async {
    resetWith('Discarded');
    LogConsole.add(OutputEvent(Level.INFO, ['Retained']), bufferSize: 1);
    await tester.pumpWidget(neutralApp(LogConsole()));

    expect(find.textContaining('Discarded'), findsNothing);
    expect(await copyLogs(tester), 'Retained');
  });

  testWidgets('opens and closes without Material or Cupertino widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      neutralApp(
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => LogConsole.open(context, dark: true),
            child: const Text('Open console'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open console'));
    await tester.pumpAndSettle();
    expect(find.text('Log Console'), findsOneWidget);
    expect(find.byType(WidgetsApp), findsOneWidget);

    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();
    expect(find.text('Log Console'), findsNothing);
  });

  test('rejects a non-positive buffer size', () {
    expect(
      () => LogConsole.add(OutputEvent(Level.INFO, ['invalid']), bufferSize: 0),
      throwsArgumentError,
    );
  });
}
