part of 'main.dart';

class CelluleStructureContent extends StatefulWidget {
  const CelluleStructureContent({super.key});

  @override
  State<CelluleStructureContent> createState() => _CelluleStructureContentState();
}

class _CelluleStructureContentState extends State<CelluleStructureContent> {
  int tab = 0;
  String treeQuery = '';
  final Map<String, String> rooms = {};

  @override
  Widget build(BuildContext context) {
    final workspace = CelluleScope.of(context);
    final courses = workspace.courses;
    final credits = courses.fold<int>(0, (sum, course) => sum + course.credits);
    final hours = courses.fold<int>(0, (sum, course) => sum + course.hours);
    final teachers = courses.expand((course) => course.ecs).map((ec) => ec.teacher).where((name) => name.isNotEmpty).toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CelluleHeading(
        eyebrow: 'RÉFÉRENTIEL DES STRATES · ANNÉE 2024–2025',
        title: 'Structure & Hiérarchie Académique',
        subtitle: 'Université de Douala  /  Faculté des Sciences  /  Informatique',
        actions: [
          OutlinedButton.icon(onPressed: () => _showAcademicHierarchy(context), icon: const Icon(Icons.account_tree_outlined, size: 17), label: const Text('Organigramme')),
          FilledButton.icon(onPressed: () => _editAcademicCourse(context, workspace), icon: const Icon(Icons.add, size: 18), label: const Text('Nouvelle UE / EC')),
        ],
      ),
      const SizedBox(height: 22),
      CelluleColumns(flex: const [3, 7], breakpoint: 1050, children: [
        _hierarchy(workspace),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, runSpacing: 8, children: [
              const CelluleBadge(label: 'FILIÈRE INFORMATIQUE', color: red),
              CelluleBadge(label: workspace.selectedClass.startsWith('M') ? 'CYCLE MASTER' : 'CYCLE LICENCE'),
            ]),
            const SizedBox(height: 16),
            Text('Classe : ${workspace.classLabel}', style: const TextStyle(fontFamily: 'Fraunces', fontSize: 27, color: ink)),
            const SizedBox(height: 10),
            const Text('Fiche d’affectation pédagogique, unités d’enseignement et éléments constitutifs. Les modifications de cette maquette sont conservées dans la démonstration.', style: TextStyle(color: slate, height: 1.5)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
            LayoutBuilder(builder: (context, constraints) => Wrap(spacing: 18, runSpacing: 18, children: [
              _AcademicInlineMetric(label: 'UNITÉS D’ENSEIGNEMENT', value: '${courses.length} UE', detail: '${courses.expand((c) => c.ecs).length} éléments constitutifs'),
              _AcademicInlineMetric(label: 'CRÉDITS DU PROGRAMME', value: '$credits ECTS', detail: 'Cible semestre : 30 crédits', color: credits == 30 ? valid : gold),
              _AcademicInlineMetric(label: 'ENSEIGNANTS AFFECTÉS', value: '${teachers.length} enseignants', detail: 'Affectation par EC'),
              _AcademicInlineMetric(label: 'VOLUME DE CONTACT', value: '$hours heures', detail: 'Cours / travaux dirigés / TP'),
            ])),
          ])),
          const SizedBox(height: 16),
          _AcademicTabs(selected: tab, onChanged: (value) => setState(() => tab = value)),
          const SizedBox(height: 14),
          if (tab == 0) _programme(context, workspace, credits),
          if (tab == 1) _assignments(context, workspace),
          if (tab == 2) _rooms(context, workspace),
          const SizedBox(height: 16),
          CellulePanel(child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 14, children: [
            const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit_note_outlined, color: ink), SizedBox(width: 10), Flexible(child: Text('Maquette de démonstration\nVérifier les crédits, les EC et les plans d’évaluation.', style: TextStyle(fontSize: 12, color: slate)))]),
            FilledButton.icon(onPressed: () => _checkAcademicProgramme(context, workspace), icon: const Icon(Icons.fact_check_outlined, size: 18), label: const Text('Vérifier la maquette')),
          ])),
        ]),
      ]),
    ]);
  }

  Widget _hierarchy(CelluleWorkspace workspace) => CellulePanel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Référentiel des Strates', style: TextStyle(fontFamily: 'Fraunces', fontSize: 23, color: ink)),
      SizedBox(height: 7),
      Text('ARBORESCENCE ACADÉMIQUE LMD', style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 1, color: slate)),
    ])),
    const Divider(height: 1),
    Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (value) => setState(() => treeQuery = value.toLowerCase()), decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.filter_alt_outlined, size: 19), hintText: 'Filtrer code ou libellé', border: OutlineInputBorder()))),
    const _AcademicTreeNode(icon: Icons.account_balance_outlined, title: 'Université de Douala', depth: 0, emphasis: true),
    const _AcademicTreeNode(icon: Icons.domain_outlined, title: 'Faculté des Sciences', depth: 1),
    const _AcademicTreeNode(icon: Icons.hub_outlined, title: 'Dépt. Mathématiques & Informatique', depth: 2),
    const _AcademicTreeNode(icon: Icons.terminal_outlined, title: 'Filière Informatique', depth: 3),
    for (final entry in _academicClasses.entries)
      if ('${entry.key} ${entry.value}'.toLowerCase().contains(treeQuery))
        _AcademicTreeNode(icon: Icons.groups_outlined, title: entry.value, depth: 4, selected: workspace.selectedClass == entry.key, onTap: () => workspace.selectClass(entry.key)),
    if (!_academicClasses.entries.any((entry) => '${entry.key} ${entry.value}'.toLowerCase().contains(treeQuery)))
      const Padding(padding: EdgeInsets.all(18), child: Text('Aucune classe ne correspond.', style: TextStyle(color: slate))),
    const Divider(height: 22),
    Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 16), child: Text('${_academicClasses.length} classes · Jeu de démonstration', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate))),
  ]));

  Widget _programme(BuildContext context, CelluleWorkspace workspace, int credits) => CellulePanel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.all(18), child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
      const Text('Maquette Pédagogique — Programme de la classe', style: TextStyle(fontFamily: 'Fraunces', fontSize: 21, color: ink)),
      OutlinedButton.icon(onPressed: () => _editAcademicCourse(context, workspace), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter une UE')),
    ])),
    _AcademicCourseRegister(courses: workspace.courses, workspace: workspace, compact: true),
    Container(padding: const EdgeInsets.all(16), color: ink.withValues(alpha: .055), child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 8, children: [
      Text('TOTAL DU PROGRAMME : $credits ECTS', style: const TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold)),
      Text('${workspace.courses.length} UE · ${workspace.courses.where((c) => c.active).length} actives', style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 12)),
    ])),
  ]));

  Widget _assignments(BuildContext context, CelluleWorkspace workspace) => CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Affectations des Enseignants', style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, color: ink)),
    const SizedBox(height: 8),
    const Text('Désignez un enseignant pour chaque EC de la classe sélectionnée.', style: TextStyle(color: slate)),
    const SizedBox(height: 18),
    for (final course in workspace.courses)
      for (final ec in course.ecs)
        Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: ink.withValues(alpha: .15)), color: paper.withValues(alpha: .35)), child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
          SizedBox(width: 265, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${course.code} / ${ec.code}', style: const TextStyle(fontFamily: 'monospace', color: red, fontSize: 11)), const SizedBox(height: 4), Text(ec.title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(ec.teacher.isEmpty ? 'Enseignant à affecter' : ec.teacher, style: TextStyle(color: ec.teacher.isEmpty ? gold : slate, fontSize: 12))])),
          OutlinedButton.icon(onPressed: () => _assignAcademicTeacher(context, workspace, course, ec), icon: const Icon(Icons.person_add_alt_1_outlined, size: 17), label: const Text('Affecter')),
        ])),
  ]));

  Widget _rooms(BuildContext context, CelluleWorkspace workspace) => CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Planning des Amphis & Salles TP', style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, color: ink)),
    const SizedBox(height: 8),
    const Text('Préaffectations locales de démonstration. La disponibilité des salles et les conflits horaires ne sont pas contrôlés.', style: TextStyle(color: slate)),
    const SizedBox(height: 18),
    for (final course in workspace.courses)
      Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: ink.withValues(alpha: .15))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${course.code} · ${course.title}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(key: ValueKey('${workspace.selectedClass}-${course.id}'), initialValue: rooms['${workspace.selectedClass}-${course.id}'] ?? 'À planifier', isExpanded: true, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: 'Salle de cours / TP'), items: const ['À planifier', 'Amphi 300', 'Salle Info 102', 'Laboratoire Unix', 'Salle TD 204'].map((room) => DropdownMenuItem(value: room, child: Text(room))).toList(), onChanged: (value) { if (value != null) { setState(() => rooms['${workspace.selectedClass}-${course.id}'] = value); celluleDemoNotice(context, 'Préaffectation de salle enregistrée dans cette vue.'); } }),
      ])),
  ]));
}

