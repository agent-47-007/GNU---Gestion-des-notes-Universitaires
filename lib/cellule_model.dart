import 'package:flutter/foundation.dart';

import 'grade_entry_model.dart';

enum CelluleSection { supervision, structure, catalog, numerisation, publications, bulletin }

class CelluleEc {
  final String code, title, teacher;
  final int credits;
  final Map<String, int> weights;
  const CelluleEc({required this.code, required this.title, required this.teacher, required this.credits, required this.weights});
}

class CelluleCourse {
  final String id, code, title, category, teacher;
  final int credits, hours;
  final bool active;
  final List<CelluleEc> ecs;
  const CelluleCourse({required this.id, required this.code, required this.title, required this.category, required this.credits, required this.teacher, required this.hours, required this.active, required this.ecs});
}

class CelluleStudent {
  final String id, matricule, name;
  final Map<String, int?> scores;
  final Set<String> eliminated;
  const CelluleStudent({required this.id, required this.matricule, required this.name, required this.scores, this.eliminated = const {}});
}

class CelluleStudentResult {
  final double? mgp;
  final double pointsCredits;
  final int totalCredits, acquiredCredits;
  final bool complete, hasEl, belowThreshold;
  const CelluleStudentResult({required this.mgp, required this.pointsCredits, required this.totalCredits, required this.acquiredCredits, required this.complete, required this.hasEl, required this.belowThreshold});
}

class _CelluleCohort {
  final List<CelluleCourse> courses;
  final List<CelluleStudent> students;
  final List<String> events = ['Ouverture du registre de démonstration.'];
  bool calculated = false, validated = false, published = false;
  int selectedStudentIndex = 0;
  _CelluleCohort(this.courses, this.students);
}

/// All records here belong to an isolated demonstration. This workspace does
/// not write to the academic API, produce signatures, or publish real results.
class CelluleWorkspace extends ChangeNotifier {
  static const classLabels = {
    'L1-INFO': 'Licence 1 Informatique — Tronc commun',
    'L2-INFO': 'Licence 2 Informatique — Option générale',
    'L3-INFO-A': 'Licence 3 Informatique — Promotion A',
    'L3-INFO-B': 'Licence 3 Informatique — Promotion B',
    'M1-GL': 'Master 1 Génie logiciel',
  };
  final Map<String, _CelluleCohort> _cohorts = {};
  String _selectedClass = 'L3-INFO-A';
  CelluleSection section;

  CelluleWorkspace({this.section = CelluleSection.structure}) {
    for (final id in classLabels.keys) {
      final courses = _demoCourses(id);
      _cohorts[id] = _CelluleCohort(courses, _demoStudents(id, courses));
    }
  }

  _CelluleCohort get _cohort => _cohorts[_selectedClass]!;
  String get selectedClass => _selectedClass;
  String get classLabel => classLabels[_selectedClass]!;
  List<CelluleCourse> get courses => List.unmodifiable(_cohort.courses);
  List<CelluleStudent> get students => List.unmodifiable(_cohort.students);
  List<String> get events => List.unmodifiable(_cohort.events);
  bool get calculated => _cohort.calculated;
  bool get validated => _cohort.validated;
  bool get published => _cohort.published;
  int get selectedStudentIndex => _cohort.selectedStudentIndex;
  CelluleStudent get selectedStudent => students[selectedStudentIndex];
  bool get complete => students.every((student) => result(student).complete);

  void openSection(CelluleSection value) {
    if (section == value) return;
    section = value;
    notifyListeners();
  }

  void selectClass(String value) {
    if (!classLabels.containsKey(value)) throw ArgumentError('Classe inconnue.');
    if (_selectedClass == value) return;
    _selectedClass = value;
    notifyListeners();
  }

  void selectStudent(int index) {
    if (index < 0 || index >= students.length) return;
    _cohort.selectedStudentIndex = index;
    notifyListeners();
  }

