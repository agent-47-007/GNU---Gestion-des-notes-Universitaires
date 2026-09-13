import 'dart:convert';

enum GradeNoteKind { numeric, missing, absent, invalid }

enum GradeEntryStatus { draft, validated, submitted }

class GradeEvaluation {
  final String id, code, title;
  final int weight;
  final bool isResit;

  const GradeEvaluation({
    required this.id,
    required this.code,
    required this.title,
    required this.weight,
    this.isResit = false,
  });
}

class GradeElement {
  final String id, code, title;
  final int credits;
  final List<GradeEvaluation> evaluations;

  const GradeElement({
    required this.id,
    required this.code,
    required this.title,
    required this.credits,
    required this.evaluations,
  });
}

class GradeUnit {
  final String id, code, title;
  final int credits;
  final List<GradeElement> elements;

  const GradeUnit({
    required this.id,
    required this.code,
    required this.title,
    required this.credits,
    required this.elements,
  });
}

class GradeStudent {
  final String id, matricule, name, group;

  const GradeStudent({
    required this.id,
    required this.matricule,
    required this.name,
    required this.group,
  });
}

/// Exact decimal arithmetic matching PostgreSQL numeric, including on the web.
/// Only presentation getters convert to double; ceilings never use a double.
class _Fraction {
  final BigInt numerator, denominator;

  _Fraction(this.numerator, this.denominator);
  _Fraction.integer(int value)
      : numerator = BigInt.from(value),
        denominator = BigInt.one;

  _Fraction operator +(_Fraction other) => _Fraction(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  _Fraction times(int value) =>
      _Fraction(numerator * BigInt.from(value), denominator);
  _Fraction dividedBy(int value) =>
      _Fraction(numerator, denominator * BigInt.from(value));
  int get ceiling =>
      ((numerator + denominator - BigInt.one) ~/ denominator).toInt();
  double get asDouble => numerator.toDouble() / denominator.toDouble();
}

class GradeNote {
  final String raw;
  final GradeNoteKind kind;
  final String? error;
  final _Fraction? _value;

  const GradeNote._(this.raw, this.kind, this._value, this.error);

  factory GradeNote.parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return GradeNote._(raw, GradeNoteKind.missing, null, null);
    }
    if (text.toUpperCase() == 'ABS') {
      return GradeNote._(raw, GradeNoteKind.absent, null, null);
    }
    // Bound local draft input sizes and reject non-finite/scientific notation.
    if (text.length > 40 ||
        !RegExp(r'^[+-]?\d+(?:[.,]\d+)?$').hasMatch(text)) {
      return GradeNote._(raw, GradeNoteKind.invalid, null,
          'Saisir une note de 0 à 20, ABS, ou laisser vide.');
    }
    final pieces = text.replaceAll(',', '.').split('.');
    final decimals = pieces.length == 2 ? pieces[1] : '';
    final numerator = BigInt.parse('${pieces[0]}$decimals');
    final denominator = BigInt.from(10).pow(decimals.length);
    if (numerator < BigInt.zero || numerator > BigInt.from(20) * denominator) {
      return GradeNote._(raw, GradeNoteKind.invalid, null,
          'La note doit être comprise entre 0 et 20.');
    }
    return GradeNote._(raw, GradeNoteKind.numeric,
        _Fraction(numerator, denominator), null);
  }

  double? get value20 => _value?.asDouble;
}

class GradeResult {
  final bool complete, eliminated;
  final int? score100;
  final _Fraction? _raw100;

  const GradeResult._(
      this.complete, this.eliminated, this._raw100, this.score100);
  const GradeResult.incomplete() : this._(false, false, null, null);
  const GradeResult.eliminated() : this._(true, true, null, null);

  double? get raw100 => _raw100?.asDouble;
  double? get raw20 => _raw100?.dividedBy(5).asDouble;
  double? get rounded20 => score100 == null ? null : score100! / 5;
  String? get grade => eliminated ? 'EL' : gradeForScore(score100);
  double? get points => eliminated ? 0 : pointsForScore(score100);

  /// Annual admission condition, meaningful only for an aggregated UE result.
  bool get belowAnnualThreshold => score100 != null && score100! < 35;

  static String? gradeForScore(int? score) {
    if (score == null || score < 0 || score > 100) return null;
    for (final band in _gradeBands) {
      if (score >= band.$1) return band.$2;
    }
    return 'F';
  }

  static double? pointsForScore(int? score) {
    if (score == null || score < 0 || score > 100) return null;
    for (final band in _gradeBands) {
      if (score >= band.$1) return band.$3;
    }
    return 0;
  }

