// Basic smoke test for SmartLogiChain.

import 'package:flutter_test/flutter_test.dart';

import 'package:meridian/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MeridianApp());
    await tester.pumpAndSettle();

    // Verify the bottom nav renders with all 5 tabs.
    expect(find.text('Command'), findsOneWidget);
    expect(find.text('Shipments'), findsOneWidget);
    expect(find.text('Copilot'), findsOneWidget);
    expect(find.text('Simulate'), findsOneWidget);
    expect(find.text('Impact'), findsOneWidget);
  });
}