  CelluleStudentResult result(CelluleStudent student) {
    var totalCredits = 0, acquired = 0, pointsTenths = 0;
    var complete = true, hasEl = false, below = false;
    for (final course in courses.where((c) => c.active)) {
      totalCredits += course.credits;
      if (student.eliminated.contains(course.code)) {
        hasEl = true;
        continue;
      }
      final score = student.scores[course.code];
      if (score == null || score < 0 || score > 100) {
        complete = false;
        continue;
      }
      final points = GradeResult.pointsForScore(score)!;
      pointsTenths += (points * 10).round() * course.credits;
      if (score >= 50) acquired += course.credits;
      if (score < 35) below = true;
    }
    complete = complete && totalCredits > 0;
    return CelluleStudentResult(
      mgp: complete ? pointsTenths / (10 * totalCredits) : null,
      pointsCredits: pointsTenths / 10,
      totalCredits: totalCredits,
      acquiredCredits: acquired,
      complete: complete,
      hasEl: hasEl,
      belowThreshold: below,
    );
  }

  void _validateCourse(CelluleCourse course) {
    if (course.id.trim().isEmpty || course.code.trim().isEmpty || course.title.trim().isEmpty || course.credits <= 0 || course.hours < 0 || !['FONDAMENTALE', 'OPTIONNELLE'].contains(course.category)) {
      throw ArgumentError('Code, intitulé, catégorie et crédits positifs requis.');
    }
    if (course.ecs.length > 2 || (course.active && course.ecs.isEmpty)) {
      throw ArgumentError('Une UE active comporte un ou deux EC.');
    }
    if (course.ecs.map((ec) => ec.code).toSet().length != course.ecs.length) {
      throw ArgumentError('Les codes EC doivent être distincts.');
    }
    for (final ec in course.ecs) {
      if (ec.code.trim().isEmpty || ec.title.trim().isEmpty || ec.credits <= 0 || ec.weights.isEmpty || ec.weights.values.any((weight) => weight <= 0) || ec.weights.values.fold(0, (sum, weight) => sum + weight) != 100) {
        throw ArgumentError('Chaque EC exige des crédits positifs et un plan totalisant 100 %.');
      }
    }
  }

  void _invalidate(String event) {
    _cohort.calculated = false;
    _cohort.validated = false;
    _cohort.published = false;
    _cohort.events.insert(0, event);
  }

  void addCourse(CelluleCourse course) {
    _validateCourse(course);
    if (courses.any((existing) => existing.id == course.id || existing.code.toUpperCase() == course.code.toUpperCase())) {
      throw ArgumentError('Ce code UE existe déjà dans cette classe.');
    }
    _cohort.courses.add(course);
    _invalidate('Ajout local de l’UE ${course.code} au catalogue de démonstration.');
    notifyListeners();
  }

  void replaceCourse(CelluleCourse course) {
    _validateCourse(course);
    final index = _cohort.courses.indexWhere((existing) => existing.id == course.id);
    if (index < 0) throw ArgumentError('UE inconnue.');
    final previous = courses[index];
    if (previous.code != course.code) throw ArgumentError('Créer une nouvelle version pour changer le code UE.');
    _cohort.courses[index] = course;
    _invalidate('Modification locale de ${course.code} ; calcul et validation à reprendre.');
    notifyListeners();
  }

  bool calculate() {
    _cohort.calculated = true;
    _cohort.validated = false;
    _cohort.published = false;
    final count = students.where((s) => result(s).complete).length;
    _cohort.events.insert(0, 'Calcul de démonstration : $count/${students.length} dossiers complets.');
    notifyListeners();
    return complete;
  }

