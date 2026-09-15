part of 'main.dart';

/// Consolidation des résultats transmis par les enseignants, côté scolarité.
class CelluleNumerisationContent extends StatefulWidget {
  const CelluleNumerisationContent({super.key});

  @override
  State<CelluleNumerisationContent> createState() =>
      _CelluleNumerisationContentState();
}

class _CelluleNumerisationContentState
    extends State<CelluleNumerisationContent> {
  String _search = '';
  String _filter = 'Tous';

  List<CelluleCourse> _courses(CelluleWorkspace workspace) =>
      workspace.courses.where((course) => course.active).toList();

  void _calculate(CelluleWorkspace workspace) {
    final complete = workspace.calculate();
    celluleNotice(
      context,
      complete
          ? 'Calcul MGP terminé pour le jeu de démonstration. Les résultats '
              'semestriels sont disponibles dans les bulletins.'
          : 'Le registre contient des résultats manquants. Consultez l’audit '
              'avant de finaliser le calcul MGP.',
    );
  }

  Future<void> _importDemo(CelluleWorkspace workspace) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: paperLight,
        title: const Text('Import de démonstration'),
        content: const Text(
          'Le traitement des fichiers Excel et CSV n’est pas encore connecté. '
          'Vous pouvez compléter le jeu local avec des résultats fictifs pour '
          'essayer le calcul et la publication. Aucun fichier ne sera importé '
          'et aucune note réelle ne sera modifiée. La validation précédente '
          'devra être renouvelée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Compléter les données fictives'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    workspace.loadCompleteDemo();
    celluleNotice(context, 'Jeu fictif complété. Relancez le calcul MGP.');
  }

  void _audit(CelluleWorkspace workspace) {
    final courses = _courses(workspace);
    final issues = <({String title, String detail, Color color})>[];
    for (final student in workspace.students) {
      for (final course in courses) {
        final score = student.scores[course.code];
        if (student.eliminated.contains(course.code)) {
          issues.add((
            title: 'Absence au rattrapage · ${course.code}',
            detail:
                '${student.matricule} · ${student.name} — Statut EL, 0 point.',
            color: red,
          ));
        } else if (score == null) {
          issues.add((
            title: 'Résultat manquant · ${course.code}',
            detail: '${student.matricule} · ${student.name} — MGP incomplète.',
            color: pending,
          ));
        } else if (score < 35) {
          issues.add((
            title: 'Résultat UE sous 35/100 · ${course.code}',
            detail: '${student.matricule} · ${student.name} — $score/100. '
                'À prendre en compte lors de la délibération annuelle.',
            color: red,
          ));
        }
      }
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: paperLight,
        title: Text('Audit d’intégrité · ${issues.length} signalement(s)'),
        content: SizedBox(
          width: 590,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contrôle des résultats UE arrondis sur 100. Les corrections '
                  'de notes relèvent de l’enseignant habilité.',
                  style: TextStyle(color: slate),
                ),
                const SizedBox(height: 16),
                if (issues.isEmpty)
                  const Text('Aucun résultat manquant, EL ou sous 35/100.',
                      style: TextStyle(color: valid)),
                for (final issue in issues)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    color: issue.color.withValues(alpha: .08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue.title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: issue.color)),
                        const SizedBox(height: 5),
                        Text(issue.detail),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => celluleNotice(
                dialogContext,
                'Demandez la rectification à l’enseignant de l’EC concerné. '
                'L’agent de scolarité ne peut pas modifier les notes.'),
            child: const Text('Procédure de correction'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer l’audit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = CelluleScope.of(context);
    final courses = _courses(workspace);
    final allStudents = workspace.students;
    final total = courses.length * allStudents.length;
    final entered = allStudents.fold<int>(
        0,
        (count, student) =>
            count +
            courses
                .where((course) =>
                    student.scores[course.code] != null ||
                    student.eliminated.contains(course.code))
                .length);
    final missing = total - entered;
    final underThreshold = allStudents.fold<int>(
        0,
        (count, student) =>
            count +
            courses
                .where((course) =>
                    !student.eliminated.contains(course.code) &&
                    student.scores[course.code] != null &&
                    student.scores[course.code]! < 35)
                .length);
    final eliminated = allStudents.fold<int>(
        0,
        (count, student) =>
            count +
            courses
                .where((course) => student.eliminated.contains(course.code))
                .length);
    final visible = allStudents.where((student) {
      final result = workspace.result(student);
      final matchesQuery = '${student.matricule} ${student.name}'
          .toLowerCase()
          .contains(_search.trim().toLowerCase());
      final matchesFilter = switch (_filter) {
        'Complets' => result.complete,
        'Incomplets' => !result.complete,
        'Sous seuil / EL' => result.belowThreshold || result.hasEl,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CelluleHeading(
          eyebrow: 'REGISTRE MATRICIEL · FEUILLE DE DÉLIBÉRATION',
          title: 'Numérisation & Moteur de Calcul MGP',
          subtitle: 'Échelle réglementaire 4,00 · ${workspace.classLabel} · '
              'Résultats semestriels de démonstration',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _audit(workspace),
              icon: const Icon(Icons.rule_outlined, size: 17),
              label: const Text('Auditer les écarts'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: red),
              onPressed: () => _calculate(workspace),
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('Lancer le calcul global MGP'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  workspace.openSection(CelluleSection.publications),
              icon: const Icon(Icons.lock_outline, size: 17),
              label: const Text('Validation & publication'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: ink),
              onPressed: () => celluleDemoNotice(
                  context, 'Export du bordereau consolidé .xlsx'),
              icon: const Icon(Icons.download_outlined, size: 17),
              label: const Text('Bordereau .xlsx · démo'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _formula(),
        const SizedBox(height: 22),
        CelluleColumns(
          flex: const [4, 5, 3],
          breakpoint: 1120,
          children: [
            _context(workspace, courses, total == 0 ? 0 : entered / total),
            _upload(workspace),
            _integrity(workspace, missing, underThreshold, eliminated),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth >= 720) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unités d’Enseignement (UE)',
                  style: TextStyle(
                      fontFamily: 'Fraunces', fontSize: 23, color: ink)),
              const SizedBox(height: 12),
              for (final course in courses) ...[
                _courseCard(workspace, course),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
            ],
          );
        }),
        _register(workspace, courses, visible),
        const SizedBox(height: 24),
        CelluleColumns(
          flex: const [3, 2],
          children: [
            _distribution(workspace, courses),
            _journal(workspace),
          ],
        ),
      ],
    );
  }

  Widget _formula() => CellulePanel(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: red.withValues(alpha: .09),
                child: const Text('Σ',
                    style: TextStyle(
                        fontFamily: 'serif',
                        color: red,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pondération des résultats LMD',
                      style: TextStyle(
                          fontFamily: 'Fraunces', fontSize: 21, color: ink)),
                  SizedBox(height: 8),
                  Text('MGP = Σ (points du grade × crédits UE) / Σ crédits UE',
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 12, color: ink)),
                  SizedBox(height: 5),
                  Text(
                      'Toutes les UE inscrites comptent, y compris les UE non acquises '
                      'et EL. Une note manquante empêche de finaliser la MGP.',
                      style:
                          TextStyle(color: slate, fontSize: 12, height: 1.5)),
                ],
              )),
            ],
          );
          const rules = Wrap(spacing: 24, runSpacing: 14, children: [
            _NumerisationRule(
                label: 'MINIMUM UE POUR L’ADMISSION ANNUELLE',
                value: '35/100 · soit 7/20',
                color: red),
            _NumerisationRule(
                label: 'UE ACQUISE',
                value: '≥ 50/100 · C · 2,00 points',
                color: valid),
          ]);
          if (constraints.maxWidth < 1050) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const Divider(height: 30), rules]);
          }
          return Row(children: [
            Expanded(child: title),
            const SizedBox(width: 24),
            const SizedBox(width: 280, child: rules)
          ]);
        }),
      );

  Widget _context(CelluleWorkspace workspace, List<CelluleCourse> courses,
          double enteredFraction) =>
      CellulePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _NumerisationPanelTitle(
              icon: Icons.fact_check_outlined,
              text: '1. Cible d’Évaluation LMD'),
          const SizedBox(height: 16),
          const CelluleBadge(label: 'SESSION OUVERTE'),
          const SizedBox(height: 16),
          const _NumerisationField(
              label: 'FACULTÉ & DÉPARTEMENT',
              value: 'FS · Mathématiques & Informatique'),
          const SizedBox(height: 12),
          _NumerisationField(
              label: 'FILIÈRE · CLASSE · SEMESTRE',
              value: '${workspace.classLabel} · Semestre 5'),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _NumerisationSmallMetric(
                label: 'Étudiants', value: '${workspace.students.length}'),
            _NumerisationSmallMetric(
                label: 'UE actives', value: '${courses.length}'),
            _NumerisationSmallMetric(
                label: 'Renseigné',
                value: '${(enteredFraction * 100).toStringAsFixed(1)} %',
                color: gold),
          ]),
          const SizedBox(height: 18),
          LinearProgressIndicator(
              value: enteredFraction,
              color: valid,
              backgroundColor: paper,
              minHeight: 3),
          const SizedBox(height: 12),
          Text(
              '${courses.fold<int>(0, (sum, course) => sum + course.credits)} crédits '
              'ECTS · jeu local de démonstration',
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 10, color: slate)),
        ]),
      );

  Widget _upload(CelluleWorkspace workspace) => CellulePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _NumerisationPanelTitle(
              icon: Icons.upload_file_outlined,
              text: '2. Téléversement des Bordereaux'),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
                color: paper.withValues(alpha: .52),
                border: Border.all(color: ink.withValues(alpha: .12))),
            child: Column(children: [
              Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: red.withValues(alpha: .08)),
                  child: const Icon(Icons.cloud_upload_outlined,
                      color: red, size: 27)),
              const SizedBox(height: 13),
              const Text('Bordereaux enseignants',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Fraunces', fontSize: 21, color: ink)),
              const SizedBox(height: 8),
              const Text(
                  'Formats prévus : .xlsx et .csv\n'
                  'Résultats UE consolidés à partir des EC',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: slate, fontSize: 12, height: 1.5)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: () => _importDemo(workspace),
                  icon: const Icon(Icons.file_upload_outlined, size: 17),
                  label: const Text('Simuler un import')),
            ]),
          ),
          const SizedBox(height: 12),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: gold, size: 17),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Aucun fichier transmis. Les données présentées '
                    'sont fictives ; seules les notes des enseignants habilités '
                    'pourront alimenter le registre officiel.',
                    style: TextStyle(fontSize: 11, color: slate, height: 1.5))),
          ]),
        ]),
      );

  Widget _integrity(CelluleWorkspace workspace, int missing, int underThreshold,
          int eliminated) =>
      CellulePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _NumerisationPanelTitle(
              icon: Icons.verified_outlined, text: '3. Audit d’Intégrité'),
          const SizedBox(height: 16),
          CelluleBadge(
              label: '${missing + underThreshold + eliminated} SIGNALEMENT(S)',
              color:
                  missing + underThreshold + eliminated > 0 ? pending : valid),
          const SizedBox(height: 14),
          _NumerisationAlert(
              count: missing,
              title: 'Résultats manquants',
              detail: 'Calcul définitif en attente',
              color: pending),
          _NumerisationAlert(
              count: underThreshold,
              title: 'UE sous 35/100',
              detail: 'Signalement pour le bilan annuel',
              color: red),
          _NumerisationAlert(
              count: eliminated,
              title: 'Statuts EL',
              detail: 'Absence au rattrapage · 0 point',
              color: red),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: () => _audit(workspace),
              icon: const Icon(Icons.manage_search, size: 18),
              label: const Text('Examiner les écarts')),
          const SizedBox(height: 8),
          const Text('Le semestre seul ne prononce pas d’admission annuelle.',
              style: TextStyle(fontSize: 11, color: slate, height: 1.5)),
        ]),
      );

  Widget _courseCard(CelluleWorkspace workspace, CelluleCourse course) {
    final entered = workspace.students
        .where((student) =>
            student.scores[course.code] != null ||
            student.eliminated.contains(course.code))
        .length;
    return CellulePanel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 8, children: [
          Text('${course.code} · ${course.credits} ECTS',
              style: const TextStyle(fontFamily: 'monospace', color: ink)),
          CelluleBadge(
              label:
                  entered == workspace.students.length ? 'COMPLET' : 'EN COURS',
              color: entered == workspace.students.length ? valid : pending),
        ]),
        const SizedBox(height: 10),
        Text(course.title, style: const TextStyle(fontSize: 17, color: ink)),
        const SizedBox(height: 10),
        Text(
            'Promotion : $entered/${workspace.students.length} résultats reçus',
            style: const TextStyle(color: slate, fontSize: 12)),
      ]),
    );
  }

  Widget _register(CelluleWorkspace workspace, List<CelluleCourse> courses,
          List<CelluleStudent> students) =>
      CellulePanel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _NumerisationPanelTitle(
                  icon: Icons.menu_book_outlined,
                  text: 'Registre Central des Délibérations'),
              const SizedBox(height: 14),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final filter in [
                  'Tous',
                  'Complets',
                  'Incomplets',
                  'Sous seuil / EL'
                ])
                  ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                      selectedColor: ink,
                      labelStyle: TextStyle(
                          color: _filter == filter ? Colors.white : ink,
                          fontSize: 11),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                      hintText: 'Filtrer par matricule ou nom…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: paper,
                      isDense: true,
                      border: InputBorder.none),
                ),
              ),
            ]),
          ),
          if (students.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun étudiant ne correspond à cette recherche.',
                    style: TextStyle(color: slate)))
          else
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(children: [
                  for (final student in students)
                    _studentCard(workspace, courses, student),
                ]);
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(paper),
                    headingRowHeight: 67,
                    dataRowMinHeight: 76,
                    dataRowMaxHeight: 90,
                    columnSpacing: 18,
                    horizontalMargin: 16,
                    columns: [
                      const DataColumn(
                          label: _NumerisationTableLabel('MATRICULE')),
                      const DataColumn(
                          label: _NumerisationTableLabel('NOM & PRÉNOMS')),
                      for (final course in courses)
                        DataColumn(
                            label: _NumerisationTableLabel(
                                '${course.code}\n${course.credits} CR · /100')),
                      const DataColumn(
                          label: _NumerisationTableLabel('CRÉDITS\nACQUIS')),
                      const DataColumn(
                          label: _NumerisationTableLabel('MGP\n/4,00')),
                      const DataColumn(
                          label: _NumerisationTableLabel(
                              'SITUATION\nSEMESTRIELLE')),
                    ],
                    rows: students.map((student) {
                      final result = workspace.result(student);
                      return DataRow(
                        color: WidgetStatePropertyAll(!result.complete
                            ? pending.withValues(alpha: .065)
                            : result.belowThreshold || result.hasEl
                                ? red.withValues(alpha: .04)
                                : Colors.transparent),
                        cells: [
                          DataCell(Text(student.matricule,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12))),
                          DataCell(SizedBox(
                              width: 180,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(student.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: ink)),
                                    const SizedBox(height: 5),
                                    Text(
                                        !result.complete
                                            ? 'Bordereau incomplet'
                                            : 'Résultats consolidés',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: !result.complete
                                                ? red
                                                : slate)),
                                  ]))),
                          for (final course in courses)
                            DataCell(_score(student, course)),
                          DataCell(Text(
                              '${result.acquiredCredits} / ${result.totalCredits}',
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: result.acquiredCredits ==
                                          result.totalCredits
                                      ? valid
                                      : gold))),
                          DataCell(_mgp(workspace, student)),
                          DataCell(_studentStatus(workspace, student)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 24, runSpacing: 8, children: [
              Text(
                  'Étudiants affichés : ${students.length} sur ${workspace.students.length}',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11, color: ink)),
              Text(
                  workspace.calculated
                      ? '● Calcul global effectué'
                      : '○ Calcul global à finaliser',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: workspace.calculated ? valid : gold)),
              const Text('Notes UE entières sur 100 · Grades officiels LMD',
                  style: TextStyle(fontSize: 11, color: slate)),
            ]),
          ),
        ]),
      );

  Widget _score(CelluleStudent student, CelluleCourse course) {
    final score = student.scores[course.code];
    final isEl = student.eliminated.contains(course.code);
    final grade = isEl ? 'EL' : GradeResult.gradeForScore(score);
    final points = isEl ? 0.0 : GradeResult.pointsForScore(score);
    final color = isEl || (score != null && score < 35)
        ? red
        : score == null
            ? pending
            : score >= 50
                ? valid
                : gold;
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEl ? 'EL' : score?.toString() ?? '—',
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 14, color: color)),
          const SizedBox(height: 4),
          Text(
              isEl
                  ? '0,00 pt'
                  : score == null
                      ? 'MANQUANT'
                      : '$grade · ${points?.toStringAsFixed(2) ?? '—'}',
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9, color: color)),
        ]);
  }

  Widget _mgp(CelluleWorkspace workspace, CelluleStudent student) {
    final result = workspace.result(student);
    return Text(
        !result.complete
            ? 'INC.'
            : !workspace.calculated
                ? 'À calculer'
                : result.mgp?.toStringAsFixed(2).replaceAll('.', ',') ?? '—',
        style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: !result.complete ? red : ink));
  }

  Widget _studentStatus(CelluleWorkspace workspace, CelluleStudent student) {
    final result = workspace.result(student);
    final (label, color) = !result.complete
        ? ('INCOMPLET', pending)
        : result.hasEl
            ? ('EL · À EXAMINER', red)
            : result.belowThreshold
                ? ('UE SOUS 35/100', red)
                : result.acquiredCredits == result.totalCredits
                    ? ('CRÉDITS ACQUIS', valid)
                    : ('CRÉDITS À ACQUÉRIR', gold);
    return CelluleBadge(label: label, color: color);
  }

  Widget _studentCard(CelluleWorkspace workspace, List<CelluleCourse> courses,
      CelluleStudent student) {
    final result = workspace.result(student);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: paper.withValues(alpha: .35),
          border: Border.all(color: ink.withValues(alpha: .1)),
          borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(student.matricule,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: slate)),
        const SizedBox(height: 5),
        Text(student.name,
            style: const TextStyle(
                color: ink, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 12, children: [
          for (final course in courses)
            SizedBox(
                width: 77,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.code,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: slate)),
                      const SizedBox(height: 6),
                      _score(student, course),
                    ])),
        ]),
        const Divider(height: 25),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('MGP : ',
                  style: TextStyle(color: slate, fontSize: 12)),
              _mgp(workspace, student),
            ]),
            Text('${result.acquiredCredits}/${result.totalCredits} ECTS',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: ink)),
            _studentStatus(workspace, student),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            workspace.selectStudent(workspace.students.indexOf(student));
            workspace.openSection(CelluleSection.bulletin);
          },
          icon: const Icon(Icons.receipt_long_outlined, size: 16),
          label: const Text('Voir le bulletin'),
        ),
      ]),
    );
  }

  Widget _distribution(
      CelluleWorkspace workspace, List<CelluleCourse> courses) {
    const groups = ['A', 'A−', 'B+', 'B', 'B−', 'C+', 'C', 'C−/D+/D/E'];
    final counts = List<int>.filled(groups.length, 0);
    for (final student in workspace.students) {
      for (final course in courses) {
        final grade = GradeResult.gradeForScore(student.scores[course.code]);
        if (student.eliminated.contains(course.code)) {
          counts[counts.length - 1]++;
        } else if (grade != null) {
          final normalized = grade.replaceAll('-', '−');
          final index = groups.indexOf(normalized);
          counts[index < 0 ? counts.length - 1 : index]++;
        }
      }
    }
    final maximum = counts.fold<int>(1, (a, b) => a > b ? a : b);
    const colors = [
      valid,
      Color(0xFF60836B),
      gold,
      Color(0xFFB78C48),
      Color(0xFF7D7E6D),
      Color(0xFF64718A),
      Color(0xFF8790A0),
      red
    ];
    return CellulePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _NumerisationPanelTitle(
            icon: Icons.bar_chart, text: 'Distribution des Grades LMD (S5)'),
        const SizedBox(height: 8),
        Text(
            '${counts.fold<int>(0, (sum, count) => sum + count)} résultats UE '
            'renseignés · effectifs du jeu de démonstration',
            style: const TextStyle(fontSize: 11, color: slate)),
        const SizedBox(height: 25),
        SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < groups.length; index++)
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${counts[index]}',
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          const SizedBox(height: 5),
                          Container(
                              height: counts[index] == 0
                                  ? 2
                                  : 125 * counts[index] / maximum,
                              color: colors[index]),
                          const SizedBox(height: 8),
                          SizedBox(
                              height: 20,
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                      index == groups.length - 1
                                          ? '< C / EL'
                                          : groups[index],
                                      style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          color: colors[index])))),
                        ]),
                  )),
              ],
            )),
        const Divider(height: 25),
        const Text(
            'A = 4,00 · A− = 3,70 · B+ = 3,30 · B = 3,00 · '
            'B− = 2,70 · C+ = 2,30 · C = 2,00',
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: slate,
                height: 1.6)),
        const SizedBox(height: 8),
        const Text(
            'Acquisition des crédits : UE ≥ 50/100. '
            'Les situations annuelles nécessitent les deux semestres.',
            style: TextStyle(fontSize: 11, color: valid, height: 1.5)),
      ]),
    );
  }

  Widget _journal(CelluleWorkspace workspace) => CellulePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _NumerisationPanelTitle(
              icon: Icons.history_edu_outlined, text: 'Journal des Opérations'),
          const SizedBox(height: 15),
          const CelluleBadge(label: 'PISTE D’AUDIT LOCALE', color: slate),
          const SizedBox(height: 12),
          if (workspace.events.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucune opération sur ce registre.',
                    style: TextStyle(color: slate, fontSize: 12))),
          for (final event in workspace.events.reversed.take(4))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 7),
              color: paper.withValues(alpha: .55),
              child: Text(event,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: ink,
                      height: 1.5)),
            ),
          const SizedBox(height: 8),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: red.withValues(alpha: .08),
              child: const Text(
                  'Démonstration · aucune signature numérique officielle',
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 10, color: red))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: () =>
                  workspace.openSection(CelluleSection.publications),
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Préparer la publication')),
        ]),
      );
}

