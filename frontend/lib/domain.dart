import 'dart:typed_data';

import 'package:flutter/foundation.dart';

enum UserRole { student, teacher, agent }

class GradeBand {
  const GradeBand(
    this.minimum,
    this.grade,
    this.points,
    this.appreciation,
    this.result,
  );
  final int minimum;
  final String grade, appreciation;
  final String result;
  final double points;
}

const gradeScale = <GradeBand>[
  GradeBand(80, 'A', 4.00, 'Très bien', 'Crédits capitalisés et transférables'),
  GradeBand(
    75,
    'A-',
    3.70,
    'Très bien',
    'Crédits capitalisés et transférables',
  ),
  GradeBand(70, 'B+', 3.30, 'Bien', 'Crédits capitalisés et transférables'),
  GradeBand(65, 'B', 3.00, 'Bien', 'Crédits capitalisés et transférables'),
  GradeBand(60, 'B-', 2.70, 'Bien', 'Crédits capitalisés et transférables'),
  GradeBand(
    55,
    'C+',
    2.30,
    'Assez-Bien',
    'Crédits capitalisés et transférables',
  ),
  GradeBand(
    50,
    'C',
    2.00,
    'Assez-Bien',
    'Crédits capitalisés et transférables',
  ),
  GradeBand(
    45,
    'C-',
    1.70,
    'Passable',
    'Crédits capitalisés et non transférables',
  ),
  GradeBand(
    40,
    'D+',
    1.30,
    'Insuffisant',
    'Crédits capitalisés et non transférables',
  ),
  GradeBand(
    35,
    'D',
    1.00,
    'Insuffisant',
    'Crédits capitalisés et non transférables',
  ),
  GradeBand(30, 'E', 0.00, 'Échec', 'Crédits non capitalisés'),
  GradeBand(0, 'F', 0.00, 'Échec', 'Crédits non capitalisés'),
];

GradeBand gradeForMark(double mark) =>
    gradeScale.firstWhere((band) => mark >= band.minimum);

double mgpForResults(Iterable<({int credits, double mark})> results) {
  var weightedPoints = 0.0;
  var totalCredits = 0;
  for (final result in results) {
    weightedPoints += result.credits * gradeForMark(result.mark).points;
    totalCredits += result.credits;
  }
  return totalCredits == 0
      ? 0
      : (weightedPoints / totalCredits * 100).roundToDouble() / 100;
}

extension RoleLabels on UserRole {
  String get label => switch (this) {
    UserRole.student => 'Étudiant',
    UserRole.teacher => 'Enseignant',
    UserRole.agent => 'Agent informatique',
  };
  String get displayName => switch (this) {
    UserRole.student => 'Alex Mouna',
    UserRole.teacher => 'Dr. Sam Nkom',
    UserRole.agent => 'Camille Etoa',
  };
  String get initials => switch (this) {
    UserRole.student => 'AM',
    UserRole.teacher => 'SN',
    UserRole.agent => 'CE',
  };
}

class Course {
  Course(
    this.code,
    this.title,
    this.credits,
    this.score, {
    this.required = true,
  });
  final String code, title;
  final int credits;
  final double? score;
  final bool required;
}

class RegistrationUnit {
  const RegistrationUnit({
    required this.code,
    required this.title,
    required this.semester,
    required this.credits,
    required this.professors,
    required this.weighting,
    this.required = true,
  });
  final String code, title, semester, professors, weighting;
  final int credits;
  final bool required;
}

/// Référence unique du catalogue de matières de la fiche académique fournie.
const academicUnits = <RegistrationUnit>[
  RegistrationUnit(
    code: 'INF211',
    title: 'PROGRAMMATION ORIENTÉE OBJET',
    semester: 'Semestre 1',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'INF212',
    title: 'MATHEMATIQUES DISCRETES',
    semester: 'Semestre 2',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'INF221',
    title: 'BASES DE DONNEES ET MODELISATION',
    semester: 'Semestre 1',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'INF222',
    title: 'PROGRAMMATION WEB',
    semester: 'Semestre 2',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'INF231',
    title: 'METHODES ALGORITHMIQUES ET STRUCTURES DE DONNEES',
    semester: 'Semestre 1',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'INF232',
    title: 'STATISTIQUES ET ANALYSE DE DONNEES',
    semester: 'Semestre 2',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'INF252',
    title: 'SECURITE INFORMATIQUE',
    semester: 'Semestre 2',
    credits: 3,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'INF261',
    title: 'SYSTEME WINDOWS ET PROTOCOLES DE ROUTAGE',
    semester: 'Semestre 1',
    credits: 3,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
  ),
  RegistrationUnit(
    code: 'MAT211',
    title: 'ALGEBRE 2A : THEORIE SPECTRALE ET ALGEBRE MULTILINEAIRE',
    semester: 'Semestre 1',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'CC 30% · TP 0% · SN 70%',
  ),
  RegistrationUnit(
    code: 'MAT232',
    title: 'CALCUL INTEGRAL SUR Rn',
    semester: 'Semestre 2',
    credits: 6,
    professors: 'À confirmer',
    weighting: 'CC 30% · TP 0% · SN 70%',
  ),
  RegistrationUnit(
    code: 'FBL211',
    title: 'FORMATION BILINGUE II',
    semester: 'Semestre 1',
    credits: 3,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
    required: false,
  ),
  RegistrationUnit(
    code: 'PPE212',
    title: 'PROJET PROFESSIONNEL ET PRE-IMMERSION',
    semester: 'Semestre 2',
    credits: 3,
    professors: 'À confirmer',
    weighting: 'À définir par l’enseignant',
    required: false,
  ),
];

