part of 'main.dart';

class CelluleScope extends InheritedNotifier<CelluleWorkspace> {
  const CelluleScope({super.key, required CelluleWorkspace workspace, required super.child}) : super(notifier: workspace);
  static CelluleWorkspace of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CelluleScope>()!.notifier!;
}

class CellulePortal extends StatefulWidget {
  const CellulePortal({super.key, this.initialSection, this.workspace});
  final CelluleSection? initialSection;
  final CelluleWorkspace? workspace;
  @override
  State<CellulePortal> createState() => _CellulePortalState();
}

class _CellulePortalState extends State<CellulePortal> {
  late final CelluleWorkspace workspace;
  bool initialized = false;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    workspace = widget.workspace ?? CelluleWorkspace();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      if (widget.workspace == null) workspace.section = widget.initialSection ?? (MediaQuery.sizeOf(context).width < 760 ? CelluleSection.supervision : CelluleSection.structure);
      initialized = true;
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    if (widget.workspace == null) workspace.dispose();
    super.dispose();
  }

  void navigate(CelluleSection section) {
    workspace.openSection(section);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gnu_token');
    await prefs.remove('gnu_current_user');
    GnuApi.token = null;
    GnuApi.currentUser = null;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  void profile() {
    final user = GnuApi.currentUser;
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Profil · Cellule informatique'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_celluleUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('Identifiant : ${user?['code_utilisateur'] ?? user?['login'] ?? 'ADM-8842 · Démonstration'}'),
        const Text('Rôle : Agent · Cellule informatique'),
        const SizedBox(height: 12),
        const Text('Structure académique, catalogue, contrôle des notes et préparation des publications.'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')), FilledButton.icon(onPressed: () async { Navigator.pop(context); await logout(); }, icon: const Icon(Icons.logout), label: const Text('Se déconnecter'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final role = GnuApi.currentUser?['role']?.toString().toUpperCase();
    if (role != null && role != 'AGENT') {
      return Scaffold(appBar: AppBar(title: const Text('Cellule informatique')), body: const Center(child: Text('Cet espace est réservé au profil Agent.')));
    }
    return CelluleScope(workspace: workspace, child: AnimatedBuilder(
      animation: workspace,
      builder: (context, _) {
        final compact = MediaQuery.sizeOf(context).width < 1180;
        final mobile = MediaQuery.sizeOf(context).width < 760;
        final content = switch (workspace.section) {
          CelluleSection.supervision => const CelluleSupervisionContent(),
          CelluleSection.structure => const CelluleStructureContent(),
          CelluleSection.catalog => const CelluleCatalogContent(),
          CelluleSection.numerisation => const CelluleNumerisationContent(),
          CelluleSection.publications => const CellulePublicationsContent(),
          CelluleSection.bulletin => const CelluleBulletinContent(),
        };
        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: paper,
            cardTheme: CardThemeData(color: paperLight, surfaceTintColor: Colors.transparent, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(mobile ? 12 : 0), side: BorderSide(color: ink.withValues(alpha: .18)))),
            inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: paperLight, isDense: true, border: const OutlineInputBorder(borderRadius: BorderRadius.zero), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: ink.withValues(alpha: .24))), labelStyle: const TextStyle(fontSize: 11, color: slate)),
            filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(mobile ? 8 : 0)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16))),
            outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(mobile ? 8 : 0)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15))),
          ),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false, toolbarHeight: compact ? 80 : 92,
              titleSpacing: compact ? 16 : 26, backgroundColor: paperLight, surfaceTintColor: paperLight,
              title: Row(children: [
                Image.asset('assets/logo_gnu.png', width: 38, height: 44),
                const SizedBox(width: 12),
                if (compact) Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CELLULE INFORMATIQUE', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold, fontSize: 10)),
                  Text(_celluleSectionTitle(workspace.section), style: const TextStyle(fontFamily: 'Fraunces', fontSize: 22, color: ink), overflow: TextOverflow.ellipsis),
                ])) else ...[
                  const SizedBox(width: 245, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('GNU', style: TextStyle(fontFamily: 'Fraunces', fontSize: 27, color: ink)), Text('CELLULE INFORMATIQUE · ADMINISTRATION\nCENTRALE LMD', style: TextStyle(fontFamily: 'monospace', letterSpacing: 1.1, fontSize: 10, color: slate))])),
                  IconButton(key: const ValueKey('cellule-nav-supervision'), tooltip: 'Supervision', onPressed: () => navigate(CelluleSection.supervision), icon: Icon(Icons.dashboard_outlined, color: workspace.section == CelluleSection.supervision ? red : slate)),
                  Expanded(child: Container(decoration: BoxDecoration(color: paper, border: Border.all(color: ink.withValues(alpha: .18)), borderRadius: BorderRadius.circular(4)), padding: const EdgeInsets.all(3), child: Row(children: [
                    for (final section in [CelluleSection.structure, CelluleSection.catalog, CelluleSection.numerisation, CelluleSection.publications])
                      Expanded(child: TextButton(
                        key: ValueKey('cellule-nav-${section.name}'),
                        onPressed: () => navigate(section),
                        style: TextButton.styleFrom(backgroundColor: workspace.section == section || (section == CelluleSection.publications && workspace.section == CelluleSection.bulletin) ? red : Colors.transparent, foregroundColor: workspace.section == section || (section == CelluleSection.publications && workspace.section == CelluleSection.bulletin) ? Colors.white : slate, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
                        child: Text(_celluleNavTitle(section), style: const TextStyle(fontSize: 11), maxLines: 2),
                      )),
                  ]))),
                  const SizedBox(width: 18),
                  SizedBox(width: 128, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_celluleUserName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), const Text('AGENT · CELLULE', style: TextStyle(fontFamily: 'monospace', color: valid, fontSize: 10))])),
                ],
                if (compact) PopupMenuButton<CelluleSection>(tooltip: 'Toutes les pages de la Cellule', onSelected: navigate, itemBuilder: (_) => [for (final section in CelluleSection.values) PopupMenuItem(value: section, child: Text(_celluleSectionTitle(section)))]),
                IconButton(key: const ValueKey('cellule-profile'), tooltip: 'Mon profil', onPressed: profile, icon: const CircleAvatar(radius: 19, backgroundColor: red, child: Icon(Icons.person_outline, color: Colors.white, size: 20))),
              ]),
            ),
            body: Column(children: [
              if (!mobile) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12), decoration: BoxDecoration(color: paperLight, border: Border.symmetric(horizontal: BorderSide(color: ink.withValues(alpha: .12)))), child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 20, runSpacing: 8, children: [
                const Text('♜  UNIVERSITÉ DE DOUALA   ›   Rectorat & Décanat   ›   Cellule Informatique LMD', style: TextStyle(fontSize: 12, color: ink)),
                const Text('SESSION 2024–2025 · ESPACE DE DÉMONSTRATION', style: TextStyle(fontFamily: 'monospace', color: valid, fontSize: 11)),
              ])),
              Expanded(child: SingleChildScrollView(controller: scroll, key: ValueKey('cellule-scroll-${workspace.section.name}'), padding: EdgeInsets.all(mobile ? 16 : 26), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1540), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (mobile) Padding(padding: const EdgeInsets.only(bottom: 16), child: CellulePanel(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SESSION 2024–2025 · DÉMONSTRATION', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), const SizedBox(height: 6), Text(workspace.classLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]))),
                content,
                const SizedBox(height: 24),
                const Text('Données d’exemple · Modifications conservées pendant cet espace de travail.\nLes envois, imports, exports, signatures et publications sont simulés.', style: TextStyle(color: slate, fontSize: 11)),
                if (!mobile) ...[const SizedBox(height: 28), const Divider(), Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 8, children: [const Text('GNU — Gestion des Notes Universitaires', style: TextStyle(fontFamily: 'Fraunces', fontSize: 19, color: ink)), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())), icon: const Icon(Icons.headset_mic_outlined, size: 16), label: const Text('ASSISTANCE & SUPPORT'))])],
              ]))))),
            ]),
            bottomNavigationBar: mobile ? NavigationBar(
              height: 74, backgroundColor: paperLight, indicatorColor: red.withValues(alpha: .13),
              selectedIndex: switch (workspace.section) { CelluleSection.supervision => 0, CelluleSection.numerisation => 1, CelluleSection.publications || CelluleSection.bulletin => 2, _ => 3 },
              onDestinationSelected: (index) => navigate([CelluleSection.supervision, CelluleSection.numerisation, CelluleSection.publications, CelluleSection.structure][index]),
              destinations: const [NavigationDestination(icon: Icon(Icons.grid_view), label: 'Supervision'), NavigationDestination(icon: Icon(Icons.edit_document), label: 'Numérisation'), NavigationDestination(icon: Icon(Icons.verified_outlined), label: 'Publications'), NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Structure')],
            ) : null,
          ),
        );
      },
    ));
  }
}

