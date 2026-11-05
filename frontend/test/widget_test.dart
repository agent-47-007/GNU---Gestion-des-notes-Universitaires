import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnu_frontend/main.dart';
import 'package:gnu_frontend/api_client.dart';
import 'package:gnu_frontend/domain.dart';
import 'package:gnu_frontend/dialogs.dart';
import 'package:gnu_frontend/features.dart';
import 'package:gnu_frontend/ui.dart';

void main() {
  testWidgets('accueil dirige vers la connexion étudiante réelle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GnuApp(sessionStorage: _MemorySessionStorage()));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue sur GNU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'aucune inscription libre n’est proposée',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(GnuApp(sessionStorage: _MemorySessionStorage()));
      await tester.pumpAndSettle();
      expect(find.text('Créer un compte étudiant'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 1440.0]) {
    for (final role in UserRole.values) {
      testWidgets('navigation ${role.name} à $width pixels sans débordement', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          GnuApp(sessionStorage: _MemorySessionStorage()),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Bienvenue sur GNU'), findsOneWidget);
      });
    }
  }

  testWidgets('requête absence : message et preuve obligatoires', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = DemoStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: RequestDialog(store: store)),
      ),
    );
    await tester.tap(find.text('Soumettre la requête'));
    await tester.pumpAndSettle();
    expect(
      find.text('Précisez votre demande en au moins 15 caractères.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextFormField),
      'Je souhaite justifier mon absence à cette évaluation.',
    );
    await tester.tap(find.text('Vérification de note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Absence justifiée').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soumettre la requête'));
    await tester.pumpAndSettle();
    expect(
      find.text('Joignez une preuve pour justifier cette absence.'),
      findsOneWidget,
    );
    expect(store.requests.length, 1);
  });
}

class _MemorySessionStorage implements SessionStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
