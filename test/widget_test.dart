import 'package:flutter_test/flutter_test.dart';
import 'package:ai_phone_controller/main.dart';

void main() {
  testWidgets('shows the assistant title and text input', (tester) async {
    await tester.pumpWidget(const AiPhoneControllerApp());

    expect(find.text('AI Phone Controller'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Hi! I can currently open'), findsOneWidget);
  });
}