class StudentResult {
  const StudentResult({
    required this.code,
    required this.title,
    required this.semester,
    required this.credits,
    required this.mark,
  });
  final String code, title, semester;
  final int credits;
  final double mark;
}

class AssessmentMark {
  const AssessmentMark({
    required this.code,
    required this.title,
    required this.cc,
    required this.tp,
    required this.tpe,
    required this.sn,
    required this.ccWeight,
    required this.tpWeight,
    required this.tpeWeight,
    required this.snWeight,
  });
  final String code, title;
  final double cc, tp, tpe, sn;
  final int ccWeight, tpWeight, tpeWeight, snWeight;
  double get total =>
      (cc * ccWeight + tp * tpWeight + tpe * tpeWeight + sn * snWeight) / 100;
}

class StudentMark {
  StudentMark(this.id, this.name, this.cc, this.exam);
  final String id, name;
  String cc, exam;
}

class AcademicRequest {
  AcademicRequest({
    required this.id,
    required this.course,
    required this.type,
    required this.message,
    this.proofName,
    this.proofBytes,
  });
  final String id, course, type, message;
  final String? proofName;
  final Uint8List? proofBytes;
  String status = 'À examiner';
  String? decision;
}

class DemoAccount {
  DemoAccount(this.name, this.email, this.role);
  final String name, email;
  final UserRole role;
  bool active = true;
}

/// Données fictives en mémoire, sans appel réseau. Réinitialisées au rechargement.
class DemoStore extends ChangeNotifier {
  // Le catalogue étudiant est alimenté par la source unique ci-dessus.
  final demoMarks = const <String, double>{
    'INF211': 81,
    'INF212': 49,
    'INF221': 68,
    'INF222': 85,
    'INF231': 76,
    'INF232': 63,
    'INF252': 77,
    'INF261': 58,
    'MAT211': 43,
    'MAT232': 54,
    'FBL211': 72,
    'PPE212': 88,
  };
  List<StudentResult> get studentResults => registrationUnits
      .map(
        (unit) => StudentResult(
          code: unit.code,
          title: unit.title,
          semester: unit.semester,
          credits: unit.credits,
          mark: demoMarks[unit.code] ?? 0,
        ),
      )
      .toList(growable: false);
  // Vue de compatibilité utilisée par quelques outils internes : les valeurs
  // proviennent aussi du référentiel académique, jamais d'un ancien catalogue.
  List<Course> get courses => registrationUnits
      .map(
        (unit) => Course(
          unit.code,
          unit.title,
          unit.credits,
          demoMarks[unit.code],
          required: unit.required,
        ),
      )
      .toList(growable: false);
  final registrationUnits = academicUnits;

  /// UE choisies explicitement par l’étudiant. Une liste vide correspond à un brouillon.
  final selectedCourses = <String>{};
  final submittedEnrollmentSemesters = <String>{};
  final approvedEnrollmentSemesters = <String>{};
  bool get enrollmentSubmitted => submittedEnrollmentSemesters.isNotEmpty;
  bool get enrollmentApproved => approvedEnrollmentSemesters.isNotEmpty;
  final marks = <StudentMark>[
    StudentMark('24I001', 'Alex Mouna', '15', '15,5'),
    StudentMark('24I002', 'Dani Essama', '12', '14'),
    StudentMark('24I003', 'Charlie Biloa', '9', '8'),
    StudentMark('24I004', 'Lou Talla', '16', ''),
  ];
  final int ccWeight = 30;
  int get examWeight => 100 - ccWeight;
  bool gradesValidated = false;
  bool gradesSubmitted = false;
  int publicationVersion = 0;
  List<double> publishedScores = [];
  final requests = <AcademicRequest>[
    AcademicRequest(
      id: 'REQ-001',
      course: 'INF211',
      type: 'Vérification de note',
      message: 'Je souhaite vérifier la transcription de ma note de contrôle continu.',
    ),
  ];
  final accounts = <DemoAccount>[
    DemoAccount('Alex Mouna', 'alex@example.test', UserRole.student),
    DemoAccount('Dr. Sam Nkom', 'sam@example.test', UserRole.teacher),
    DemoAccount('Camille Etoa', 'camille@example.test', UserRole.agent),
  ];
  final programs = <String>['Informatique · Licence 2'];
  final assignments = <String>[
    'Dr. Sam Nkom → INF211 · PROGRAMMATION ORIENTÉE OBJET',
  ];
  final sessions = <String>[];
  final activity = <String>['Session de démonstration ouverte'];