String get _celluleUserName {
  final user = GnuApi.currentUser;
  final name = [user?['nom'], user?['prenom']].where((part) => part != null && part.toString().trim().isNotEmpty).join(' ');
  return name.isEmpty ? 'Dr. MBALLA Paul' : name;
}

String _celluleSectionTitle(CelluleSection section) => switch (section) {
  CelluleSection.supervision => 'Supervision', CelluleSection.structure => 'Structure & Hiérarchie', CelluleSection.catalog => 'Catalogue UE & EC', CelluleSection.numerisation => 'Numérisation & Calcul MGP', CelluleSection.publications => 'Bulletins & Publications', CelluleSection.bulletin => 'Prévisualisation du bulletin',
};
String _celluleNavTitle(CelluleSection section) => switch (section) { CelluleSection.structure => 'Structure &\nHiérarchie', CelluleSection.catalog => 'Catalogue des UEs &\nCours', CelluleSection.numerisation => 'Numérisation & Calcul\nMGP', _ => 'Bulletins &\nPublications' };

void celluleNotice(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
void celluleDemoNotice(BuildContext context, String action) => celluleNotice(context, '$action — simulation. Aucun fichier ni envoi officiel n’est produit.');

class CellulePanel extends StatelessWidget {
  const CellulePanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

class CelluleBadge extends StatelessWidget {
  const CelluleBadge({super.key, required this.label, this.color = valid});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .10), border: Border.all(color: color.withValues(alpha: .3))), child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: .4, color: color)));
}

