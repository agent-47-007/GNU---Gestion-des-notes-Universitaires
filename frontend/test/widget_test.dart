import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnu_frontend/main.dart';
import 'package:gnu_frontend/api_client.dart';
import 'package:gnu_frontend/domain.dart';
import 'package:gnu_frontend/dialogs.dart';
import 'package:gnu_frontend/features.dart';
import 'package:gnu_frontend/ui.dart';

void main() {
  testWidgets('accueil et entrée dans un espace explicite de démonstration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GnuApp(sessionStorage: _MemorySessionStorage()));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue sur GNU'), findsOneWidget);
    await tester.tap(find.text('Enseignant'));
    await tester.tap(find.text('Explorer cet espace démo'));
    await tester.pumpAndSettle();
    expect(find.text('Saisie des notes'), findsOneWidget);
    expect(find.text('Notes & bulletins'), findsNothing);
    expect(find.text('DÉMO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inscription étudiante affiche les validations avant l’appel réseau',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(GnuApp(sessionStorage: _MemorySessionStorage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connexion réelle étudiant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer un compte étudiant'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Créer mon compte'));
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Renseignez le nom, le prénom'),
        findsOneWidget,
      );
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
        final store = DemoStore();
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Portal(role: role, store: store, onExit: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final destination in destinations(role).skip(1)) {
          if (width < 1100) {
            await tester.tap(find.byTooltip('Ouvrir le menu'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.widgetWithText(ListTile, destination.label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: destination.label);
          expect(find.byType(FeaturePage), findsOneWidget);
        }
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
