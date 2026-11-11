import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiphonecontroller/main.dart';

void main() {
  testWidgets('shows the assistant title, input and workflow help', (tester) async {
    await tester.pumpWidget(const AiPhoneControllerApp());

    expect(find.text('AI Phone Controller'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('AI Phone Controller ready'), findsOneWidget);
    expect(find.textContaining('open Chrome then read screen'), findsOneWidget);
  });
}