class CelluleHeading extends StatelessWidget {
  const CelluleHeading({super.key, required this.title, this.eyebrow, this.subtitle, this.actions = const []});
  final String title;
  final String? eyebrow, subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (eyebrow != null) ...[Text(eyebrow!, style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 10, letterSpacing: 1)), const SizedBox(height: 8)],
    Text(title, style: TextStyle(fontFamily: 'Fraunces', fontSize: MediaQuery.sizeOf(context).width < 760 ? 25 : 34, color: ink)),
    if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, style: const TextStyle(color: slate, fontSize: 13))],
    if (actions.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: actions)],
  ]));
}

class CelluleMetric extends StatelessWidget {
  const CelluleMetric({super.key, required this.label, required this.value, this.detail, this.color = ink, this.icon});
  final String label, value;
  final String? detail;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => CellulePanel(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate, letterSpacing: .5))), if (icon != null) Icon(icon, size: 18, color: color)]),
    const SizedBox(height: 16), Text(value, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 27, color: color)),
    if (detail != null) ...[const SizedBox(height: 7), Text(detail!, style: const TextStyle(fontSize: 11, color: slate))],
  ]));
}

class CelluleColumns extends StatelessWidget {
  const CelluleColumns({super.key, required this.children, this.flex, this.breakpoint = 900, this.gap = 20});
  final List<Widget> children;
  final List<int>? flex;
  final int breakpoint;
  final double gap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    if (constraints.maxWidth < breakpoint) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var index = 0; index < children.length; index++) ...[if (index > 0) SizedBox(height: gap), children[index]]]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var index = 0; index < children.length; index++) ...[if (index > 0) SizedBox(width: gap), Expanded(flex: flex?[index] ?? 1, child: children[index])]]);
  });
}

