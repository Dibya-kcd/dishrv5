// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dishr/main.dart';
import 'package:provider/provider.dart';
import 'package:dishr/providers/restaurant_provider.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => RestaurantProvider()),
        ],
        child: const RestoPOSApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