class _NumerisationPanelTitle extends StatelessWidget {
  const _NumerisationPanelTitle({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ink, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontFamily: 'Fraunces', fontSize: 20, color: ink)))
        ],
      );
}

class _NumerisationRule extends StatelessWidget {
  const _NumerisationRule(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 9, color: slate)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: color)),
        ],
      );
}

class _NumerisationField extends StatelessWidget {
  const _NumerisationField({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: .4,
                  color: slate)),
          const SizedBox(height: 5),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              color: paper,
              child: Text(value,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: ink,
                      height: 1.5))),
        ],
      );
}

class _NumerisationSmallMetric extends StatelessWidget {
  const _NumerisationSmallMetric(
      {required this.label, required this.value, this.color = ink});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(9),
        color: paper,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 10, color: slate)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Fraunces', fontSize: 24, color: color)),
        ]),
      );
}

class _NumerisationAlert extends StatelessWidget {
  const _NumerisationAlert(
      {required this.count,
      required this.title,
      required this.detail,
      required this.color});
  final int count;
  final String title, detail;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 7),
        color: (count > 0 ? color : valid).withValues(alpha: .07),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: count > 0 ? color : valid)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11, color: count > 0 ? color : valid)),
                const SizedBox(height: 4),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 10, color: slate, height: 1.4)),
              ])),
        ]),
      );
}

class _NumerisationTableLabel extends StatelessWidget {
  const _NumerisationTableLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          letterSpacing: .6,
          height: 1.6,
          color: ink));
}
