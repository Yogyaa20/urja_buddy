import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:urja_buddy/main.dart';

void main() {
  // Setup Hive for the test environment
  setUpAll(() async {
    // Creates a temporary directory for Hive to store test data
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame within a ProviderScope.
    // ProviderScope is required because your app uses Riverpod.
    await tester.pumpWidget(
      const ProviderScope(
        child: UrjaBuddyApp(),
      ),
    );

    // pumpAndSettle waits for all animations and scheduled tasks (like Hive opening) to finish
    await tester.pumpAndSettle();

    // Verify that the app builds and shows the main app widget
    expect(find.byType(UrjaBuddyApp), findsOneWidget);
  });
}