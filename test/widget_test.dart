// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gnu_frontend/main.dart';

void main() {
  testWidgets('teacher dashboard is displayed at desktop size', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TeacherDashboard())));

    expect(find.text('Tableau de bord Enseignant — Synthèse Annuelle 2024–2025'), findsOneWidget);
    expect(find.text('Unités d’Enseignement'), findsOneWidget);

  });
}