  static double? parseMark(String raw) {
    final text = raw.trim();
    if (!RegExp(r'^\d{1,2}([.,]\d{1,2})?$').hasMatch(text)) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value >= 0 && value <= 20 ? value : null;
  }

  int get missingMarks => marks.fold(
    0,
    (sum, row) =>
        sum +
        (parseMark(row.cc) == null ? 1 : 0) +
        (parseMark(row.exam) == null ? 1 : 0),
  );
  int get selectedCredits => registrationUnits
      .where((c) => selectedCourses.contains(c.code))
      .fold(0, (sum, course) => sum + course.credits);
  int selectedCreditsFor(String semester) => registrationUnits
      .where(
        (unit) =>
            unit.semester == semester && selectedCourses.contains(unit.code),
      )
      .fold(0, (sum, unit) => sum + unit.credits);
  int selectedUnitsFor(String semester) => registrationUnits
      .where(
        (unit) =>
            unit.semester == semester && selectedCourses.contains(unit.code),
      )
      .length;
  int get openRequests =>
      requests.where((r) => r.status == 'À examiner').length;
  double? total(StudentMark row) {
    final cc = parseMark(row.cc), exam = parseMark(row.exam);
    if (cc == null || exam == null) return null;
    return (cc * ccWeight + exam * examWeight) / 100;
  }

  void record(String event) {
    activity.insert(0, event);
    notifyListeners();
  }

  void changeMark(int index, bool isCc, String value) {
    if (isCc) {
      marks[index].cc = value;
    } else {
      marks[index].exam = value;
    }
    gradesValidated = false;
    gradesSubmitted = false;
    notifyListeners();
  }

  bool validateGrades() {
    if (missingMarks != 0) return false;
    gradesValidated = true;
    record('Notes d’algorithmique contrôlées et validées');
    return true;
  }

  bool submitGrades() {
    if (!gradesValidated || missingMarks != 0) return false;
    gradesSubmitted = true;
    record('Registre transmis à la cellule informatique');
    return true;
  }

  bool publish() {
    if (!gradesSubmitted || !gradesValidated || missingMarks != 0) return false;
    publishedScores = marks.map((row) => total(row)!).toList(growable: false);
    publicationVersion++;
    record('Publication de démonstration · version $publicationVersion');
    return true;
  }

  void selectRegistrationUnit(RegistrationUnit course, bool selected) {
    if (submittedEnrollmentSemesters.contains(course.semester)) return;
    if (selected) {
      selectedCourses.add(course.code);
    } else {
      selectedCourses.remove(course.code);
    }
    notifyListeners();
  }

  void importEnrollmentSelections(
    String semester,
    Map<String, bool> selections,
  ) {
    if (submittedEnrollmentSemesters.contains(semester)) return;
    for (final unit in registrationUnits.where(
      (item) => item.semester == semester,
    )) {
      final selected = selections[unit.code];
      if (selected == null) continue;
      if (selected) {
        selectedCourses.add(unit.code);
      } else {
        selectedCourses.remove(unit.code);
      }
    }
    notifyListeners();
  }

  void selectCourse(Course course, bool selected) {
    final unit = registrationUnits.firstWhere(
      (candidate) => candidate.code == course.code,
    );
    selectRegistrationUnit(unit, selected);
  }

  bool submitEnrollment([String semester = 'Semestre 2']) {
    if (submittedEnrollmentSemesters.contains(semester) ||
        selectedUnitsFor(semester) == 0) {
      return false;
    }
    submittedEnrollmentSemesters.add(semester);
    record('Inscription $semester soumise pour vérification');
    return true;
  }

  void approveEnrollment([String semester = 'Semestre 2']) {
    if (!submittedEnrollmentSemesters.contains(semester)) return;
    approvedEnrollmentSemesters.add(semester);
    record('Inscription pédagogique $semester vérifiée');
  }

  void addRequest(AcademicRequest request) {
    requests.insert(0, request);
    record('Requête ${request.id} déposée');
  }

  void decide(AcademicRequest request, bool accepted, String reason) {
    request.status = accepted ? 'Acceptée' : 'Rejetée';
    request.decision = reason.trim().isEmpty
        ? 'Aucune précision fournie.'
        : reason.trim();
    record('Requête ${request.id} : ${request.status.toLowerCase()}');
  }

  void addAccount(DemoAccount account) {
    if (accounts.any(
      (a) => a.email.toLowerCase() == account.email.toLowerCase(),
    )) {
      throw ArgumentError('Cette adresse existe déjà.');
    }
    accounts.add(account);
    record('Compte de ${account.name} ajouté');
  }

  void toggleAccount(DemoAccount account) {
    account.active = !account.active;
    record('Statut de ${account.name} actualisé');
  }

  void addProgram(String title) {
    programs.add(title);
    record('Programme ajouté : $title');
  }

  void addAssignment(String title) {
    assignments.add(title);
    record('Affectation ajoutée');
  }

  void addSession(String title) {
    sessions.add(title);
    record('Évaluation de démonstration planifiée');
  }
}