const _academicClasses = <String, String>{
  'L1-INFO': 'L1 Info — Tronc commun',
  'L2-INFO': 'L2 Info — Option générale',
  'L3-INFO-A': 'L3 Info — Promotion A',
  'L3-INFO-B': 'L3 Info — Promotion B',
  'M1-GL': 'M1 Génie logiciel',
};

class CelluleCatalogContent extends StatefulWidget {
  const CelluleCatalogContent({super.key});

  @override
  State<CelluleCatalogContent> createState() => _CelluleCatalogContentState();
}

class _CelluleCatalogContentState extends State<CelluleCatalogContent> {
  final search = TextEditingController();
  String category = 'TOUTES';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = CelluleScope.of(context);
    final courses = workspace.courses;
    final query = search.text.trim().toLowerCase();
    final filtered = courses.where((course) => (category == 'TOUTES' || course.category == category) && '${course.code} ${course.title} ${course.ecs.map((ec) => '${ec.code} ${ec.title}').join(' ')}'.toLowerCase().contains(query)).toList();
    final credits = courses.fold<int>(0, (sum, course) => sum + course.credits);
    final teachers = courses.expand((course) => course.ecs).map((ec) => ec.teacher).where((name) => name.isNotEmpty).toSet();
    final fundamental = courses.where((course) => course.category == 'FONDAMENTALE').fold<int>(0, (sum, course) => sum + course.credits);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CelluleHeading(eyebrow: 'RÉFÉRENTIEL PÉDAGOGIQUE LMD', title: 'Catalogue des Unités d’Enseignement & EC', subtitle: 'Définition des maquettes, crédits, plans d’évaluation par EC et affectations des enseignants.', actions: [
        OutlinedButton.icon(onPressed: () => celluleDemoNotice(context, 'Export de la maquette simulé : aucun fichier n’est généré.'), icon: const Icon(Icons.file_download_outlined, size: 18), label: const Text('Exporter maquette')),
        FilledButton.icon(onPressed: () => _editAcademicCourse(context, workspace), icon: const Icon(Icons.add_circle_outline, size: 18), label: const Text('Nouvelle UE / EC')),
      ]),
      const SizedBox(height: 22),
      CelluleColumns(breakpoint: 800, gap: 14, children: [
        CelluleMetric(label: 'VOLUME DU PROGRAMME', value: '${courses.length}', detail: '${courses.where((course) => course.active).length} UE actives · ${courses.expand((course) => course.ecs).length} EC', icon: Icons.account_tree_outlined),
        CelluleMetric(label: 'TOTAL DES CRÉDITS', value: '$credits ECTS', detail: 'Cible : 30 crédits / semestre', color: credits == 30 ? valid : gold, icon: Icons.workspace_premium_outlined),
        const CelluleMetric(label: 'PLANS D’ÉVALUATION', value: '100 %', detail: 'Pondérations configurées par EC', color: red, icon: Icons.rule_outlined),
        CelluleMetric(label: 'CORPS ENSEIGNANT', value: '${teachers.length}', detail: 'Enseignants affectés aux EC', icon: Icons.badge_outlined),
      ]),
      const SizedBox(height: 22),
      CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, children: [
          const Text('▽ FILTRES DU REGISTRE PÉDAGOGIQUE', style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: .7, color: ink)),
          TextButton.icon(onPressed: () => setState(() { search.clear(); category = 'TOUTES'; }), icon: const Icon(Icons.restart_alt, size: 16), label: const Text('Réinitialiser les filtres')),
        ]),
        const Divider(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth < 600 ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
          return Wrap(spacing: 12, runSpacing: 14, children: [
            SizedBox(width: fieldWidth, child: DropdownButtonFormField<String>(key: ValueKey(workspace.selectedClass), initialValue: workspace.selectedClass, isExpanded: true, decoration: const InputDecoration(labelText: 'Classe / programme', border: OutlineInputBorder(), isDense: true), items: _academicClasses.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) workspace.selectClass(value); })),
            SizedBox(width: fieldWidth, child: DropdownButtonFormField<String>(key: ValueKey(category), initialValue: category, isExpanded: true, decoration: const InputDecoration(labelText: 'Nature UE', border: OutlineInputBorder(), isDense: true), items: const [DropdownMenuItem(value: 'TOUTES', child: Text('Toutes les natures')), DropdownMenuItem(value: 'FONDAMENTALE', child: Text('Fondamentale')), DropdownMenuItem(value: 'OPTIONNELLE', child: Text('Optionnelle / complémentaire'))], onChanged: (value) => setState(() => category = value ?? 'TOUTES'))),
            SizedBox(width: fieldWidth, child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Rechercher une UE ou un EC', hintText: 'Code ou intitulé…', suffixIcon: Icon(Icons.search, size: 19), border: OutlineInputBorder(), isDense: true))),
          ]);
        }),
      ])),
      const SizedBox(height: 22),
      CellulePanel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(18), child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 10, children: [
          const Text('Registre des Éléments Constitutifs', style: TextStyle(fontFamily: 'Fraunces', fontSize: 25, color: ink)),
          CelluleBadge(label: '${filtered.length} UE AFFICHÉES / ${courses.length}', color: ink),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 15), child: Text(workspace.classLabel, style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 12))),
        _AcademicCourseRegister(courses: filtered, workspace: workspace),
        Container(padding: const EdgeInsets.all(15), color: ink.withValues(alpha: .055), child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 8, children: [
          const Text('MAQUETTE DE DÉMONSTRATION · MODIFICATIONS LOCALES', style: TextStyle(fontFamily: 'monospace', color: slate, fontSize: 10)),
          Text('Volume du programme : ${courses.fold<int>(0, (sum, course) => sum + course.hours)} heures', style: const TextStyle(fontFamily: 'monospace', color: ink, fontSize: 11)),
        ])),
      ])),
      const SizedBox(height: 22),
      CelluleColumns(breakpoint: 900, children: [
        const CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Formule de la Note Finale', style: TextStyle(fontFamily: 'Fraunces', fontSize: 21, color: red)), SizedBox(height: 10),
          Text('Chaque EC possède son plan d’évaluation. La somme des pondérations doit être égale à 100 %.', style: TextStyle(color: slate, fontSize: 12)), SizedBox(height: 12),
          Text('Note EC = Σ (note × poids / 100)', style: TextStyle(fontFamily: 'monospace', color: ink, fontSize: 12)), SizedBox(height: 12),
          Text('Le minimum annuel de 35/100 s’applique au résultat arrondi de l’UE, pas à une note de CC, TP ou SN.', style: TextStyle(color: red, fontSize: 12)),
        ])),
        CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Équilibre des Crédits ECTS', style: TextStyle(fontFamily: 'Fraunces', fontSize: 21, color: gold)), const SizedBox(height: 10),
          Text('$credits crédits inscrits au programme · cible de 30 par semestre.', style: const TextStyle(color: slate, fontSize: 12)), const SizedBox(height: 14),
          Text('UE fondamentales : $fundamental ECTS', style: const TextStyle(fontSize: 12)), const SizedBox(height: 8),
          LinearProgressIndicator(value: credits == 0 ? 0 : fundamental / credits, color: red, backgroundColor: gold.withValues(alpha: .3), minHeight: 7), const SizedBox(height: 10),
          Text('UE optionnelles : ${credits - fundamental} ECTS', style: const TextStyle(fontSize: 12)), const SizedBox(height: 10),
          Text('Une UE active comporte 1 à 2 EC.', style: TextStyle(color: ink.withValues(alpha: .8), fontSize: 12)),
        ])),
        const CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Affectation & Saisie', style: TextStyle(fontFamily: 'Fraunces', fontSize: 21, color: ink)), SizedBox(height: 10),
          Text('Les enseignants sont affectés par EC et par classe. Le plan d’évaluation fournit les composantes de la saisie des notes.', style: TextStyle(color: slate, fontSize: 12)), SizedBox(height: 12),
          CelluleBadge(label: 'PARAMÉTRAGE LOCAL', color: gold), SizedBox(height: 10),
          Text('La publication et les droits d’accès définitifs nécessitent le raccordement au serveur.', style: TextStyle(color: slate, fontSize: 12)),
        ])),
      ]),
    ]);
  }
}

