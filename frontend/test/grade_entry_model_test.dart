import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnu_frontend/grade_entry_model.dart';

const _student = GradeStudent(
  id: 'student',
  matricule: 'MAT001',
  name: 'Étudiant de test',
  group: '',
);

GradeElement _element(String id,
        {int credits = 1,
        bool resit = false,
        List<GradeEvaluation>? evaluations}) =>
    GradeElement(
      id: id,
      code: id,
      title: id,
      credits: credits,
      evaluations: evaluations ??
          [
            GradeEvaluation(
                id: 'exam',
                code: 'EX',
                title: 'Examen',
                weight: 100,
                isResit: resit)
          ],
    );

GradeEntryBook _book({List<GradeElement>? elements, int unitCredits = 6}) =>
    GradeEntryBook(
      units: [
        GradeUnit(
            id: 'ue',
            code: 'UE',
            title: 'Unité de test',
            credits: unitCredits,
            elements: elements ?? [_element('ec')])
      ],
      students: const [_student],
      catalogId: 'test',
      programVersion: 'test-v1',
      classId: 'test-class',
      academicYear: '2024-2025',
    );

void _fill(GradeEntryBook book, String ecId, String value) {
  for (final student in book.students) {
    for (final evaluation in book.element(ecId).evaluations) {
      book.updateNote(ecId, student.id, evaluation.id, value);
    }
  }
}

