import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiphonecontroller/main.dart';

const _channel = MethodChannel('com.example.aiphonecontroller/accessibility');

void _mockAndroidBridge(
  WidgetTester tester, {
  String accessibilityStatus = 'enabled',
  List<Map<String, Object?>> visibleElements = const [],
  List<String>? calls,
  Object? Function(MethodCall call)? override,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    calls?.add(call.method);
    if (override != null) return override(call);
    switch (call.method) {
      case 'confirmAction':
        return true;
      case 'launchAppByName':
      case 'clickElement':
      case 'enterText':
      case 'goBack':
      case 'goHome':
      case 'scrollScreen':
      case 'openSettingsPage':
        return true;
      case 'getAccessibilityStatus':
        return accessibilityStatus;
      case 'readVisibleElements':
        return visibleElements;
      case 'openAccessibilitySettings':
        return null;
      default:
        throw PlatformException(code: 'UNIMPLEMENTED', message: call.method);
    }
  });
}

void _clearAndroidBridge() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
}

void main() {
  tearDown(_clearAndroidBridge);

  testWidgets('renders all main controls and quick actions', (tester) async {
    await tester.pumpWidget(const AiPhoneControllerApp());

    expect(find.text('AI Controller'), findsOneWidget);
    expect(find.text('YOUR ON-DEVICE ASSISTANT'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('mic-button')), findsOneWidget);
    expect(find.textContaining('AI Phone Controller ready'), findsOneWidget);
    for (final app in ['chrome', 'youtube', 'settings', 'maps', 'calculator']) {
      expect(find.byKey(ValueKey('quick-$app')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('quick-read-screen')), findsOneWidget);
    expect(find.byTooltip('Accessibility settings'), findsOneWidget);
    expect(find.byTooltip('Read screen'), findsOneWidget);
  });

  testWidgets('all five app quick-action buttons request confirmation and launch', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(tester, calls: calls);
    await tester.pumpWidget(const AiPhoneControllerApp());

    for (final app in ['chrome', 'youtube', 'settings', 'maps', 'calculator']) {
      await tester.tap(find.byKey(ValueKey('quick-$app')));
      await tester.pumpAndSettle();
      expect(calls, contains('confirmAction'));
      expect(calls, contains('launchAppByName'));
    }
    expect(calls.where((call) => call == 'launchAppByName').length, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Read Screen toolbar button displays accessible elements and can tap a control', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(
      tester,
      calls: calls,
      visibleElements: [
        {'index': 0, 'label': 'Continue', 'clickable': true, 'editable': false, 'className': 'Button'},
        {'index': 1, 'label': 'Heading', 'clickable': false, 'editable': false, 'className': 'TextView'},
      ],
    );
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.tap(find.byTooltip('Read screen'));
    await tester.pumpAndSettle();
    expect(find.text('Visible elements (2)'), findsOneWidget);
    expect(find.text('0. Continue'), findsOneWidget);

    await tester.tap(find.text('0. Continue'));
    await tester.pumpAndSettle();
    expect(calls, contains('readVisibleElements'));
    expect(calls, contains('confirmAction'));
    expect(calls, contains('clickElement'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accessibility settings button shows enabled status', (tester) async {
    _mockAndroidBridge(tester, accessibilityStatus: 'enabled');
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.tap(find.byTooltip('Accessibility settings'));
    await tester.pumpAndSettle();

    expect(find.text('Accessibility service'), findsOneWidget);
    expect(find.textContaining('Enabled.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accessibility settings opens Android settings when service is disabled', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(tester, accessibilityStatus: 'disabled', calls: calls);
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.tap(find.byTooltip('Accessibility settings'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(calls, contains('openAccessibilitySettings'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('editable screen element opens text entry and confirms before entering', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(
      tester,
      calls: calls,
      visibleElements: [
        {'index': 3, 'label': 'Search', 'clickable': false, 'editable': true, 'className': 'EditText'},
      ],
    );
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.tap(find.byTooltip('Read screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3. Search'));
    await tester.pumpAndSettle();
    expect(find.text('Enter text'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'sample query');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(calls, contains('confirmAction'));
    expect(calls, contains('enterText'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel workflow control appears and cancels remaining steps', (tester) async {
    final calls = <String>[];
    final confirmation = Completer<Object?>();
    _mockAndroidBridge(
      tester,
      calls: calls,
      override: (call) {
        if (call.method == 'confirmAction') return confirmation.future;
        if (call.method == 'launchAppByName') return true;
        return null;
      },
    );
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'open Chrome then open Maps');
    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pump();

    expect(find.byTooltip('Cancel workflow'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel workflow'));
    await tester.pump();
    confirmation.complete(true);
    await tester.pumpAndSettle();

    expect(find.textContaining('Workflow cancellation requested.'), findsOneWidget);
    expect(calls.where((call) => call == 'launchAppByName').length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voice button uses the native on-device recognizer and submits recognized text', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(
      tester,
      calls: calls,
      override: (call) {
        if (call.method == 'startVoiceRecognition') return 'help';
        if (call.method == 'confirmAction') return true;
        return null;
      },
    );
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.tap(find.byKey(const ValueKey('mic-button')));
    await tester.pumpAndSettle();

    expect(calls, contains('startVoiceRecognition'));
    expect(find.text('help'), findsOneWidget);
    expect(find.textContaining('Commands:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home command confirms before leaving the current app', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(tester, calls: calls);
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'home');
    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pumpAndSettle();

    expect(calls, contains('confirmAction'));
    expect(calls, contains('goHome'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll command confirms and requests the chosen direction', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(tester, calls: calls);
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'scroll down');
    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pumpAndSettle();

    expect(calls, contains('confirmAction'));
    expect(calls, contains('scrollScreen'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings command opens only the selected settings page', (tester) async {
    final calls = <String>[];
    _mockAndroidBridge(tester, calls: calls);
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'settings wifi');
    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pumpAndSettle();

    expect(calls, contains('confirmAction'));
    expect(calls, contains('openSettingsPage'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('help command is sent and displays supported actions', (tester) async {
    await tester.pumpWidget(const AiPhoneControllerApp());

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'help');
    await tester.tap(find.byKey(const ValueKey('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('help'), findsOneWidget);
    expect(find.textContaining('Single actions:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(393, 852),
    const Size(412, 915),
    const Size(640, 360),
  ]) {
    testWidgets('layout fits viewport ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const AiPhoneControllerApp());
      await tester.pump();

      expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('send-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