class _AcademicInlineMetric extends StatelessWidget {
  const _AcademicInlineMetric({required this.label, required this.value, required this.detail, this.color = ink});
  final String label;
  final String value;
  final String detail;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(width: 175, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 10)), const SizedBox(height: 7), Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 18, color: color, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(detail, style: const TextStyle(color: slate, fontSize: 11))]));
}

class _AcademicTreeNode extends StatelessWidget {
  const _AcademicTreeNode({required this.icon, required this.title, required this.depth, this.selected = false, this.emphasis = false, this.onTap});
  final IconData icon;
  final String title;
  final int depth;
  final bool selected;
  final bool emphasis;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(10 + depth * 7, 3, 10, 3), child: Material(color: selected ? red : ink.withValues(alpha: .025), child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), decoration: BoxDecoration(border: Border.all(color: selected ? red : ink.withValues(alpha: .15))), child: Row(children: [Icon(icon, size: 17, color: selected ? paperLight : (emphasis ? red : slate)), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(fontFamily: emphasis ? 'Fraunces' : null, fontSize: emphasis ? 19 : 12, color: selected ? paperLight : ink, fontWeight: selected ? FontWeight.bold : FontWeight.normal))), if (selected) const Icon(Icons.check_circle_outline, size: 15, color: paperLight)])))));
}