void main() {
  group('Saisie de notes', () {
    test('zéro, absence et note manquante restent trois situations distinctes',
        () {
      expect(GradeNote.parse('0').kind, GradeNoteKind.numeric);
      expect(GradeNote.parse('0').value20, 0);
      expect(GradeNote.parse('   ').kind, GradeNoteKind.missing);
      expect(GradeNote.parse(' abs ').kind, GradeNoteKind.absent);
      expect(GradeNote.parse('ABS').value20, isNull);
      expect(GradeNote.parse(' 15,50 ').value20, 15.5);
      expect(GradeNote.parse('20.000').value20, 20);
      expect(GradeNote.parse('+12').value20, 12);
    });

    test('valeurs hors bornes, non finies et texte sont invalides', () {
      for (final raw in [
        '-0.01',
        '20.00000000000000000001',
        '21',
        'NaN',
        'Infinity',
        '-Infinity',
        '1e1',
        'INC',
        'absent',
        '12,3.4',
        '--',
        List.filled(41, '0').join()
      ]) {
        final note = GradeNote.parse(raw);
        expect(note.kind, GradeNoteKind.invalid, reason: raw);
        expect(note.error, isNotEmpty, reason: raw);
        expect(note.value20, isNull, reason: raw);
      }
    });

    test('les adresses hors étudiant, EC ou évaluation sont rejetées', () {
      final book = _book();
      expect(() => book.updateNote('other', 'student', 'exam', '10'),
          throwsArgumentError);
      expect(() => book.updateNote('ec', 'other', 'exam', '10'),
          throwsArgumentError);
      expect(() => book.updateNote('ec', 'student', 'other', '10'),
          throwsArgumentError);
    });
  });

  group('Calcul conforme aux fonctions SQL', () {
    test('conversion exacte de 0 et 20 vers 0 et 100', () {
      final book = _book();
      _fill(book, 'ec', '0');
      expect(book.ecResult('ec', 'student').score100, 0);
      expect(book.ueResult('ue', 'student').grade, 'F');
      expect(book.ecResult('ec', 'student').eliminated, isFalse);
      _fill(book, 'ec', '20');
      final result = book.ueResult('ue', 'student');
      expect(result.raw100, 100);
      expect(result.score100, 100);
      expect(result.rounded20, 20);
      expect(result.grade, 'A+');
      expect(result.points, 4);
    });

    test('les décimales sur une frontière entière ne gagnent pas un point', () {
      final book = _book(elements: [
        _element('ec', evaluations: const [
          GradeEvaluation(id: 'cc', code: 'CC', title: 'CC', weight: 20),
          GradeEvaluation(id: 'tp', code: 'TP', title: 'TP', weight: 30),
          GradeEvaluation(id: 'sn', code: 'SN', title: 'SN', weight: 50),
        ])
      ]);
      for (final row in <(String, int)>[
        ('0.2', 1),
        ('6.8', 34),
        ('7', 35),
        ('8.20', 41),
        ('10.2', 51),
        ('14.2', 71),
        ('14.8', 74),
        ('15', 75),
        ('20', 100),
      ]) {
        _fill(book, 'ec', row.$1);
        expect(book.ecResult('ec', 'student').score100, row.$2, reason: row.$1);
      }
    });

    test(
        'les décimales au-delà de la précision double sont arrondies exactement',
        () {
      final book = _book();
      _fill(book, 'ec', '14.80000000000000000000000001');
      expect(book.ecResult('ec', 'student').score100, 75);
      expect(book.ecResult('ec', 'student').grade, 'A−');
      _fill(book, 'ec', '14.79999999999999999999999999');
      expect(book.ecResult('ec', 'student').score100, 74);
      expect(book.ecResult('ec', 'student').grade, 'B+');
    });

    test('arrondi supérieur EC puis moyenne par crédits EC puis arrondi UE',
        () {
      // UE credits intentionally differ from the EC credit sum (6 versus 5).
      final book = _book(
          elements: [_element('ec1', credits: 3), _element('ec2', credits: 2)]);
      _fill(book, 'ec1', '10.02'); // 50.1 -> 51
      _fill(book, 'ec2', '10.22'); // 51.1 -> 52
      expect(book.ecResult('ec1', 'student').score100, 51);
      expect(book.ecResult('ec2', 'student').score100, 52);
      final result = book.ueResult('ue', 'student');
      expect(result.raw100, closeTo(51.4, 0.000001));
      expect(result.score100, 52);
      expect(result.grade, 'C');
    });

    test('un EC incomplet empêche un aperçu numérique de l’UE', () {
      final book = _book(elements: [_element('ec1'), _element('ec2')]);
      _fill(book, 'ec1', '15');
      final result = book.ueResult('ue', 'student');
      expect(result.complete, isFalse);
      expect(result.raw100, isNull);
      expect(result.score100, isNull);
      expect(result.grade, isNull);
      _fill(book, 'ec2', 'ABS');
      expect(book.ueResult('ue', 'student').complete, isFalse);
      _fill(book, 'ec2', '20.01');
      expect(book.ueResult('ue', 'student').complete, isFalse);
    });

    test('le seuil 35 porte sur le résultat UE arrondi', () {
      final book =
          _book(elements: [_element('ec1'), _element('ec2', credits: 2)]);
      _fill(book, 'ec1', '6.6'); // 33
      _fill(book, 'ec2', '7'); // 35, UE 34.333... -> 35
      expect(book.ueResult('ue', 'student').score100, 35);
      expect(book.ueResult('ue', 'student').belowAnnualThreshold, isFalse);
      _fill(book, 'ec2', '6.8'); // UE 33.666... -> 34
      final result = book.ueResult('ue', 'student');
      expect(result.score100, 34);
      expect(result.belowAnnualThreshold, isTrue);
      expect(result.grade, 'E');
      expect(result.points, 0);
      expect(result.eliminated, isFalse);
    });

    test('une note CC sous 7 ne produit jamais EL', () {
      final book = GradeEntryBook.demo();
      final result = book.ecResult('inf301-ec1', '21U2991');
      expect(result.raw20, closeTo(9.1, 0.000001));
      expect(result.score100, 46);
      expect(result.eliminated, isFalse);
      expect(result.grade, 'C−');
    });

    test('les exemples de la page utilisent le barème SQL après arrondi', () {
      final book = GradeEntryBook.demo();
      final abena = book.ecResult('inf301-ec1', '21U2094');
      expect(abena.raw100, 75.75);
      expect(abena.score100, 76);
      expect(abena.grade, 'A−');
      expect(book.ecResult('inf301-ec1', '21U3104').grade, 'A+');
      expect(book.ecResult('inf301-ec1', '21U2849').grade, 'B−');
    });

    test('toutes les bandes grades et points respectent leurs frontières', () {
      const bands = <(int, int, String, double)>[
        (0, 29, 'F', 0),
        (30, 34, 'E', 0),
        (35, 39, 'D−', 1),
        (40, 44, 'D+', 1.3),
        (45, 49, 'C−', 1.7),
        (50, 54, 'C', 2),
        (55, 59, 'C+', 2.3),
        (60, 64, 'B−', 2.7),
        (65, 69, 'B', 3),
        (70, 74, 'B+', 3.3),
        (75, 79, 'A−', 3.7),
        (80, 100, 'A+', 4),
      ];
      for (final band in bands) {
        for (var score = band.$1; score <= band.$2; score++) {
          expect(GradeResult.gradeForScore(score), band.$3, reason: '$score');
          expect(GradeResult.pointsForScore(score), band.$4, reason: '$score');
        }
      }
      for (final score in <int?>[null, -1, 101]) {
        expect(GradeResult.gradeForScore(score), isNull);
        expect(GradeResult.pointsForScore(score), isNull);
      }
    });

    test('absence normale bloque, absence explicite au rattrapage produit EL',
        () {
      final normal = _book();
      _fill(normal, 'ec', 'ABS');
      expect(normal.ecResult('ec', 'student').complete, isFalse);
      expect(normal.ecResult('ec', 'student').eliminated, isFalse);
      expect(normal.validateEc('ec'), isFalse);
      expect(normal.submitEc('ec'), isFalse);

      final resit = _book(elements: [_element('ec', resit: true)]);
      _fill(resit, 'ec', 'ABS');
      final result = resit.ueResult('ue', 'student');
      expect(result.complete, isTrue);
      expect(result.eliminated, isTrue);
      expect(result.score100, isNull);
      expect(result.grade, 'EL');
      expect(result.points, 0);
      expect(resit.validateEc('ec'), isTrue);
    });
  });

  group('Validation par EC et brouillons', () {
    test(
        'compteurs dynamiques séparent notes, absences, manquantes et invalides',
        () {
      final book = GradeEntryBook.demo();
      var summary = book.summary('inf301-ec1');
      expect(summary.total, 21);
      expect(summary.numeric, 18);
      expect(summary.missing, 2);
      expect(summary.absent, 1);
      expect(summary.invalid, 0);
      expect(summary.belowUeThreshold, 0); // Other EC has no grades yet.
      expect(summary.completionPercent, closeTo(18 * 100 / 21, 0.000001));
      book.updateNote('inf301-ec1', '21U2412', 'sn', '0');
      book.updateNote('inf301-ec1', '21U2118', 'sn', 'NaN');
      summary = book.summary('inf301-ec1');
      expect(summary.numeric, 19);
      expect(summary.missing, 0);
      expect(summary.invalid, 1);
      expect(book.validationIssues('inf301-ec1'), hasLength(2));
    });

    test(
        'soumission exige validation, modification et reprise exigent revalidation',
        () {
      final book = _book();
      expect(book.validateEc('ec'), isFalse);
      _fill(book, 'ec', '10');
      expect(book.submitEc('ec'), isFalse);
      expect(book.status('ec'), GradeEntryStatus.draft);
      expect(book.validateEc('ec'), isTrue);
      expect(book.status('ec'), GradeEntryStatus.validated);
      book.updateNote(
          'ec', 'student', 'exam', '10'); // Same value is not an edit.
      expect(book.status('ec'), GradeEntryStatus.validated);
      expect(book.submitEc('ec'), isTrue);
      expect(book.status('ec'), GradeEntryStatus.submitted);
      book.reopenEc('ec');
      expect(book.status('ec'), GradeEntryStatus.draft);
      expect(book.submitEc('ec'), isFalse);
      book.validateEc('ec');
      _fill(book, 'ec', '11');
      expect(book.status('ec'), GradeEntryStatus.draft);
      expect(book.submitEc('ec'), isFalse);
    });

    test('modifier un EC préserve notes et validation de l’autre EC', () {
      final book = _book(elements: [_element('ec1'), _element('ec2')]);
      _fill(book, 'ec1', '12');
      _fill(book, 'ec2', '15');
      book.validateEc('ec1');
      book.validateEc('ec2');
      book.submitEc('ec2');
      _fill(book, 'ec1', 'NaN');
      expect(book.status('ec1'), GradeEntryStatus.draft);
      expect(book.status('ec2'), GradeEntryStatus.submitted);
      expect(book.rawNote('ec2', 'student', 'exam'), '15');
      expect(book.validateEc('ec1'), isFalse);
    });

    test('validation de l’EC courant indépendante de complétude UE', () {
      final book = _book(elements: [_element('ec1'), _element('ec2')]);
      _fill(book, 'ec1', '12');
      expect(book.ueResult('ue', 'student').complete, isFalse);
      expect(book.validateEc('ec1'), isTrue);
      expect(book.submitEc('ec1'), isTrue);
      expect(book.status('ec2'), GradeEntryStatus.draft);
    });

    test('brouillon restaure saisies de tous les EC mais demande revalidation',
        () {
      final book = GradeEntryBook.demo();
      _fill(book, 'inf301-ec1', '12,50');
      _fill(book, 'inf301-ec2', '14');
      book.validateEc('inf301-ec1');
      book.submitEc('inf301-ec1');
      book.validateEc('inf301-ec2');
      book.updateNote('inf305-ec1', '21U2094', 'cc', 'NaN');
      final restored = GradeEntryBook.fromDraft(book.encodeDraft());
      expect(restored.rawNote('inf301-ec1', '21U2094', 'tp'), '12,50');
      expect(restored.rawNote('inf301-ec2', '21U2094', 'sn'), '14');
      expect(restored.note('inf305-ec1', '21U2094', 'cc').kind,
          GradeNoteKind.invalid);
      expect(restored.status('inf301-ec1'), GradeEntryStatus.draft);
      expect(restored.status('inf301-ec2'), GradeEntryStatus.draft);
      expect(restored.submitEc('inf301-ec1'), isFalse);
      expect(restored.validateEc('inf301-ec1'), isTrue);
    });

    test('brouillon d’une autre classe, version ou structure est rejeté', () {
      final encoded = GradeEntryBook.demo().encodeDraft();
      for (final field in [
        'schemaVersion',
        'catalogId',
        'programVersion',
        'classId',
        'academicYear'
      ]) {
        final data = jsonDecode(encoded) as Map<String, dynamic>;
        data[field] = 'foreign';
        expect(() => GradeEntryBook.fromDraft(jsonEncode(data)),
            throwsFormatException,
            reason: field);
      }
      final mutations = <void Function(Map<String, dynamic>)>[
        (data) => data['notes'].remove('inf301-ec1'),
        (data) => data['notes']['unknown-ec'] = {},
        (data) => data['notes']['inf301-ec1'].remove('21U2094'),
        (data) => data['notes']['inf301-ec1']['21U2094'].remove('cc'),
        (data) => data['notes']['inf301-ec1']['21U2094']['cc'] = 15,
        (data) => data['notes']['inf301-ec1']['21U2094']['cc'] = null,
        (data) => data['status'] = 'submitted',
      ];
      for (final mutate in mutations) {
        final data = jsonDecode(encoded) as Map<String, dynamic>;
        mutate(data);
        expect(() => GradeEntryBook.fromDraft(jsonEncode(data)),
            throwsFormatException);
      }
      for (final encoded in ['not json', 'null', '[]', '{}']) {
        expect(() => GradeEntryBook.fromDraft(encoded), throwsFormatException);
      }
    });
  });

  test('un plan vide, aux poids invalides ou doublons est rejeté', () {
    for (final plan in <List<GradeEvaluation>>[
      [],
      [const GradeEvaluation(id: 'cc', code: 'CC', title: 'CC', weight: 99)],
      [
        const GradeEvaluation(id: 'cc', code: 'CC', title: 'CC', weight: 0),
        const GradeEvaluation(id: 'sn', code: 'SN', title: 'SN', weight: 100)
      ],
      [
        const GradeEvaluation(id: 'cc', code: 'CC', title: 'CC', weight: 30),
        const GradeEvaluation(id: 'cc', code: 'CC', title: 'CC', weight: 70)
      ],
    ]) {
      expect(() => _book(elements: [_element('ec', evaluations: plan)]),
          throwsArgumentError);
    }
    expect(() => _book(elements: []), throwsArgumentError);
    expect(() => _book(elements: [_element('a'), _element('b'), _element('c')]),
        throwsArgumentError);
    expect(() => _book(elements: [_element('a', credits: 0)]),
        throwsArgumentError);
  });
}
