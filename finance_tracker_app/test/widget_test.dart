import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_tracker_app/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: FinanceTrackerApp()));

    // Wait for any async operations
    await tester.pumpAndSettle();

    // Verify that the app title is displayed
    expect(find.text('Finance Tracker'), findsOneWidget);
  });
}