class _AcademicTabs extends StatelessWidget {
  const _AcademicTabs({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    const labels = ['Programme & UE', 'Affectations enseignants', 'Amphis & salles TP'];
    const icons = [Icons.menu_book_outlined, Icons.badge_outlined, Icons.calendar_month_outlined];
    final narrow = constraints.maxWidth < 560;
    return Wrap(spacing: 4, runSpacing: 4, children: List.generate(labels.length, (index) => SizedBox(width: narrow ? constraints.maxWidth : (constraints.maxWidth - 8) / 3, child: Material(color: selected == index ? paperLight : ink.withValues(alpha: .025), child: InkWell(onTap: () => onChanged(index), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected == index ? red : ink.withValues(alpha: .18), width: selected == index ? 3 : 1))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icons[index], color: selected == index ? red : slate, size: 18), const SizedBox(width: 9), Flexible(child: Text(labels[index], textAlign: TextAlign.center, style: TextStyle(color: selected == index ? ink : slate, fontWeight: selected == index ? FontWeight.bold : FontWeight.normal, fontSize: 12)))])))))));
  });
}

class _AcademicCourseRegister extends StatelessWidget {
  const _AcademicCourseRegister({required this.courses, required this.workspace, this.compact = false});
  final List<CelluleCourse> courses;
  final CelluleWorkspace workspace;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Padding(padding: EdgeInsets.all(32), child: Column(children: [Icon(Icons.search_off_outlined, color: slate, size: 30), SizedBox(height: 10), Text('Aucune UE ne correspond à cette sélection.', textAlign: TextAlign.center, style: TextStyle(color: slate))]));
    }
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 680) {
        return Column(children: [for (final course in courses) _courseCard(context, course)]);
      }
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: BoxConstraints(minWidth: constraints.maxWidth), child: DataTable(
        headingRowColor: WidgetStatePropertyAll(ink.withValues(alpha: .065)),
        headingTextStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: .7, color: ink),
        dataTextStyle: const TextStyle(fontSize: 12, color: ink),
        columnSpacing: 18, horizontalMargin: 16, dataRowMinHeight: compact ? 82 : 108, dataRowMaxHeight: compact ? 96 : 120,
        columns: [const DataColumn(label: Text('CODE UE')), const DataColumn(label: Text('INTITULÉ OFFICIEL & EC')), const DataColumn(label: Text('CRÉDITS')), if (!compact) const DataColumn(label: Text('PLAN D’ÉVALUATION / EC')), const DataColumn(label: Text('RESPONSABLE')), const DataColumn(label: Text('STATUT')), const DataColumn(label: Text('ACTIONS'))],
        rows: courses.map((course) => DataRow(cells: [
          DataCell(Text(course.code, style: const TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.w600))),
          DataCell(SizedBox(width: compact ? 195 : 235, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 5), Text(course.ecs.map((ec) => ec.code).join(' · '), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), if (!compact) Padding(padding: const EdgeInsets.only(top: 5), child: Text(course.category, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: course.category == 'FONDAMENTALE' ? red : gold)))]))),
          DataCell(Text('${course.credits} ECTS\n${course.hours} h', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
          if (!compact) DataCell(SizedBox(width: 205, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [for (final ec in course.ecs) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('${ec.code} : ${_academicWeights(ec)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10)))]))),
          DataCell(SizedBox(width: 150, child: Text(course.teacher.isEmpty ? 'À affecter' : course.teacher, style: TextStyle(color: course.teacher.isEmpty ? gold : ink)))),
          DataCell(CelluleBadge(label: course.active ? 'ACTIVE' : 'EN RÉVISION', color: course.active ? valid : gold)),
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'Modifier ${course.code}', onPressed: () => _editAcademicCourse(context, workspace, course: course), icon: const Icon(Icons.edit_note_outlined, size: 20)), IconButton(tooltip: 'Détails ${course.code}', onPressed: () => _showAcademicCourse(context, workspace, course), icon: const Icon(Icons.visibility_outlined, size: 19))])),
        ])).toList(),
      )));
    });
  }

  Widget _courseCard(BuildContext context, CelluleCourse course) => Container(margin: const EdgeInsets.fromLTRB(14, 0, 14, 14), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: paperLight, border: Border.all(color: ink.withValues(alpha: .17)), borderRadius: BorderRadius.circular(9)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [Expanded(child: Wrap(spacing: 9, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(course.code, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: red, fontWeight: FontWeight.bold)), CelluleBadge(label: '${course.credits} ECTS', color: ink)])), PopupMenuButton<String>(tooltip: 'Actions ${course.code}', onSelected: (value) { if (value == 'edit') { _editAcademicCourse(context, workspace, course: course); } else { _showAcademicCourse(context, workspace, course); } }, itemBuilder: (context) => const [PopupMenuItem(value: 'details', child: Text('Voir les EC et pondérations')), PopupMenuItem(value: 'edit', child: Text('Modifier l’UE'))])]),
    const SizedBox(height: 8), Text(course.title, style: const TextStyle(fontFamily: 'Fraunces', fontSize: 23, color: ink)),
    const SizedBox(height: 12), Container(padding: const EdgeInsets.all(10), color: ink.withValues(alpha: .05), child: Row(children: [const Icon(Icons.school_outlined, color: red, size: 18), const SizedBox(width: 8), Expanded(child: Text(course.teacher.isEmpty ? 'Enseignant à affecter' : course.teacher, style: const TextStyle(fontSize: 12))), Text('${course.hours} h', style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 11))])),
    const SizedBox(height: 12),
    for (final ec in course.ecs) Padding(padding: const EdgeInsets.only(bottom: 9), child: Text('${ec.code} · ${ec.credits} ECTS\n${ec.title}\n${_academicWeights(ec)}', style: const TextStyle(fontSize: 11, color: slate, height: 1.5))),
    Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 8, spacing: 10, children: [CelluleBadge(label: course.category, color: course.category == 'FONDAMENTALE' ? red : gold), CelluleBadge(label: course.active ? 'ACTIVE' : 'EN RÉVISION', color: course.active ? valid : gold)]),
  ]));
}

