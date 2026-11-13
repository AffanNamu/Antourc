import 'package:assistlink/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app fails closed when no backend URL is configured', (tester) async {
    await tester.pumpWidget(const AssistLinkApp());

    expect(find.text('Connect AssistLink to its server'), findsOneWidget);
    expect(find.textContaining('ASSISTLINK_API_BASE_URL'), findsOneWidget);
    expect(find.textContaining('does not ship with a hardcoded server'), findsOneWidget);
  });
}