  static const _gradeBands = <(int, String, double)>[
    (80, 'A+', 4),
    (75, 'A−', 3.7),
    (70, 'B+', 3.3),
    (65, 'B', 3),
    (60, 'B−', 2.7),
    (55, 'C+', 2.3),
    (50, 'C', 2),
    (45, 'C−', 1.7),
    (40, 'D+', 1.3),
    (35, 'D−', 1),
    (30, 'E', 0),
    (0, 'F', 0),
  ];
}

class GradeSummary {
  final int total, numeric, missing, absent, invalid, belowUeThreshold;

  const GradeSummary({
    required this.total,
    required this.numeric,
    required this.missing,
    required this.absent,
    required this.invalid,
    required this.belowUeThreshold,
  });

  double get completionPercent => total == 0 ? 0 : numeric * 100 / total;
}

/// Editable demonstration register. No academic publication or API write occurs.
class GradeEntryBook {
  static const demoCatalogId = 'gnu-grade-entry-demo-v1';
  static const demoProgramVersion = 'GNU-1.2-demo';
  static const demoClassId = 'L3-INFO-PROMO-A-demo';
  static const demoAcademicYear = '2024-2025';

  final String catalogId, programVersion, classId, academicYear;
  final List<GradeUnit> units;
  final List<GradeStudent> students;
  final Map<String, GradeElement> _elements = {};
  final Map<String, GradeUnit> _unitByElement = {};
  final Map<String, Map<String, Map<String, String>>> _notes = {};
  final Map<String, GradeEntryStatus> _statuses = {};

  GradeEntryBook({
    required List<GradeUnit> units,
    required List<GradeStudent> students,
    required this.catalogId,
    required this.programVersion,
    required this.classId,
    required this.academicYear,
  })  : units = List.unmodifiable(units),
        students = List.unmodifiable(students) {
    if (units.isEmpty || students.isEmpty ||
        units.map((u) => u.id).toSet().length != units.length ||
        students.map((s) => s.id).toSet().length != students.length) {
      throw ArgumentError('Catalogue ou liste d’étudiants invalide.');
    }
    for (final unit in units) {
      if (unit.elements.isEmpty || unit.elements.length > 2 ||
          unit.credits <= 0 ||
          unit.elements.fold(0, (sum, ec) => sum + ec.credits) != unit.credits) {
        throw ArgumentError('Une UE active contient 1 à 2 EC et leurs crédits.');
      }
      for (final element in unit.elements) {
        if (_elements.containsKey(element.id) || element.credits <= 0 ||
            element.evaluations.isEmpty ||
            element.evaluations.any((evaluation) => evaluation.weight <= 0) ||
            element.evaluations.fold(0, (sum, e) => sum + e.weight) != 100 ||
            element.evaluations.map((e) => e.id).toSet().length !=
                element.evaluations.length) {
          throw ArgumentError('EC ou pondérations du plan d’évaluation invalides.');
        }
        _elements[element.id] = element;
        _unitByElement[element.id] = unit;
        _notes[element.id] = {
          for (final student in students)
            student.id: {for (final evaluation in element.evaluations) evaluation.id: ''},
        };
        _statuses[element.id] = GradeEntryStatus.draft;
      }
    }
  }

  factory GradeEntryBook.demo() {
    final book = GradeEntryBook(
      units: _demoUnits,
      students: _demoStudents,
      catalogId: demoCatalogId,
      programVersion: demoProgramVersion,
      classId: demoClassId,
      academicYear: demoAcademicYear,
    );
    const initialNotes = <List<String>>[
      ['15.50', '16.00', '14.50'],
      ['12.00', 'ABS', ''],
      ['6.50', '11.00', '9.00'],
      ['17.25', '18.00', '16.50'],
      ['14.00', '13.50', '11.50'],
      ['11.50', '10.00', ''],
      ['10.50', '12.00', '10.00'],
    ];
    final element = book.units.first.elements.first;
    for (var s = 0; s < book.students.length; s++) {
      for (var e = 0; e < element.evaluations.length; e++) {
        book.updateNote(element.id, book.students[s].id,
            element.evaluations[e].id, initialNotes[s][e]);
      }
    }
    return book;
  }

  GradeElement element(String id) =>
      _elements[id] ?? (throw ArgumentError.value(id, 'ecId', 'EC inconnu'));

  GradeUnit unitForElement(String id) =>
      _unitByElement[id] ?? (throw ArgumentError.value(id, 'ecId', 'EC inconnu'));

  String rawNote(String ecId, String studentId, String evaluationId) {
    final value = _notes[ecId]?[studentId]?[evaluationId];
    if (value == null) throw ArgumentError('Note hors EC, étudiant ou évaluation.');
    return value;
  }