String _academicWeights(CelluleEc ec) => ec.weights.entries.where((entry) => entry.value > 0).map((entry) => '${entry.key} ${entry.value} %').join(' · ');

void _showAcademicHierarchy(BuildContext context) {
  showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Organigramme académique'), content: const SizedBox(width: 450, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    _AcademicTreeNode(icon: Icons.account_balance_outlined, title: 'Université de Douala', depth: 0, emphasis: true),
    _AcademicTreeNode(icon: Icons.domain_outlined, title: 'Faculté des Sciences', depth: 1),
    _AcademicTreeNode(icon: Icons.hub_outlined, title: 'Dépt. Mathématiques & Informatique', depth: 2),
    _AcademicTreeNode(icon: Icons.terminal_outlined, title: 'Filière Informatique', depth: 3),
    _AcademicTreeNode(icon: Icons.groups_outlined, title: 'Classes → UE → EC', depth: 4),
    SizedBox(height: 12), Text('Arborescence du jeu de démonstration.', style: TextStyle(color: slate, fontSize: 12)),
  ])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer'))]));
}

void _checkAcademicProgramme(BuildContext context, CelluleWorkspace workspace) {
  final problems = <String>[];
  final credits = workspace.courses.fold<int>(0, (sum, course) => sum + course.credits);
  if (credits != 30) problems.add('Le programme totalise $credits crédits ; la cible du semestre est 30.');
  for (final course in workspace.courses) {
    if (course.active && (course.ecs.isEmpty || course.ecs.length > 2)) problems.add('${course.code} : une UE active doit comporter 1 à 2 EC.');
    if (course.ecs.fold<int>(0, (sum, ec) => sum + ec.credits) != course.credits) problems.add('${course.code} : les crédits des EC ne correspondent pas à ceux de l’UE.');
    for (final ec in course.ecs) {
      if (ec.weights.values.fold<int>(0, (sum, weight) => sum + weight) != 100) problems.add('${ec.code} : les pondérations doivent totaliser 100 %.');
      if (ec.teacher.trim().isEmpty) problems.add('${ec.code} : enseignant à affecter.');
    }
  }
  showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(problems.isEmpty ? 'Maquette cohérente' : '${problems.length} point(s) à vérifier'), content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(workspace.classLabel, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 14), if (problems.isEmpty) const Text('Les crédits, le nombre d’EC, les pondérations et les affectations du programme sont cohérents.'), for (final problem in problems) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('• $problem')), const SizedBox(height: 12), const Text('Contrôle local de démonstration. Ce résultat ne constitue pas une homologation administrative.', style: TextStyle(color: slate, fontSize: 12))]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer'))]));
}

