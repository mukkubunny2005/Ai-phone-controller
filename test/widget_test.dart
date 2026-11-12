import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiphonecontroller/main.dart';

void main() {
  testWidgets('renders the redesigned assistant chat and controls', (tester) async {
    await tester.pumpWidget(const AiPhoneControllerApp());

    expect(find.text('AI Controller'), findsOneWidget);
    expect(find.text('YOUR ON-DEVICE ASSISTANT'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
    expect(find.textContaining('AI Phone Controller ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-chrome')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-read-screen')), findsOneWidget);
    expect(find.byTooltip('Accessibility settings'), findsOneWidget);
    expect(find.byTooltip('Read screen'), findsOneWidget);
  });

  testWidgets('does not overflow on a compact phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AiPhoneControllerApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
  });

  testWidgets('sends the help command and displays the supported actions', (tester) async {
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'help');
    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('help'), findsOneWidget);
    expect(find.textContaining('Single actions:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