  GradeNote note(String ecId, String studentId, String evaluationId) =>
      GradeNote.parse(rawNote(ecId, studentId, evaluationId));

  void updateNote(String ecId, String studentId, String evaluationId, String raw) {
    if (rawNote(ecId, studentId, evaluationId) == raw) return;
    _notes[ecId]![studentId]![evaluationId] = raw;
    _statuses[ecId] = GradeEntryStatus.draft;
  }

  GradeResult ecResult(String ecId, String studentId) {
    var result = _Fraction.integer(0);
    var eliminated = false;
    for (final evaluation in element(ecId).evaluations) {
      final input = note(ecId, studentId, evaluation.id);
      if (input.kind == GradeNoteKind.absent && evaluation.isResit) {
        eliminated = true;
      } else if (input.kind != GradeNoteKind.numeric) {
        return const GradeResult.incomplete();
      } else {
        // /20 -> /100, then evaluation weight /100 = value * weight /20.
        result = result + input._value!.times(evaluation.weight).dividedBy(20);
      }
    }
    return eliminated
        ? const GradeResult.eliminated()
        : GradeResult._(true, false, result, result.ceiling);
  }

  GradeResult ueResult(String ueId, String studentId) {
    final unit = units.firstWhere((unit) => unit.id == ueId);
    var total = 0;
    var eliminated = false;
    for (final element in unit.elements) {
      final result = ecResult(element.id, studentId);
      if (!result.complete) return const GradeResult.incomplete();
      eliminated = eliminated || result.eliminated;
      total += (result.score100 ?? 0) * element.credits;
    }
    if (eliminated) return const GradeResult.eliminated();
    final result = _Fraction.integer(total).dividedBy(unit.credits);
    return GradeResult._(true, false, result, result.ceiling);
  }

  GradeSummary summary(String ecId) {
    final ec = element(ecId);
    var numeric = 0, missing = 0, absent = 0, invalid = 0, below = 0;
    for (final student in students) {
      for (final evaluation in ec.evaluations) {
        switch (note(ecId, student.id, evaluation.id).kind) {
          case GradeNoteKind.numeric: numeric++;
          case GradeNoteKind.missing: missing++;
          case GradeNoteKind.absent: absent++;
          case GradeNoteKind.invalid: invalid++;
        }
      }
      if (ueResult(unitForElement(ecId).id, student.id).belowAnnualThreshold) below++;
    }
    return GradeSummary(total: students.length * ec.evaluations.length,
        numeric: numeric, missing: missing, absent: absent, invalid: invalid,
        belowUeThreshold: below);
  }

  GradeEntryStatus status(String ecId) =>
      _statuses[ecId] ?? (throw ArgumentError.value(ecId, 'ecId', 'EC inconnu'));

  List<String> validationIssues(String ecId) {
    final issues = <String>[];
    for (final student in students) {
      for (final evaluation in element(ecId).evaluations) {
        final input = note(ecId, student.id, evaluation.id);
        final prefix = '${student.matricule} · ${evaluation.code}';
        if (input.kind == GradeNoteKind.missing) {
          issues.add('$prefix : note manquante.');
        } else if (input.kind == GradeNoteKind.invalid) {
          issues.add('$prefix : ${input.error}');
        } else if (input.kind == GradeNoteKind.absent && !evaluation.isResit) {
          issues.add('$prefix : absence en session normale à régulariser.');
        }
      }
    }
    return issues;
  }

  bool validateEc(String ecId) {
    if (validationIssues(ecId).isNotEmpty) return false;
    if (status(ecId) != GradeEntryStatus.submitted) {
      _statuses[ecId] = GradeEntryStatus.validated;
    }
    return true;
  }

  bool submitEc(String ecId) {
    if (status(ecId) != GradeEntryStatus.validated ||
        validationIssues(ecId).isNotEmpty) return false;
    _statuses[ecId] = GradeEntryStatus.submitted;
    return true;
  }

  /// Local snapshots deliberately contain no attestation or publication status.
  /// Restoring a draft always requires a fresh validation before submission.
  String encodeDraft() => jsonEncode({
        'schemaVersion': 1,
        'catalogId': catalogId,
        'programVersion': programVersion,
        'classId': classId,
        'academicYear': academicYear,
        'notes': _notes,
      });