void _showAcademicCourse(BuildContext context, CelluleWorkspace workspace, CelluleCourse course) {
  showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text('${course.code} · ${course.title}'), content: SizedBox(width: 610, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('${course.category} · ${course.credits} ECTS · ${course.hours} heures', style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 12)), const SizedBox(height: 18),
    for (final ec in course.ecs) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: paper, border: Border.all(color: ink.withValues(alpha: .15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${ec.code} · ${ec.credits} ECTS', style: const TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(ec.title, style: const TextStyle(fontFamily: 'Fraunces', fontSize: 20)), const SizedBox(height: 8), Text(ec.teacher.isEmpty ? 'Enseignant à affecter' : ec.teacher, style: const TextStyle(color: slate)), const SizedBox(height: 12), Text(_academicWeights(ec), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))])),
    const Text('Les notes sont saisies par EC. Le minimum annuel de 35/100 concerne le résultat arrondi de l’UE.', style: TextStyle(color: slate, fontSize: 12)),
  ]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')), FilledButton.icon(onPressed: () { Navigator.pop(dialogContext); _editAcademicCourse(context, workspace, course: course); }, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Modifier'))]));
}

Future<void> _assignAcademicTeacher(BuildContext context, CelluleWorkspace workspace, CelluleCourse course, CelluleEc ec) async {
  final result = await showDialog<String>(context: context, builder: (dialogContext) => _AcademicTeacherDialog(ec: ec));
  if (result == null || !context.mounted) return;
  workspace.replaceCourse(CelluleCourse(id: course.id, code: course.code, title: course.title, category: course.category, credits: course.credits, teacher: course.ecs.first.code == ec.code ? result : course.teacher, hours: course.hours, active: course.active, ecs: course.ecs.map((item) => item.code == ec.code ? CelluleEc(code: item.code, title: item.title, teacher: result, credits: item.credits, weights: item.weights) : item).toList()));
  celluleDemoNotice(context, 'Enseignant affecté à ${ec.code} dans la maquette locale.');
}

class _AcademicTeacherDialog extends StatefulWidget {
  const _AcademicTeacherDialog({required this.ec});
  final CelluleEc ec;
  @override
  State<_AcademicTeacherDialog> createState() => _AcademicTeacherDialogState();
}

