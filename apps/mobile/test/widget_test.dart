import 'package:assistlink/src/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('home explains the real consent model and honest build status', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AssistLinkApp()));

    expect(find.text('AssistLink'), findsOneWidget);
    expect(find.text('Remote help,\nwith permission.'), findsOneWidget);
    expect(find.text('New call'), findsOneWidget);
    expect(find.text('Share screen during a call'), findsOneWidget);
    expect(find.textContaining('not connected yet'), findsOneWidget);
  });
}
