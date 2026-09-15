import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnu_frontend/grade_draft_store.dart';
import 'package:gnu_frontend/grade_entry_model.dart';
import 'package:gnu_frontend/main.dart';

class TestDraftStore implements GradeDraftStore {
  String? value;
  bool failWrite = false;
  @override
  String get locationLabel => 'ce test';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('Stockage indisponible');
    this.value = value;
  }
}

GradeEntryBook completeBook() {
  final book = GradeEntryBook.demo();
  for (final unit in book.units) {
    for (final ec in unit.elements) {
      for (final student in book.students) {
        for (final evaluation in ec.evaluations) {
          book.updateNote(ec.id, student.id, evaluation.id, '12');
        }
      }
    }
  }
  return book;
}

Future<void> openPage(WidgetTester tester,
    {GradeEntryBook? book,
    TestDraftStore? store,
    Size size = const Size(1440, 1100)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
      home: GradeEntryPage(book: book, store: store ?? TestDraftStore())));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder action(String name) => find.byKey(ValueKey(name));
Finder cell(String ec, String student, String evaluation) =>
    find.byKey(ValueKey('note-$ec-$student-$evaluation'));

void main() {
  testWidgets('la saisie incomplète bloque validation et transmission',
      (tester) async {
    await openPage(tester);
    expect(tester.widget<FilledButton>(action('validate-entry')).onPressed,
        isNull);
    expect(
        tester.widget<FilledButton>(action('submit-entry')).onPressed, isNull);
    expect(find.textContaining('Finalisation bloquée'), findsOneWidget);
    expect(find.text('18 / 21'), findsOneWidget);
    final empty = cell('inf301-ec1', '21U2118', 'sn');
    await tester.ensureVisible(empty);
    await tester.enterText(empty, '0');
    await tester.pumpAndSettle();
    expect(find.text('19 / 21'), findsOneWidget);
    expect(tester.widget<FilledButton>(action('validate-entry')).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'valider ne transmet pas et une modification exige une revalidation',
      (tester) async {
    await openPage(tester, book: completeBook());
    await tapVisible(tester, action('validate-entry'));
    expect(find.text('Saisie validée · Non transmise'), findsOneWidget);
    expect(tester.widget<FilledButton>(action('submit-entry')).onPressed,
        isNotNull);
    final note = cell('inf301-ec1', '21U2094', 'cc');
    await tester.ensureVisible(note);
    await tester.enterText(note, '20,01');
    await tester.pumpAndSettle();
    expect(find.text('Brouillon · À vérifier'), findsOneWidget);
    expect(find.text('Note invalide'), findsOneWidget);
    expect(tester.widget<FilledButton>(action('validate-entry')).onPressed,
        isNull);
    expect(
        tester.widget<FilledButton>(action('submit-entry')).onPressed, isNull);
  });

  testWidgets(
      'la transmission simulée demande une confirmation et verrouille cet EC',
      (tester) async {
    final book = completeBook();
    await openPage(tester, book: book);
    await tapVisible(tester, action('validate-entry'));
    await tapVisible(tester, action('submit-entry'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(book.status('inf301-ec1'), GradeEntryStatus.validated);
    await tapVisible(tester, action('submit-entry'));
    await tester.tap(find.text('Confirmer la simulation'));
    await tester.pumpAndSettle();
    expect(
        find.text('Transmission simulée · Aucun envoi réel'), findsOneWidget);
    expect(book.status('inf301-ec2'), GradeEntryStatus.draft);
    expect(
        tester
            .widget<TextFormField>(cell('inf301-ec1', '21U2094', 'cc'))
            .enabled,
        isFalse);
    await tapVisible(tester, find.text('Reprendre la saisie'));
    expect(book.status('inf301-ec1'), GradeEntryStatus.draft);
    expect(
        tester.widget<FilledButton>(action('submit-entry')).onPressed, isNull);
  });

  testWidgets('changer EC charge son plan et conserve la saisie du premier EC',
      (tester) async {
    await openPage(tester);
    final firstNote = cell('inf301-ec1', '21U2094', 'cc');
    await tester.ensureVisible(firstNote);
    await tester.enterText(firstNote, '13,75');
    await tester.pumpAndSettle();
    await tapVisible(tester, action('element-inf301-inf301-ec1'));
    await tester.tap(find.text('INF301-EC2 · Structures de données').last);
    await tester.pumpAndSettle();
    expect(find.text('CC · 30 %'), findsOneWidget);
    expect(find.text('SN · 70 %'), findsOneWidget);
    expect(find.text('TP · 30 %'), findsNothing);
    expect(
        tester
            .widget<TextFormField>(cell('inf301-ec2', '21U2094', 'cc'))
            .initialValue,
        '');
    expect(find.text('0 / 14'), findsOneWidget);
    await tapVisible(tester, action('element-inf301-inf301-ec2'));
    await tester.tap(find.text('INF301-EC1 · Algorithmique avancée').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(firstNote).initialValue, '13,75');
  });

  testWidgets('enregistrer puis rouvrir restaure les notes sans attestation',
      (tester) async {
    final store = TestDraftStore();
    final book = completeBook();
    await openPage(tester, book: book, store: store);
    final note = cell('inf301-ec1', '21U2094', 'cc');
    await tester.ensureVisible(note);
    await tester.enterText(note, '16,25');
    await tester.pumpAndSettle();
    await tapVisible(tester, action('validate-entry'));
    await tapVisible(tester, action('save-draft'));
    expect(store.value, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: GradeEntryPage(store: store)));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(note).initialValue, '16,25');
    expect(find.text('Brouillon · À vérifier'), findsOneWidget);
    expect(find.textContaining('Brouillon restauré'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(action('submit-entry')).onPressed, isNull);
  });

  testWidgets(
      'échec de sauvegarde conserve les modifications et avertit à la sortie',
      (tester) async {
    final store = TestDraftStore()..failWrite = true;
    await openPage(tester, store: store);
    final note = cell('inf301-ec1', '21U2094', 'cc');
    await tester.ensureVisible(note);
    await tester.enterText(note, '13');
    await tester.pumpAndSettle();
    await tapVisible(tester, action('save-draft'));
    expect(store.value, isNull);
    expect(find.textContaining('Enregistrement impossible'), findsOneWidget);
    expect(find.text('Modifications non enregistrées.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Unités d’enseignement'));
    await tester.pumpAndSettle();
    expect(find.text('Modifications non enregistrées'), findsOneWidget);
    await tester.tap(find.text('Rester sur la page'));
    await tester.pumpAndSettle();
    expect(find.byType(GradeEntryPage), findsOneWidget);
  });

  testWidgets('la page reste utilisable sur petit écran', (tester) async {
    await openPage(tester, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(action('save-draft'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