class _AcademicTeacherDialogState extends State<_AcademicTeacherDialog> {
  late final TextEditingController teacher = TextEditingController(text: widget.ec.teacher);
  final form = GlobalKey<FormState>();
  @override
  void dispose() { teacher.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Affecter un enseignant'), content: SizedBox(width: 430, child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('${widget.ec.code} · ${widget.ec.title}'), const SizedBox(height: 18), TextFormField(controller: teacher, decoration: const InputDecoration(labelText: 'Nom de l’enseignant', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Renseignez le nom de l’enseignant.' : null), const SizedBox(height: 12), const Text('Affectation locale de démonstration.', style: TextStyle(color: slate, fontSize: 12))]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, teacher.text.trim()); }, child: const Text('Affecter'))]);
}

Future<void> _editAcademicCourse(BuildContext context, CelluleWorkspace workspace, {CelluleCourse? course}) async {
  final result = await showDialog<CelluleCourse>(context: context, builder: (dialogContext) => _AcademicCourseEditor(course: course, existingCourses: workspace.courses));
  if (result == null || !context.mounted) return;
  if (course == null) { workspace.addCourse(result); } else { workspace.replaceCourse(result); }
  celluleDemoNotice(context, '${result.code} ${course == null ? 'ajoutée' : 'modifiée'} dans la maquette locale.');
}

class _AcademicCourseEditor extends StatefulWidget {
  const _AcademicCourseEditor({required this.course, required this.existingCourses});
  final CelluleCourse? course;
  final List<CelluleCourse> existingCourses;
  @override
  State<_AcademicCourseEditor> createState() => _AcademicCourseEditorState();
}

class _AcademicCourseEditorState extends State<_AcademicCourseEditor> {
  final form = GlobalKey<FormState>();
  late final code = TextEditingController(text: widget.course?.code ?? '');
  late final title = TextEditingController(text: widget.course?.title ?? '');
  late final credits = TextEditingController(text: '${widget.course?.credits ?? 6}');
  late final hours = TextEditingController(text: '${widget.course?.hours ?? 60}');
  late String category = widget.course?.category ?? 'FONDAMENTALE';
  late bool active = widget.course?.active ?? true;
  late final ecs = widget.course == null ? [_AcademicEcFields()] : widget.course!.ecs.map((ec) => _AcademicEcFields(ec: ec)).toList();
  final retiredEcs = <_AcademicEcFields>[];
  String? issue;

