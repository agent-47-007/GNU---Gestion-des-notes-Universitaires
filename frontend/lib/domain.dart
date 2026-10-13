import 'dart:typed_data';

import 'package:flutter/foundation.dart';

enum UserRole { student, teacher, agent }

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
  final courses = <Course>[
    Course('INF 201', 'Algorithmique avancée', 6, 76),
    Course('INF 202', 'Bases de données', 6, 68),
    Course('INF 203', 'Systèmes d’exploitation', 5, 58),
    Course('MAT 201', 'Mathématiques discrètes', 5, 43),
    Course('INF 204', 'Programmation orientée objet', 5, 81),
    Course('TRA 201', 'Communication professionnelle', 3, 72, required: false),
  ];
  final selectedCourses = <String>{
    'INF 201',
    'INF 202',
    'INF 203',
    'MAT 201',
    'INF 204',
  };
  bool enrollmentSubmitted = false;
  bool enrollmentApproved = false;
  final marks = <StudentMark>[
    StudentMark('24I001', 'Alex Mouna', '15', '15,5'),
    StudentMark('24I002', 'Dani Essama', '12', '14'),
    StudentMark('24I003', 'Charlie Biloa', '9', '8'),
    StudentMark('24I004', 'Lou Talla', '16', ''),
  ];
  int ccWeight = 30;
  int get examWeight => 100 - ccWeight;
  bool gradesValidated = false;
  bool gradesSubmitted = false;
  int publicationVersion = 0;
  List<double> publishedScores = [];
  final requests = <AcademicRequest>[
    AcademicRequest(
      id: 'REQ-001',
      course: 'INF 201',
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
    'Dr. Sam Nkom → INF 201 · Algorithmique avancée',
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
  int get selectedCredits => courses
      .where((c) => selectedCourses.contains(c.code))
      .fold(0, (sum, course) => sum + course.credits);
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

  void changeWeights(int cc) {
    if (cc < 1 || cc > 99) throw ArgumentError('Pondération invalide');
    ccWeight = cc;
    gradesValidated = false;
    gradesSubmitted = false;
    record('Plan d’évaluation actualisé');
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

  void selectCourse(Course course, bool selected) {
    if (course.required || enrollmentSubmitted) return;
    if (selected) {
      selectedCourses.add(course.code);
    } else {
      selectedCourses.remove(course.code);
    }
    notifyListeners();
  }

  void submitEnrollment() {
    enrollmentSubmitted = true;
    record('Choix pédagogiques soumis pour vérification');
  }

  void approveEnrollment() {
    if (!enrollmentSubmitted) return;
    enrollmentApproved = true;
    record('Inscription pédagogique vérifiée');
  }

  void addRequest(AcademicRequest request) {
    requests.insert(0, request);
    record('Requête ${request.id} déposée');
  }

  void decide(AcademicRequest request, bool accepted, String reason) {
    if (reason.trim().length < 10) throw ArgumentError('Motif trop court');
    request.status = accepted ? 'Acceptée' : 'Rejetée';
    request.decision = reason.trim();
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