class CelluleSupervisionContent extends StatelessWidget {
  const CelluleSupervisionContent({super.key});
  @override
  Widget build(BuildContext context) {
    final workspace = CelluleScope.of(context);
    final complete = workspace.students.where((s) => workspace.result(s).complete).length;
    final pct = complete / workspace.students.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const CelluleHeading(title: 'Supervision & Avancement LMD', eyebrow: 'CELLULE INFORMATIQUE · SUIVI DES OPÉRATIONS', subtitle: 'Vue de contrôle de la session et suivi des dossiers de démonstration.'),
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final metric in [CelluleMetric(label: 'Saisies complètes', value: '${(pct * 100).toStringAsFixed(0)} %', detail: '$complete / ${workspace.students.length} dossiers', icon: Icons.edit_note, color: red), CelluleMetric(label: 'Contrôle du lot', value: workspace.validated ? 'Validé' : 'À vérifier', detail: 'Validation de démonstration', icon: Icons.fact_check_outlined, color: gold), CelluleMetric(label: 'UE au catalogue', value: '${workspace.courses.length}', detail: '${workspace.courses.fold(0, (sum, c) => sum + c.credits)} crédits', icon: Icons.menu_book_outlined, color: valid), CelluleMetric(label: 'Dossiers incomplets', value: '${workspace.students.length - complete}', detail: 'À régulariser par l’enseignant', icon: Icons.warning_amber_outlined, color: red)])
            SizedBox(width: constraints.maxWidth >= 1000 ? (constraints.maxWidth - 36) / 4 : width, child: metric),
        ]);
      }),
      const SizedBox(height: 20),
      CelluleColumns(flex: const [3, 2], children: [
        CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Avancement des départements', style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, color: ink)), const SizedBox(height: 20),
          for (final department in [('Informatique', pct, '$complete dossiers complets sur ${workspace.students.length}'), ('Mathématiques', .88, 'Attente d’un bordereau CC · Exemple'), ('Physique', .72, 'Contrôles en cours · Exemple'), ('Chimie', .81, 'Saisie TP consolidée · Exemple')]) Padding(padding: const EdgeInsets.only(bottom: 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(department.$1, style: const TextStyle(fontWeight: FontWeight.bold))), Text('${(department.$2 * 100).round()} %', style: TextStyle(fontFamily: 'monospace', color: department.$2 >= .9 ? valid : red))]), const SizedBox(height: 7),
            LinearProgressIndicator(value: department.$2, minHeight: 7, borderRadius: BorderRadius.circular(4), color: department.$2 >= .9 ? valid : red, backgroundColor: paper), const SizedBox(height: 6), Text(department.$3, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)),
          ])),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Alertes de la session', style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, color: ink)), const SizedBox(height: 12),
          for (final student in workspace.students.where((s) => !workspace.result(s).complete)) Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: red.withValues(alpha: .08), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, color: red), const SizedBox(height: 8), Text('${student.matricule} · Résultat manquant', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 6), Text(student.name, style: const TextStyle(color: slate)), const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: () { workspace.selectStudent(workspace.students.indexOf(student)); workspace.openSection(CelluleSection.numerisation); }, icon: const Icon(Icons.arrow_forward, size: 16), label: const Text('Examiner le dossier')),
          ]))),
          if (complete == workspace.students.length) const CellulePanel(child: Text('Tous les dossiers du jeu d’exemple sont complets.', style: TextStyle(color: valid))),
        ]),
      ]),
      const SizedBox(height: 20),
      CellulePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Actions d’exploitation', style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, color: ink)), const SizedBox(height: 16),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.analytics_outlined, color: red), title: const Text('Rapport de complétude global'), subtitle: const Text('Ouvrir le registre de contrôle et les calculs'), trailing: const Icon(Icons.chevron_right), onTap: () => workspace.openSection(CelluleSection.numerisation)), const Divider(),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.table_view_outlined, color: gold), title: const Text('Exporter le bilan consolidé (.xlsx)'), subtitle: const Text('Export de démonstration'), trailing: const Icon(Icons.download_outlined), onTap: () => celluleDemoNotice(context, 'Export du bilan consolidé')), const Divider(),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.account_tree_outlined, color: valid), title: const Text('Structure & catalogue pédagogique'), subtitle: const Text('Consulter les UE, EC et affectations'), trailing: const Icon(Icons.chevron_right), onTap: () => workspace.openSection(CelluleSection.structure)),
      ])),
    ]);
  }
}