  /// Explicit sample data replacement, never a correction of real grades.
  void loadCompleteDemo() {
    for (var index = 0; index < _cohort.students.length; index++) {
      final student = _cohort.students[index];
      _cohort.students[index] = CelluleStudent(
        id: student.id, matricule: student.matricule, name: student.name,
        scores: Map.unmodifiable({for (final course in courses) course.code: student.scores[course.code] ?? 60}),
        eliminated: student.eliminated,
      );
    }
    _invalidate('Jeu d’exemple complété localement ; aucune note serveur modifiée.');
    notifyListeners();
  }

  bool validatePublication() {
    if (!calculated || !complete || published) return false;
    _cohort.validated = true;
    _cohort.events.insert(0, 'Contrôle du lot validé dans la démonstration. Aucune signature apposée.');
    notifyListeners();
    return true;
  }

  bool simulatePublication() {
    if (!calculated || !validated || !complete || published) return false;
    _cohort.published = true;
    _cohort.events.insert(0, 'Simulation de publication terminée. Aucun résultat diffusé.');
    notifyListeners();
    return true;
  }
}

List<CelluleCourse> _demoCourses(String classId) {
  final level = classId.startsWith('L1') ? '1' : classId.startsWith('L2') ? '2' : classId.startsWith('M1') ? '4' : '3';
  final titles = classId.startsWith('L1')
      ? ['Initiation à l’algorithmique', 'Mathématiques pour l’informatique', 'Architecture des ordinateurs', 'Introduction aux réseaux', 'Communication scientifique', 'Statistiques descriptives']
      : ['Algorithmique avancée & Théorie des graphes', 'Conception orientée objet & Modélisation UML', 'Systèmes d’exploitation & Programmation système', 'Réseaux locaux & Protocoles Internet', 'Anglais technique & Droit des TIC', 'Probabilités & Statistique'];
  const credits = [6, 6, 5, 5, 5, 3];
  const teachers = ['Pr. ETOUNDI Joseph', 'Dr. BELLA Christine', 'M. NGATCHOU Frank', 'Dr. TSOPMO Alain', 'Mme FOE Berthe', 'Pr. NANA Roger'];
  return List.generate(6, (index) {
    final code = index == 5 ? 'MAT${level}11' : 'INF$level${(index * 2 + 1).toString().padLeft(2, '0')}';
    return CelluleCourse(
      id: code, code: code, title: titles[index], category: index == 4 ? 'OPTIONNELLE' : 'FONDAMENTALE',
      credits: credits[index], teacher: teachers[index], hours: index == 5 ? 30 : 60, active: true,
      ecs: List.unmodifiable([
        CelluleEc(code: '$code.1', title: index == 0 ? 'Algorithmique' : titles[index], teacher: teachers[index], credits: index == 0 ? 3 : credits[index], weights: index == 5 ? const {'CC': 30, 'SN': 70} : const {'CC': 20, 'TP': 30, 'SN': 50}),
        if (index == 0) CelluleEc(code: '$code.2', title: 'Structures de données & Graphes', teacher: teachers[index], credits: 3, weights: const {'CC': 30, 'SN': 70}),
      ]),
    );
  });
}

List<CelluleStudent> _demoStudents(String classId, List<CelluleCourse> courses) {
  const names = ['BEKOLO Aristide Junior', 'KAMGA Alain Patrick', 'NGUEME ATOUA Christian', 'FOUDA Marie Claire', 'TCHINDA Steve Valdo'];
  const matricules = ['21U2840', '19U1984', '21U2419', '20U1108', '21U3192'];
  const scores = <List<int?>>[
    [83, 75, 86, 70, 78, 80], [60, 53, 55, 68, null, 50],
    [58, 28, 60, 50, 48, 51], [70, 68, null, 75, 63, 65],
    [65, 63, 69, 60, 71, 60],
  ];
  return List.generate(names.length, (index) => CelluleStudent(
    id: '$classId-${matricules[index]}', matricule: matricules[index], name: names[index],
    scores: Map.unmodifiable({for (var c = 0; c < courses.length; c++) courses[c].code: scores[index][c]}),
  ));
}