  factory GradeEntryBook.fromDraft(String encoded) {
    if (encoded.length > 100000) throw const FormatException('Brouillon trop volumineux.');
    final dynamic decoded = jsonDecode(encoded);
    final book = GradeEntryBook.demo();
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != 1 ||
        decoded['catalogId'] != book.catalogId ||
        decoded['programVersion'] != book.programVersion ||
        decoded['classId'] != book.classId ||
        decoded['academicYear'] != book.academicYear ||
        !_hasKeys(decoded, {'schemaVersion', 'catalogId', 'programVersion',
          'classId', 'academicYear', 'notes'})) {
      throw const FormatException('Brouillon incompatible avec ce catalogue et cette classe.');
    }
    final dynamic data = decoded['notes'];
    if (data is! Map<String, dynamic> || !_hasKeys(data, book._notes.keys.toSet())) {
      throw const FormatException('Liste des EC du brouillon invalide.');
    }
    for (final ec in book._elements.values) {
      final dynamic rows = data[ec.id];
      if (rows is! Map<String, dynamic> ||
          !_hasKeys(rows, book.students.map((s) => s.id).toSet())) {
        throw const FormatException('Liste des étudiants du brouillon invalide.');
      }
      for (final student in book.students) {
        final dynamic cells = rows[student.id];
        if (cells is! Map<String, dynamic> ||
            !_hasKeys(cells, ec.evaluations.map((e) => e.id).toSet())) {
          throw const FormatException('Plan d’évaluation du brouillon invalide.');
        }
        for (final evaluation in ec.evaluations) {
          final dynamic raw = cells[evaluation.id];
          if (raw is! String || raw.length > 80) {
            throw const FormatException('Valeur de brouillon invalide.');
          }
          // Preserve unfinished and erroneous input so the user can correct it.
          book.updateNote(ec.id, student.id, evaluation.id, raw);
        }
      }
    }
    return book;
  }

  static bool _hasKeys(Map<String, dynamic> map, Set<String> expected) =>
      map.length == expected.length && expected.every(map.containsKey);
}

const _demoPlanWithTp = [
  GradeEvaluation(id: 'cc', code: 'CC', title: 'Contrôle continu', weight: 20),
  GradeEvaluation(id: 'tp', code: 'TP', title: 'Travaux pratiques', weight: 30),
  GradeEvaluation(id: 'sn', code: 'SN', title: 'Session normale', weight: 50),
];

const _demoPlanWithoutTp = [
  GradeEvaluation(id: 'cc', code: 'CC', title: 'Contrôle continu', weight: 30),
  GradeEvaluation(id: 'sn', code: 'SN', title: 'Session normale', weight: 70),
];

const _demoUnits = [
  GradeUnit(id: 'inf301', code: 'INF301',
      title: 'Algorithmique avancée & Structures de données', credits: 5,
      elements: [
        GradeElement(id: 'inf301-ec1', code: 'INF301-EC1',
            title: 'Algorithmique avancée', credits: 3, evaluations: _demoPlanWithTp),
        GradeElement(id: 'inf301-ec2', code: 'INF301-EC2',
            title: 'Structures de données', credits: 2, evaluations: _demoPlanWithoutTp),
      ]),
  GradeUnit(id: 'inf305', code: 'INF305', title: 'Systèmes & Réseaux', credits: 5,
      elements: [
        GradeElement(id: 'inf305-ec1', code: 'INF305-EC1',
            title: 'Systèmes d’exploitation', credits: 3, evaluations: _demoPlanWithoutTp),
        GradeElement(id: 'inf305-ec2', code: 'INF305-EC2',
            title: 'Réseaux informatiques', credits: 2, evaluations: _demoPlanWithTp),
      ]),
  GradeUnit(id: 'inf201', code: 'INF201', title: 'C/C++ fondamental', credits: 4,
      elements: [
        GradeElement(id: 'inf201-ec1', code: 'INF201-EC1',
            title: 'Programmation C/C++', credits: 4, evaluations: _demoPlanWithTp),
      ]),
];

const _demoStudents = [
  GradeStudent(id: '21U2094', matricule: '21U2094', name: 'ABENA ESSOMBA Jean-Marc', group: 'G1'),
  GradeStudent(id: '21U2412', matricule: '21U2412', name: 'BIKOUÉ NDOUMBE Carine', group: 'G1'),
  GradeStudent(id: '21U2991', matricule: '21U2991', name: 'EKANE TCHINDA Rostand', group: 'G2'),
  GradeStudent(id: '21U3104', matricule: '21U3104', name: 'KAMDEM WABO Ulrich', group: 'G2'),
  GradeStudent(id: '21U2849', matricule: '21U2849', name: 'DJOUKA FOTSO Franck Kevin', group: 'G1'),
  GradeStudent(id: '21U2118', matricule: '21U2118', name: 'MANGA ATANGANA Boris Cyrille', group: 'G2'),
  GradeStudent(id: '21U2505', matricule: '21U2505', name: 'NGO MBOCK Madeleine Viviane', group: 'G1'),
];