  @override
  void dispose() {
    for (final controller in [code, title, credits, hours]) { controller.dispose(); }
    for (final ec in [...ecs, ...retiredEcs]) { ec.dispose(); }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;
  String? _positive(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number <= 0 ? 'Entier positif requis' : null;
  }

  void _save() {
    setState(() => issue = null);
    if (!form.currentState!.validate()) return;
    final otherCourses = widget.existingCourses.where((course) => course.id != widget.course?.id);
    if (otherCourses.any((course) => course.code.toUpperCase() == code.text.trim().toUpperCase())) {
      setState(() => issue = 'Ce code UE existe déjà dans le programme.'); return;
    }
    if (ecs.isEmpty || ecs.length > 2) { setState(() => issue = 'Une UE doit comporter un ou deux EC.'); return; }
    if (ecs.fold<int>(0, (sum, ec) => sum + int.parse(ec.credits.text)) != int.parse(credits.text)) { setState(() => issue = 'La somme des crédits des EC doit correspondre aux crédits de l’UE.'); return; }
    final seen = <String>{};
    final existingEcCodes = otherCourses.expand((course) => course.ecs).map((ec) => ec.code.toUpperCase()).toSet();
    for (final ec in ecs) {
      if (!seen.add(ec.code.text.trim().toUpperCase()) || existingEcCodes.contains(ec.code.text.trim().toUpperCase())) { setState(() => issue = 'Chaque EC doit posséder un code unique dans le programme.'); return; }
      if ([ec.cc, ec.tp, ec.sn].fold<int>(0, (sum, field) => sum + int.parse(field.text)) != 100) { setState(() => issue = '${ec.code.text} : la somme CC + TP + SN doit être de 100 %.'); return; }
    }
    Navigator.pop(context, CelluleCourse(id: widget.course?.id ?? 'demo-${DateTime.now().microsecondsSinceEpoch}', code: code.text.trim().toUpperCase(), title: title.text.trim(), category: category, credits: int.parse(credits.text), teacher: ecs.first.teacher.text.trim(), hours: int.parse(hours.text), active: active, ecs: ecs.map((ec) => CelluleEc(code: ec.code.text.trim().toUpperCase(), title: ec.title.text.trim(), teacher: ec.teacher.text.trim(), credits: int.parse(ec.credits.text), weights: {'CC': int.parse(ec.cc.text), 'TP': int.parse(ec.tp.text), 'SN': int.parse(ec.sn.text)})).toList()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.course == null ? 'Nouvelle Unité d’Enseignement' : 'Modifier ${widget.course!.code}'), content: SizedBox(width: 650, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Maquette locale de démonstration · 1 à 2 EC par UE', style: TextStyle(color: slate, fontSize: 12)), const SizedBox(height: 18),
    TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Code UE', border: OutlineInputBorder()), validator: _required), const SizedBox(height: 13),
    TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Intitulé de l’UE', border: OutlineInputBorder()), validator: _required), const SizedBox(height: 13),
    Row(children: [Expanded(child: TextFormField(controller: credits, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Crédits ECTS', border: OutlineInputBorder()), validator: _positive)), const SizedBox(width: 12), Expanded(child: TextFormField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Volume horaire', border: OutlineInputBorder()), validator: _positive))]), const SizedBox(height: 13),
    DropdownButtonFormField<String>(initialValue: category, isExpanded: true, decoration: const InputDecoration(labelText: 'Nature UE', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'FONDAMENTALE', child: Text('Fondamentale')), DropdownMenuItem(value: 'OPTIONNELLE', child: Text('Optionnelle / complémentaire'))], onChanged: (value) => setState(() => category = value ?? 'FONDAMENTALE')),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('UE active'), subtitle: const Text('Désactiver pour conserver une UE en révision.', style: TextStyle(fontSize: 11)), value: active, onChanged: (value) => setState(() => active = value)),
    const Divider(height: 26),
    for (var index = 0; index < ecs.length; index++) _ecForm(index),
    if (ecs.length < 2) Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => setState(() => ecs.add(_AcademicEcFields())), icon: const Icon(Icons.add, size: 18), label: const Text('Ajouter un deuxième EC'))),
    if (issue != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(issue!, style: const TextStyle(color: red, fontWeight: FontWeight.w600))),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: _save, child: const Text('Enregistrer la maquette'))]);

  Widget _ecForm(int index) {
    final ec = ecs[index];
    return Container(key: ObjectKey(ec), margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: paper.withValues(alpha: .5), border: Border.all(color: ink.withValues(alpha: .16))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text('ÉLÉMENT CONSTITUTIF ${index + 1}', style: const TextStyle(fontFamily: 'monospace', color: red, fontSize: 12))), if (ecs.length > 1) IconButton(tooltip: 'Retirer cet EC', onPressed: () => setState(() { retiredEcs.add(ecs.removeAt(index)); }), icon: const Icon(Icons.close, size: 18))]), const SizedBox(height: 12),
      TextFormField(controller: ec.code, decoration: const InputDecoration(labelText: 'Code EC', border: OutlineInputBorder(), isDense: true), validator: _required), const SizedBox(height: 12),
      TextFormField(controller: ec.title, decoration: const InputDecoration(labelText: 'Intitulé de l’EC', border: OutlineInputBorder(), isDense: true), validator: _required), const SizedBox(height: 12),
      TextFormField(controller: ec.teacher, decoration: const InputDecoration(labelText: 'Enseignant (facultatif)', border: OutlineInputBorder(), isDense: true)), const SizedBox(height: 12),
      TextFormField(controller: ec.credits, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Crédits de l’EC', border: OutlineInputBorder(), isDense: true), validator: _positive), const SizedBox(height: 16),
      const Text('Pondérations du plan d’évaluation · total 100 %', style: TextStyle(color: slate, fontSize: 12)), const SizedBox(height: 12),
      Row(children: [for (final entry in {'CC': ec.cc, 'TP': ec.tp, 'SN': ec.sn}.entries) Expanded(child: Padding(padding: const EdgeInsets.only(right: 7), child: TextFormField(controller: entry.value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${entry.key} %', border: const OutlineInputBorder(), isDense: true), validator: (value) { final number = int.tryParse(value ?? ''); return number == null || number < 0 || number > 100 ? '0 à 100' : null; }))) ]),
      const SizedBox(height: 8), const Text('Utiliser 0 % lorsqu’une composante n’est pas prévue.', style: TextStyle(color: slate, fontSize: 10)),
    ]));
  }
}

class _AcademicEcFields {
  _AcademicEcFields({CelluleEc? ec}) : code = TextEditingController(text: ec?.code ?? ''), title = TextEditingController(text: ec?.title ?? ''), teacher = TextEditingController(text: ec?.teacher ?? ''), credits = TextEditingController(text: '${ec?.credits ?? 3}'), cc = TextEditingController(text: '${ec?.weights['CC'] ?? 20}'), tp = TextEditingController(text: '${ec?.weights['TP'] ?? 30}'), sn = TextEditingController(text: '${ec?.weights['SN'] ?? 50}');
  final TextEditingController code;
  final TextEditingController title;
  final TextEditingController teacher;
  final TextEditingController credits;
  final TextEditingController cc;
  final TextEditingController tp;
  final TextEditingController sn;
  void dispose() { for (final field in [code, title, teacher, credits, cc, tp, sn]) { field.dispose(); } }
}
