part of 'main.dart';

enum TeacherSection { dashboard, units, grades, requests }

class TeacherAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TeacherSection section;

  const TeacherAppBar({super.key, required this.section});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  void _go(BuildContext context, TeacherSection destination) {
    if (destination == section) return;
    final page = switch (destination) {
      TeacherSection.dashboard => const RoleHome(role: Role.enseignant),
      TeacherSection.units => const TeacherUnitsPage(),
      TeacherSection.grades => const GradeEntryPage(),
      TeacherSection.requests => const TeacherRequestsPage(),
    };
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1080;
    final buttons = <Widget>[
      _TNavButton(
        icon: Icons.grid_view_outlined,
        label: 'Tableau de bord',
        active: section == TeacherSection.dashboard,
        onPressed: () => _go(context, TeacherSection.dashboard),
      ),
      _TNavButton(
        icon: Icons.menu_book_outlined,
        label: 'Unités d’enseignement',
        active: section == TeacherSection.units,
        onPressed: () => _go(context, TeacherSection.units),
      ),
      _TNavButton(
        icon: Icons.fact_check_outlined,
        label: 'Saisie et vérifications des notes',
        active: section == TeacherSection.grades,
        onPressed: () => _go(context, TeacherSection.grades),
      ),
      _TNavButton(
        icon: Icons.assignment_outlined,
        label: 'Requêtes',
        badge: '4',
        active: section == TeacherSection.requests,
        onPressed: () => _go(context, TeacherSection.requests),
      ),
    ];

    return AppBar(
      toolbarHeight: 72,
      titleSpacing: compact ? 14 : 30,
      backgroundColor: paperLight,
      surfaceTintColor: paperLight,
      elevation: 0,
      title: const _TBrand(),
      actions: compact
          ? [
              PopupMenuButton<TeacherSection>(
                tooltip: 'Navigation enseignant',
                icon: const Icon(Icons.menu, color: ink),
                onSelected: (value) => _go(context, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: TeacherSection.dashboard, child: Text('Tableau de bord')),
                  PopupMenuItem(value: TeacherSection.units, child: Text('Unités d’enseignement')),
                  PopupMenuItem(value: TeacherSection.grades, child: Text('Saisie des notes')),
                  PopupMenuItem(value: TeacherSection.requests, child: Text('Requêtes (4)')),
                ],
              ),
              const _TProfileButton(compact: true),
              const SizedBox(width: 8),
            ]
          : [
              ...buttons,
              const SizedBox(width: 14),
              const _TProfileButton(),
              const SizedBox(width: 24),
            ],
    );
  }
}

class _TBrand extends StatelessWidget {
  const _TBrand();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: paper,
              border: Border.all(color: ink.withValues(alpha: .12)),
            ),
            child: Image.asset('assets/logo_gnu.png'),
          ),
          const SizedBox(width: 10),
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GNU', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, fontSize: 22, color: ink)),
              Text('SYSTÈME ACADÉMIQUE LMD · PORTAIL', style: TextStyle(fontFamily: 'monospace', letterSpacing: .65, fontSize: 8, color: slate)),
              Text('OFFICIEL', style: TextStyle(fontFamily: 'monospace', letterSpacing: .65, fontSize: 8, color: slate)),
            ],
          ),
        ],
      );
}

class _TProfileButton extends StatelessWidget {
  final bool compact;
  const _TProfileButton({this.compact = false});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!compact)
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Pr. NDJOCK B. · Informatique', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ink)),
                  Text('ENSEIGNANT TITULAIRE', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: red)),
                ],
              ),
            if (!compact) const SizedBox(width: 9),
            const CircleAvatar(
              radius: 16,
              backgroundColor: red,
              child: Icon(Icons.person_outline, size: 18, color: Colors.white),
            ),
          ]),
        ),
      );
}

class _TNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool active;
  final VoidCallback onPressed;

  const _TNavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        child: TextButton(
          onPressed: active ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: active ? Colors.white : ink,
            backgroundColor: active ? red : Colors.transparent,
            disabledForegroundColor: Colors.white,
            disabledBackgroundColor: red,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(3))),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            SizedBox(
              width: label.length > 24 ? 145 : null,
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            if (badge != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: active ? Colors.white24 : red.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                child: Text(badge!, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9, color: active ? Colors.white : red)),
              ),
            ],
          ]),
        ),
      );
}

class _TFrame extends StatelessWidget {
  final List<Widget> children;
  const _TFrame({required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
}

class _TContextBar extends StatelessWidget {
  const _TContextBar();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: paperLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final identity = const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FACULTÉ DES SCIENCES  /  Dép. Mathématiques & Informatique', style: TextStyle(fontFamily: 'Fraunces', color: ink, fontSize: 17, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('ANNÉE 2024–2025  ·  SEMESTRES IMPAIRS & PAIRS', style: TextStyle(fontFamily: 'monospace', color: slate, fontSize: 9, letterSpacing: .45)),
              ],
            );
            final validation = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFE1E8DA), border: Border.all(color: valid.withValues(alpha: .35))),
              child: const Text('● HABILITATION PÉDAGOGIQUE\n  VALIDÉE', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: valid, fontSize: 9)),
            );
            const timestamp = Text('Horodatage officiel : 24/02/2025 · 10:15\nUTC+1', style: TextStyle(fontFamily: 'monospace', color: slate, fontSize: 9));
            if (!wide) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                identity,
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [validation, timestamp]),
              ]);
            }
            return Row(children: [
              Expanded(child: identity),
              validation,
              const SizedBox(width: 16),
              Container(width: 1, height: 30, color: ink.withValues(alpha: .16)),
              const SizedBox(width: 14),
              timestamp,
            ]);
          }),
        ),
      );
}

class _TFooter extends StatelessWidget {
  const _TFooter();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 38),
        child: Row(children: const [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GNU — Gestion des Notes Universitaires', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink)),
            SizedBox(height: 3),
            Text('Système académique officiel pour les formations LMD (Licence, Master, Doctorat)', style: TextStyle(fontSize: 10, color: slate)),
          ])),
          SizedBox(width: 18),
          Flexible(child: Text('ANNÉE UNIVERSITAIRE 2024–2025   ·   ASSISTANCE & SUPPORT', textAlign: TextAlign.end, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate))),
        ]),
      );
}

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) => _TFrame(children: [
        const _TContextBar(),
        const SizedBox(height: 18),
        const _TDashboardHero(),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final cards = [
            _TDashboardPillar(
              tag: 'PILIER 1',
              title: 'Unités d’Enseignement',
              badge: '3 Cours Affectés',
              value: '310',
              caption: 'Étudiants au total',
              icon: Icons.menu_book_outlined,
              color: ink,
              lines: const ['INF301 · Algorithmique Avancée', 'INF305 · Systèmes & Réseaux', 'INF201 · Programmation C/C++'],
              action: 'Gérer les Unités d’enseignement',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherUnitsPage())),
            ),
            _TDashboardPillar(
              tag: 'PILIER 2',
              title: 'Saisie & Vérifications',
              badge: '96.4% Numérisé',
              value: '96.4%',
              caption: 'Notes numérisées',
              icon: Icons.fact_check_outlined,
              color: valid,
              lines: const ['INF301 (Algorithmique) : 96.4% saisi (81/84)', 'INF305 (Systèmes & Réseaux) : 78.0% saisi (66/84)', 'INF201 (C/C++ Fondamental) : 100% prêt (142/142)'],
              action: 'Accéder à la saisie et vérification',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradeEntryPage())),
            ),
            _TDashboardPillar(
              tag: 'PILIER 3',
              title: 'Requêtes & Réclamations',
              badge: '2 Urgentes',
              value: '04',
              caption: 'Reçues au total',
              icon: Icons.campaign_outlined,
              color: red,
              lines: const ['#REC-2024-0841 · Note TP omise (ABS)', '#REC-2024-0842 · Erreur note CC 06/20', '10 notes éliminatoires à surveiller'],
              action: 'Traiter toutes les requêtes (4)',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherRequestsPage())),
            ),
          ];
          if (!wide) return Column(children: [for (final card in cards) ...[card, const SizedBox(height: 14)]]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 18),
            Expanded(child: cards[1]),
            const SizedBox(width: 18),
            Expanded(child: cards[2]),
          ]);
        }),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 860) return const Column(children: [_TActivityCard(), SizedBox(height: 16), _TComplianceCard()]);
          return const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: _TActivityCard()), SizedBox(width: 18), Expanded(child: _TComplianceCard())]);
        }),
        const _TFooter(),
      ]);
}

class _TDashboardHero extends StatelessWidget {
  const _TDashboardHero();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 21, 24, 21),
          child: LayoutBuilder(builder: (context, constraints) {
            const intro = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VUE CONSOLIDÉE     Semestre 5 & Rapprochement Annuel', style: TextStyle(fontFamily: 'monospace', color: red, fontSize: 10, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Tableau de bord Enseignant — Synthèse Annuelle 2024–2025', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, fontSize: 27, color: ink)),
                SizedBox(height: 8),
                Text('Bienvenue, Pr. NDJOCK B. Cet espace vous donne un aperçu panoramique de vos 3 unités d’enseignement, de l’avancement de la saisie et du traitement prioritaire des recours et requêtes étudiantes avant transmission aux jurys de délibération.', style: TextStyle(color: slate, height: 1.4)),
              ]);
            const deadline = _TDeadline();
            if (constraints.maxWidth < 720) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [intro, const SizedBox(height: 16), deadline]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: intro), const SizedBox(width: 24), deadline]);
          }),
        ),
      );
}

class _TDeadline extends StatelessWidget {
  const _TDeadline();
  @override
  Widget build(BuildContext context) => Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: paper, border: Border.all(color: red.withValues(alpha: .16))),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('◷ DÉLAI LÉGAL DE CLÔTURE', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold, fontSize: 11)),
          SizedBox(height: 6),
          Text('28h 14m', style: TextStyle(fontFamily: 'Fraunces', fontSize: 25, color: red)),
          SizedBox(height: 4),
          Text('Forclusion stricte LMD (72h post-saisie)', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)),
        ]),
      );
}

class _TDashboardPillar extends StatelessWidget {
  final String tag, title, badge, value, caption, action;
  final IconData icon;
  final Color color;
  final List<String> lines;
  final VoidCallback onPressed;

  const _TDashboardPillar({required this.tag, required this.title, required this.badge, required this.value, required this.caption, required this.icon, required this.color, required this.lines, required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(side: BorderSide(color: color, width: 3), borderRadius: BorderRadius.circular(7)),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Expanded(child: Text(tag, style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: color))),
              _TBadge(label: badge, color: color),
            ]),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink, fontSize: 19)),
            const SizedBox(height: 14),
            RichText(text: TextSpan(style: const TextStyle(color: ink), children: [TextSpan(text: value, style: TextStyle(fontFamily: 'Fraunces', fontSize: 31, color: color)), TextSpan(text: '  $caption', style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate))])),
            const SizedBox(height: 15),
            for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(line, style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 9))),
            const Divider(height: 18),
            SizedBox(width: double.infinity, child: TextButton(onPressed: onPressed, style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: color), child: Text('$action   →', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
          ]),
        ),
      );
}

class _TBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(2)),
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 8, fontWeight: FontWeight.bold, color: color)),
      );
}

class _TActivityCard extends StatelessWidget {
  const _TActivityCard();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('◴  Dernières Activités & Journal des Modifications', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, fontSize: 19, color: ink)),
              Text('Piste d’Audit LMD Horodatée', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)),
            ]),
            Divider(),
            _TActivityLine(icon: Icons.verified_outlined, title: 'Procès-verbal de notes finalisé pour l’UE INF201', detail: '142 étudiants validés · Vérification et émargement de l’enseignant validés', time: 'Aujourd’hui 08:35'),
            _TActivityLine(icon: Icons.document_scanner_outlined, title: 'Appariement OCR des bordereaux d’examen INF301', detail: '81 copies physiques indexées sur 84 · 3 défaillances documentées', time: 'Aujourd’hui 07:48'),
            _TActivityLine(icon: Icons.mail_outline, title: 'Nouvelle requête déposée : #REC-2024-0842 (KAMGA Cédric)', detail: 'Motif de transcription CC · Pièce justificative jointe', time: 'Hier 18:22'),
            SizedBox(height: 8),
            Text('● Intégrité de la chaîne de saisie garantie', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: valid)),
          ]),
        ),
      );
}

class _TActivityLine extends StatelessWidget {
  final IconData icon;
  final String title, detail, time;
  const _TActivityLine({required this.icon, required this.title, required this.detail, required this.time});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: gold, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 11, color: ink, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)),
          ])),
          const SizedBox(width: 8),
          Text(time, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate)),
        ]),
      );
}

class _TComplianceCard extends StatelessWidget {
  const _TComplianceCard();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('STATUT DU SYSTÈME LMD', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)),
            const SizedBox(height: 10),
            const Text('Conformité Réglementaire', style: TextStyle(fontFamily: 'Fraunces', fontSize: 19, fontWeight: FontWeight.bold, color: ink)),
            const SizedBox(height: 8),
            const Text('Vérification continue des normes ministérielles et académiques.', style: TextStyle(fontSize: 11, color: slate)),
            const SizedBox(height: 13),
            const _TCheck(text: 'Barème conforme : CC (20%) + TP (30%) + SN (50%)'),
            const _TCheck(text: 'Seuil éliminatoire à 07.00/20 configuré'),
            const _TCheck(text: 'Horodatage et archivage légal 72h actif'),
            const _TCheck(text: '2 requêtes exigent signature avant clôture jury', warning: true),
            const SizedBox(height: 13),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche récapitulative prête à être exportée.'))), icon: const Icon(Icons.download_outlined, size: 17), label: const Text('Exporter la Fiche Récapitulative'))),
          ]),
        ),
      );
}

class _TCheck extends StatelessWidget {
  final String text;
  final bool warning;
  const _TCheck({required this.text, this.warning = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(warning ? Icons.warning_amber_outlined : Icons.check_circle_outline, color: warning ? red : valid, size: 15),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: warning ? red : valid, fontSize: 10))),
        ]),
      );
}

class TeacherUnitsPage extends StatelessWidget {
  const TeacherUnitsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const TeacherAppBar(section: TeacherSection.units),
        body: _TFrame(children: [
          const _TContextBar(),
          const SizedBox(height: 18),
          _TUnitsHero(onExcel: () => _tNotice(context, 'Export Excel du catalogue préparé.')),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final catalog = const _TUnitsCatalog();
            final plan = const _TTeachingPlan();
            if (constraints.maxWidth < 880) return Column(children: [catalog, const SizedBox(height: 18), plan]);
            return const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _TUnitsCatalog()), SizedBox(width: 18), Expanded(flex: 2, child: _TTeachingPlan())]);
          }),
          const SizedBox(height: 22),
          _TStudentsRegister(onEntry: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradeEntryPage())), onExport: () => _tNotice(context, 'Bordereau Excel de démonstration préparé.')),
          const _TFooter(),
        ]),
      );
}

void _tNotice(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

class _TUnitsHero extends StatelessWidget {
  final VoidCallback onExcel;
  const _TUnitsHero({required this.onExcel});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: LayoutBuilder(builder: (context, constraints) {
            const description = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PORTAIL D’ASSIGNATION & REGISTRE DES UNITÉS D’ENSEIGNEMENT (LMD)', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold, fontSize: 9)),
              SizedBox(height: 7),
              Text('Catalogue des Matières & Dispensation Pédagogique', style: TextStyle(fontFamily: 'Fraunces', color: ink, fontWeight: FontWeight.bold, fontSize: 26)),
              SizedBox(height: 7),
              Text('Sélectionnez les Unités d’Enseignement complètes ou uniquement les sous-éléments constitutifs (CM, TD, TP) que vous prenez en charge pour la Faculté. Les registres des étudiants inscrits et la notation s’associent automatiquement.', style: TextStyle(fontSize: 11, color: slate, height: 1.35)),
            ]);
            final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(onPressed: onExcel, icon: const Icon(Icons.table_view_outlined, size: 17), label: const Text('Transmettre au format Excel (.xlsx)')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => _tNotice(context, 'La demande de nouvelle matière a été enregistrée.'), icon: const Icon(Icons.add_circle_outline, size: 16), label: const Text('Demander une nouvelle matière')),
            ]);
            if (constraints.maxWidth < 720) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [description, const SizedBox(height: 14), actions]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: description), const SizedBox(width: 20), SizedBox(width: 280, child: actions)]);
          }),
        ),
      );
}

class _TUnitsCatalog extends StatelessWidget {
  const _TUnitsCatalog();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('☷  Catalogue des Matières · Faculté des Sciences', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink, fontSize: 16))),
              OutlinedButton.icon(onPressed: () => _tNotice(context, 'Grille d’évaluation ouverte.'), icon: const Icon(Icons.tune, size: 15), label: const Text('Définir la grille')),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 5, runSpacing: 5, children: const [
              _TFilter(label: 'Tous les parcours'), _TFilter(label: 'L1 Info'), _TFilter(label: 'L2 Info'), _TFilter(label: 'L3 Info', active: true), _TFilter(label: 'M1 Info'), _TFilter(label: 'M2 Info'),
            ]),
            const Divider(height: 23),
            const Text('% GRILLE D’ÉVALUATION LMD ACTIVE (INF301) :', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)),
            const SizedBox(height: 7),
            const Wrap(spacing: 5, children: [
              _TWeightPill(label: 'CC : 20%', color: gold), _TWeightPill(label: 'TP : 30%', color: ink), _TWeightPill(label: 'SN : 50%', color: red), Text('Total : 100%', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)),
            ]),
            const SizedBox(height: 7),
            const Text('▲ Seuil éliminatoire : < 07.00/20', style: TextStyle(fontFamily: 'monospace', color: red, fontSize: 9)),
            const SizedBox(height: 14),
            _TUnitBlock(
              code: 'INF301',
              title: 'Algorithmique Avancée & Structures de Données',
              meta: 'Licence 3 Informatique Fondamentale · Semestre 5   ·   6 ECTS',
              status: 'EN DISPENSATION ACTIVE',
              color: red,
              students: '84 Étudiants inscrits',
              children: [
                _TEcLine(code: 'EC 301.1', title: 'Théorie & Algorithmes Complexes', details: 'CM 30h · TD 15h · Amphi 250 (G1+G2)', action: 'Dispenser CM/TD'),
                _TEcLine(code: 'EC 301.2', title: 'Implémentation & Graphes C/C++', details: 'TP Machine · Salle 4 Machine (Co-enseignant M. Manga)', action: 'Dispenser TP'),
              ],
            ),
            _TUnitBlock(code: 'INF303', title: 'Systèmes d’Exploitation II & Concurrence', meta: 'Licence 3 Informatique · Semestre 5   ·   4 ECTS', status: 'Assigné partiel', color: valid, students: '', children: const [_TEcLine(code: 'EC 303.1', title: 'Processus, Threads & IPC', details: 'CM 30h · Groupe 1', action: 'Assigné')]),
            _TUnitBlock(code: 'INF101', title: 'Algorithmique & Programmation Impérative', meta: 'Licence 1 Math-Info · S1   ·   6 ECTS', status: 'Associer', color: slate, students: '', children: const []),
            _TUnitBlock(code: 'INF202', title: 'Structures de Données & POO', meta: 'Licence 2 Math-Info · S3   ·   6 ECTS', status: 'Associer', color: slate, students: '', children: const []),
            _TUnitBlock(code: 'MGL501', title: 'Architecture Logicielle & Spécification Formelle', meta: 'Master 1 Génie Logiciel · S1   ·   6 ECTS', status: 'Dispenser', color: slate, students: '', children: const []),
            const SizedBox(height: 4),
            const Text('Habilitation officielle décennale : 2024–2027', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate)),
          ]),
        ),
      );
}

class _TFilter extends StatelessWidget {
  final String label;
  final bool active;
  const _TFilter({required this.label, this.active = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: active ? red : paper,
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 8, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? Colors.white : slate)),
      );
}

class _TWeightPill extends StatelessWidget {
  final String label;
  final Color color;
  const _TWeightPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(color: color, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)));
}

class _TUnitBlock extends StatelessWidget {
  final String code, title, meta, status, students;
  final Color color;
  final List<Widget> children;
  const _TUnitBlock({required this.code, required this.title, required this.meta, required this.status, required this.color, required this.students, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        decoration: BoxDecoration(color: color == red ? const Color(0xFFFBF9F2) : paperLight, border: Border(left: BorderSide(color: color, width: 3), top: BorderSide(color: ink.withValues(alpha: .14)), right: BorderSide(color: ink.withValues(alpha: .14)), bottom: BorderSide(color: ink.withValues(alpha: .14)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _TBadge(label: code, color: color),
            const SizedBox(width: 7),
            Expanded(child: Text(meta, style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 8))),
            _TBadge(label: status, color: color),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontFamily: 'Fraunces', fontSize: 15, fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 3), const Text('Responsable d’UE : Pr. NDJOCK B. (Coordonnateur)', style: TextStyle(fontSize: 8, color: slate))])),
            if (students.isNotEmpty) Text(students, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, fontWeight: FontWeight.bold, color: ink)),
          ]),
          if (children.isNotEmpty) ...[
            const Divider(height: 17),
            ...children,
          ],
        ]),
      );
}

class _TEcLine extends StatelessWidget {
  final String code, title, details, action;
  const _TEcLine({required this.code, required this.title, required this.details, required this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          const Icon(Icons.check_box, color: red, size: 15),
          const SizedBox(width: 7),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$code : $title', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8, color: ink)),
            Text(details, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate)),
          ])),
          FilledButton(onPressed: () => _tNotice(context, '$action sélectionné.'), style: FilledButton.styleFrom(minimumSize: const Size(0, 29), padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(action, style: const TextStyle(fontSize: 9))),
        ]),
      );
}

class _TTeachingPlan extends StatelessWidget {
  const _TTeachingPlan();
  @override
  Widget build(BuildContext context) => Column(children: const [_TPlanCard(), SizedBox(height: 16), _TClassStats()]);
}

class _TPlanCard extends StatelessWidget {
  const _TPlanCard();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.view_timeline_outlined, color: red, size: 18), const SizedBox(width: 8), const Expanded(child: Text('Plan de Dispensation & Progression (INF301)', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink, fontSize: 16))), _TBadge(label: 'Volume : 65h', color: valid)]),
            const SizedBox(height: 14),
            const _TPlanInfo(label: 'LIEU CM', value: 'Amphi Théâtre 250'),
            const SizedBox(height: 6),
            const _TPlanInfo(label: 'SALLE TP', value: 'Labo Info 4 / Salle 4'),
            const SizedBox(height: 6),
            const _TPlanInfo(label: 'GROUPES', value: 'G1 & G2 (84 étudiants)'),
            const SizedBox(height: 6),
            const _TPlanInfo(label: 'PONDÉRATION LMD', value: '20% CC · 30% TP · 50% SN'),
            const SizedBox(height: 17),
            const Text('VOLUMES HORAIRES DISPENSÉS :', style: TextStyle(fontFamily: 'monospace', color: slate, fontSize: 9)),
            const SizedBox(height: 10),
            const _TProgressLine(label: 'Cours Magistraux (CM) · Pr. Ndjock', value: '24h / 30h (80%)', progress: .8, color: red),
            const _TProgressLine(label: 'Travaux Dirigés (TD) · Pr. Ndjock', value: '12h / 15h (80%)', progress: .8, color: gold),
            const _TProgressLine(label: 'Travaux Pratiques (TP Machine) · M. Manga', value: '18h / 20h (90%)', progress: .9, color: valid),
            const SizedBox(height: 15),
            const Text('CALENDRIER DES ÉPREUVES RETENUES :', style: TextStyle(fontFamily: 'monospace', color: slate, fontSize: 9)),
            const SizedBox(height: 8),
            const _TExamLine(code: 'CC 20%', label: 'Contrôle écrit (Amphi 250)', date: '12 Mars 2025 · 14h00', color: gold),
            const _TExamLine(code: 'TP 30%', label: 'Épreuve Pratique (Labo 4)', date: '18 Mars 2025 · 08h00', color: ink),
            const _TExamLine(code: 'SN 50%', label: 'Examen Final Décanat', date: '04 Avril 2025 · 08h00', color: red),
          ]),
        ),
      );
}

class _TPlanInfo extends StatelessWidget {
  final String label, value;
  const _TPlanInfo({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(8), color: paper, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.bold, color: ink))]));
}

class _TProgressLine extends StatelessWidget {
  final String label, value;
  final double progress;
  final Color color;
  const _TProgressLine({required this.label, required this.value, required this.progress, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 9, color: ink))), Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate))]),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(1), child: LinearProgressIndicator(value: progress, minHeight: 5, color: color, backgroundColor: color.withValues(alpha: .15))),
        ]),
      );
}

class _TExamLine extends StatelessWidget {
  final String code, label, date;
  final Color color;
  const _TExamLine({required this.code, required this.label, required this.date, required this.color});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 5), padding: const EdgeInsets.all(7), color: paper, child: Row(children: [_TWeightPill(label: code, color: color), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(fontSize: 9, color: ink))), Text(date, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate))]));
}

class _TClassStats extends StatelessWidget {
  const _TClassStats();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 38, height: 38, color: red.withValues(alpha: .12), child: const Icon(Icons.analytics_outlined, color: red, size: 19)),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Statistiques Actuelles de la Classe (INF301)', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, fontSize: 13, color: ink)), SizedBox(height: 3), Text('Moyenne générale provisoire : 13.25/20 · Taux de succès estimé : 86.4%', style: TextStyle(fontSize: 9, color: slate))])),
          ]),
        ),
      );
}

class _TStudentsRegister extends StatelessWidget {
  final VoidCallback onEntry, onExport;
  const _TStudentsRegister({required this.onEntry, required this.onExport});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: LayoutBuilder(builder: (context, constraints) {
              const title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Registre Officiel des Étudiants Rattachés (INF301)', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink, fontSize: 19)), SizedBox(height: 4), Text('84 Inscrits · Pondération LMD officielle : Moy = 0.20×CC + 0.30×TP + 0.50×SN', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate))]);
              final actions = Wrap(spacing: 7, runSpacing: 6, children: [OutlinedButton.icon(onPressed: onEntry, icon: const Icon(Icons.upload_file_outlined, size: 15), label: const Text('Importer des notes')), OutlinedButton.icon(onPressed: () => _tNotice(context, 'Liste d’étudiants prête.'), icon: const Icon(Icons.print_outlined, size: 15), label: const Text('Imprimer la liste')), FilledButton.icon(onPressed: onExport, icon: const Icon(Icons.file_download_outlined, size: 15), label: const Text('Exporter & Transmettre'))]);
              if (constraints.maxWidth < 820) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), actions]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), const SizedBox(width: 12), actions]);
            }),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(10), child: Row(children: [const Expanded(child: _TSearchField(hint: 'Filtrer par nom ou matricule…')), const SizedBox(width: 14), const Text('Groupe :', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)), const SizedBox(width: 5), _TFilter(label: 'Tous (84)', active: true), const SizedBox(width: 5), const _TFilter(label: 'G1 (42)'), const SizedBox(width: 5), const _TFilter(label: 'G2 (42)'), const SizedBox(width: 14), const Text('3 notes en attente', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold, fontSize: 9))])),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
            headingRowColor: WidgetStatePropertyAll(paper),
            columnSpacing: 20,
            headingTextStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9, color: slate),
            columns: const [DataColumn(label: Text('MATRICULE')), DataColumn(label: Text('NOM & PRÉNOMS DE L’ÉTUDIANT')), DataColumn(label: Text('GRPE')), DataColumn(label: Text('CC /20')), DataColumn(label: Text('TP /20')), DataColumn(label: Text('SN /20')), DataColumn(label: Text('MOY. /20')), DataColumn(label: Text('STATUT'))],
            rows: [
              _TStudentRow('21U2094', 'ABENA ESSOMBA Jean-Marc', 'G1', '15.50', '16.00', '14.50', '15.15', 'Validé', valid),
              _TStudentRow('21U2412', 'BIKOUÉ NDOUMBE Carine', 'G1', '12.00', '—', '13.00', 'INC.', 'TP Attente', red),
              _TStudentRow('21U2849', 'DJOUKA FOTSO Franck Kevin', 'G2', '14.00', '13.50', '11.50', '12.60', 'Validé', valid),
              _TStudentRow('21U2991', 'EKANE TCHINDA Rostand', 'G2', '06.50', '11.00', '09.00', '09.10', 'Rattrapage', gold),
              _TStudentRow('21U3104', 'KAMDEM WABO Ulrich', 'G1', '17.25', '18.00', '16.50', '17.10', 'Très Bien', valid),
              _TStudentRow('21U3250', 'MBIANGA TCHOUA Sarah', 'G2', '13.00', '14.00', '12.00', '12.80', 'Validé', valid),
            ],
          )),
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Expanded(child: Text('Affichage des 6 premiers étudiants inscrits sur 84 inscrits officiels · Registre certifié transmis au jury de délibération.', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate))), TextButton(onPressed: () {}, child: const Text('Préc.')), const Text('Page 1 / 14', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: ink)), TextButton(onPressed: () {}, child: const Text('Suiv.'))])),
        ]),
      );
}

class _TSearchField extends StatelessWidget {
  final String hint;
  const _TSearchField({required this.hint});
  @override
  Widget build(BuildContext context) => SizedBox(height: 35, child: TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 16), hintText: hint, hintStyle: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate), filled: true, fillColor: paperLight, border: OutlineInputBorder(borderSide: BorderSide(color: ink.withValues(alpha: .18))), contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4))));
}

class _TStudentRow extends DataRow {
  _TStudentRow(String matricule, String name, String group, String cc, String tp, String sn, String average, String status, Color color)
      : super(cells: [
          DataCell(Text(matricule, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10, color: ink))),
          DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 10, color: ink)), const Text('Régulier · Première inscription', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate))])),
          DataCell(Text(group, style: const TextStyle(fontFamily: 'monospace', fontSize: 9))),
          DataCell(_TMark(value: cc, color: cc == '06.50' ? red : ink)),
          DataCell(_TMark(value: tp, color: tp == '—' ? red : ink)),
          DataCell(_TMark(value: sn, color: ink)),
          DataCell(Text(average, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10, color: color))),
          DataCell(_TBadge(label: status, color: color)),
        ]);
}

class _TMark extends StatelessWidget {
  final String value;
  final Color color;
  const _TMark({required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .35))), child: Text(value, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9, color: color)));
}

class TeacherRequestsPage extends StatefulWidget {
  const TeacherRequestsPage({super.key});
  @override
  State<TeacherRequestsPage> createState() => _TeacherRequestsPageState();
}

class _TeacherRequestsPageState extends State<TeacherRequestsPage> {
  bool firstRectified = false;
  String level = 'L3 INFO (3)';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const TeacherAppBar(section: TeacherSection.requests),
        body: _TFrame(children: [
          const _TContextBar(),
          const SizedBox(height: 18),
          _TRequestsHero(onExport: () => _tNotice(context, 'Export des requêtes préparé.'), onPdf: () => _tNotice(context, 'PV rectificatif PDF préparé.')),
          const SizedBox(height: 15),
          _TRequestFilters(selected: level, onChanged: (value) => setState(() => level = value)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final side = const _TRequestSidebar();
            final content = Column(children: [
              _TRequestCard(
                code: 'REQ-2025-0842',
                studentId: '21U2412',
                student: 'TCHOUENTCHEU KAMDEM Guy Arnaud',
                group: 'Groupe TP G1 · Parcours Informatique Générale',
                ec: 'INF301 · EC 301.2 Travaux Pratiques Machine',
                status: firstRectified ? 'VALIDÉE / NOTE RECTIFIÉE' : 'EN ATTENTE D’ARBITRAGE',
                color: firstRectified ? valid : pending,
                before: 'TP 00/20',
                after: firstRectified ? '16.00/20' : '16.00/20',
                reason: 'OMISSION D’ÉVALUATION TP LORS DE LA CENTRALISATION DES FEUILLES DE PRÉSENCE',
                description: '« Présence physique attestée lors de la session pratique finale. Mon travail a été vérifié et noté en séance à 16.00/20 par le chargé de TP, mais une note par défaut de 00/20 a été reportée sur l’affichage officiel. »',
                evidence: 'Émargement fiche TP signé (émargement_tp4_signé.pdf)',
                action: firstRectified ? null : () => setState(() => firstRectified = true),
                actionLabel: 'Rectifier la note',
              ),
              const SizedBox(height: 15),
              const _TRequestCard(
                code: 'REQ-2025-0839', studentId: '21U2110', student: 'MENGUELE EKANI Marie-Claire', group: 'Groupe CM G1 · Matrice Informatique Théorique', ec: 'INF301 · EC 301.1 CM/TD (Contrôle Continu)', status: 'VALIDÉE / NOTE RECTIFIÉE', color: valid, before: 'CC 08.50/20', after: '14.00/20', reason: 'ERREUR DE REPORT SUR BORDEREAU OFFICIEL (INVERSION DE LIGNE CORRIGÉE)', description: '« La copie physique du contrôle continu portait la note 14.00/20. Le secrétariat a reporté 08.50/20 suite à un décalage d’interligne sur la fiche récapitulative. »', evidence: 'Rectification enregistrée au registre avec mention décennale le 24/02/2025 à 09:10', resolved: true),
              const SizedBox(height: 15),
              const _TRequestCard(
                code: 'REQ-2025-0814', studentId: '21U2991', student: 'EKANE TCHINDA Rostand', group: 'Groupe CM G2 · Systèmes & Réseaux LMD', ec: 'INF301 · EC 301.1 Contrôle Continu', status: 'EN COURS D’EXAMEN', color: gold, before: 'CC 06.50/20', after: 'Sous seuil élim.', reason: 'NOTE CC CONTESTÉE SOUS LE SEUIL ÉLIMINATOIRE (06.50/20) — DEMANDE DE RÉÉVALUATION', description: '« Demande de vérification du décompte des points de l’exercice 3 (Complexité des algorithmes de hachage). Une question entière de 4 points ne semble pas avoir été comptabilisée lors du calcul du total. »', evidence: 'Copie physique extraite de l’archive décennale · En attente de révision par l’enseignant', underReview: true),
            ]);
            if (constraints.maxWidth < 930) return Column(children: [side, const SizedBox(height: 16), content]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 290, child: side), const SizedBox(width: 16), Expanded(child: content)]);
          }),
          const _TFooter(),
        ]),
      );
}

class _TRequestsHero extends StatelessWidget {
  final VoidCallback onExport, onPdf;
  const _TRequestsHero({required this.onExport, required this.onPdf});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(21, 18, 21, 16),
          child: LayoutBuilder(builder: (context, constraints) {
            const title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SESSION ORDINAIRE 2024–2025   |   PORTAIL D’ARBITRAGE LMD', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold, fontSize: 9)),
              SizedBox(height: 8),
              Text('Registre Officiel des Réclamations Académiques', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink, fontSize: 26)),
              SizedBox(height: 7),
              Text('Bureau de Traitement des Requêtes Académiques — Examen, arbitrage et rectification des réclamations sur notes déposées par les étudiants.', style: TextStyle(fontSize: 11, color: ink)),
            ]);
            final actions = Wrap(spacing: 8, runSpacing: 7, children: [OutlinedButton.icon(onPressed: onExport, icon: const Icon(Icons.table_view_outlined, size: 16), label: const Text('Exporter (.xlsx)')), OutlinedButton.icon(onPressed: onPdf, icon: const Icon(Icons.picture_as_pdf_outlined, size: 16), label: const Text('PV Rectificatif (.pdf)'))]);
            if (constraints.maxWidth < 760) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 14), actions]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), const SizedBox(width: 18), actions]);
          }),
        ),
      );
}

class _TRequestFilters extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _TRequestFilters({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: LayoutBuilder(builder: (context, constraints) {
            final levels = ['Tous', 'L1', 'L2', 'L3 INFO (3)', 'M1', 'M2'];
            final filters = Wrap(spacing: 5, runSpacing: 5, children: levels.map((item) => InkWell(onTap: () => onChanged(item), child: _TFilter(label: item, active: selected == item))).toList());
            final ue = SizedBox(width: 350, child: DropdownButtonFormField<String>(initialValue: 'INF301', isDense: true, decoration: const InputDecoration(prefixText: 'UE :   ', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: const [DropdownMenuItem(value: 'INF301', child: Text('INF301 - Algorithmique Avancée (L3)', style: TextStyle(fontFamily: 'monospace', fontSize: 10)))], onChanged: (_) {}));
            if (constraints.maxWidth < 850) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [filters, const SizedBox(height: 9), Wrap(spacing: 8, runSpacing: 8, children: [ue, const SizedBox(width: 250, child: _TSearchField(hint: 'Rechercher par matricule ou nom…'))])]);
            return Row(children: [const Text('NIVEAU :', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9, color: ink)), const SizedBox(width: 10), Expanded(child: filters), ue, const SizedBox(width: 9), const SizedBox(width: 220, child: _TSearchField(hint: 'Rechercher par matricule…'))]);
          }),
        ),
      );
}

class _TRequestSidebar extends StatelessWidget {
  const _TRequestSidebar();
  @override
  Widget build(BuildContext context) => Column(children: const [_TRequestTypes(), SizedBox(height: 15), _TRequestDeployment()]);
}

class _TRequestTypes extends StatelessWidget {
  const _TRequestTypes();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Row(children: [Icon(Icons.pie_chart_outline, color: gold), SizedBox(width: 8), Expanded(child: Text('Typologie des Requêtes (L3)', style: TextStyle(fontFamily: 'Fraunces', fontSize: 17, fontWeight: FontWeight.bold, color: ink))), _TBadge(label: 'Total : 4', color: ink)]),
            const Divider(height: 20),
            Container(width: 126, height: 126, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: red, width: 17)), child: const Center(child: Text('100%\nAUDITÉ', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Fraunces', color: ink, fontWeight: FontWeight.bold, fontSize: 18)))),
            const SizedBox(height: 18),
            const _TLegend(color: red, text: 'Erreurs de report CC/CM', percent: '50% (2)'),
            const _TLegend(color: gold, text: 'Omission/Inversion TP', percent: '35% (1)'),
            const _TLegend(color: ink, text: 'Rectification d’absence', percent: '15% (1)'),
          ]),
        ),
      );
}

class _TLegend extends StatelessWidget {
  final Color color;
  final String text, percent;
  const _TLegend({required this.color, required this.text, required this.percent});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [Row(children: [Container(width: 9, height: 9, color: color), const SizedBox(width: 6), Expanded(child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate))), Text(percent, style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: ink))]), const SizedBox(height: 4), LinearProgressIndicator(value: percent.startsWith('50') ? .5 : percent.startsWith('35') ? .35 : .15, minHeight: 3, color: color, backgroundColor: paper)]));
}

class _TRequestDeployment extends StatelessWidget {
  const _TRequestDeployment();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.fact_check_outlined, color: red, size: 18), const SizedBox(width: 8), const Expanded(child: Text('Dépouillement des Dossiers', style: TextStyle(fontFamily: 'Fraunces', fontSize: 17, fontWeight: FontWeight.bold, color: ink)),), _TBadge(label: 'L3 Info', color: valid)]),
            const Divider(height: 20),
            const _TKeyValue(label: 'Requêtes reçues', value: '12'),
            const _TKeyValue(label: 'Traitées & validées', value: '8', color: valid),
            const _TKeyValue(label: 'En attente d’instruction', value: '4', color: gold),
            const SizedBox(height: 12),
            const LinearProgressIndicator(value: .667, minHeight: 7, color: valid, backgroundColor: gold),
            const SizedBox(height: 5),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('66.7% Complété', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate)), Text('4 dossiers restants', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: slate))]),
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.all(10), color: paper, child: const Text('◷ DÉLAI RESTANT : 04 heures 18 min', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: red, fontSize: 10))),
          ]),
        ),
      );
}

class _TKeyValue extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TKeyValue({required this.label, required this.value, this.color = slate});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [Expanded(child: Text('$label :', style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate))), _TBadge(label: value, color: color)]));
}

class _TRequestCard extends StatelessWidget {
  final String code, studentId, student, group, ec, status, before, after, reason, description, evidence;
  final Color color;
  final VoidCallback? action;
  final String? actionLabel;
  final bool resolved, underReview;
  const _TRequestCard({required this.code, required this.studentId, required this.student, required this.group, required this.ec, required this.status, required this.color, required this.before, required this.after, required this.reason, required this.description, required this.evidence, this.action, this.actionLabel, this.resolved = false, this.underReview = false});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(side: BorderSide(color: ink.withValues(alpha: .2)), borderRadius: BorderRadius.circular(3)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [_TBadge(label: code, color: ink), _TBadge(label: 'L3 INFO', color: red), Text(ec, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)), _TBadge(label: status, color: color)]),
            const Divider(height: 19),
            LayoutBuilder(builder: (context, constraints) {
              final identity = Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: paper, border: Border.all(color: ink.withValues(alpha: .35))), child: Text(studentId, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: ink))), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(student, style: const TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink, fontSize: 18)), Text(group, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate))]))]);
              final notes = _TNoteChange(before: before, after: after, color: color);
              if (constraints.maxWidth < 630) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, const SizedBox(height: 12), notes]);
              return Row(children: [Expanded(child: identity), const SizedBox(width: 16), notes]);
            }),
            const SizedBox(height: 14),
            Container(width: double.infinity, padding: const EdgeInsets.all(13), color: paper, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('⚠ MOTIF : $reason', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color, fontSize: 9)), const SizedBox(height: 7), Text(description, style: const TextStyle(fontSize: 11, color: ink, height: 1.4)), const SizedBox(height: 9), Text('Preuve fournie :  ▧ $evidence', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: resolved ? valid : slate))])),
            const SizedBox(height: 12),
            if (resolved)
              Row(children: [const Expanded(child: Text('Statut délibératif : UE validée (Crédit acquis 6/6)', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate))), OutlinedButton.icon(onPressed: () => _tNotice(context, 'Récépissé imprimable.'), icon: const Icon(Icons.print_outlined, size: 15), label: const Text('Imprimer récépissé'))])
            else if (underReview)
              Wrap(spacing: 8, runSpacing: 8, children: [const Text('Décision d’arbitrage :', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: ink)), SizedBox(width: 320, child: DropdownButtonFormField<String>(initialValue: 'Maintenir la note', isDense: true, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)), items: const [DropdownMenuItem(value: 'Maintenir la note', child: Text('Maintenir la note actuelle (06.50/20)', style: TextStyle(fontFamily: 'monospace', fontSize: 9))), DropdownMenuItem(value: 'Réévaluer', child: Text('Demander une réévaluation', style: TextStyle(fontFamily: 'monospace', fontSize: 9)))], onChanged: (_) {})), OutlinedButton.icon(onPressed: () => _tNotice(context, 'Copie ouverte pour examen.'), icon: const Icon(Icons.search, size: 15), label: const Text('Examiner la copie')), FilledButton.icon(onPressed: () => _tNotice(context, 'Décision d’arbitrage enregistrée.'), icon: const Icon(Icons.check, size: 15), label: const Text('Valider la décision'))])
            else
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [const Text('Note de rectification :', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10, color: ink)), SizedBox(width: 68, height: 35, child: TextFormField(initialValue: '16.00', textAlign: TextAlign.center, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 4)))), const Text('/ 20   ✓ Conforme', style: TextStyle(fontFamily: 'monospace', color: valid, fontSize: 9)), OutlinedButton.icon(onPressed: () => _tNotice(context, 'Pièce jointe ouverte.'), icon: const Icon(Icons.visibility_outlined, size: 15), label: const Text('Voir pièce jointe')), OutlinedButton(onPressed: () => _tNotice(context, 'Requête rejetée.'), style: OutlinedButton.styleFrom(foregroundColor: red), child: const Text('Rejeter')), FilledButton.icon(onPressed: action, icon: const Icon(Icons.edit_document, size: 15), label: Text(actionLabel ?? 'Rectifier'))]),
          ]),
        ),
      );
}

class _TNoteChange extends StatelessWidget {
  final String before, after;
  final Color color;
  const _TNoteChange({required this.before, required this.after, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: paper, border: Border.all(color: ink.withValues(alpha: .2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Column(children: [const Text('NOTE CONTESTÉE', style: TextStyle(fontFamily: 'monospace', fontSize: 7, color: slate)), const SizedBox(height: 3), Text(before, style: const TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold, fontSize: 10))]), const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward, size: 16, color: slate)), Column(children: [const Text('NOTE RÉCLAMÉE', style: TextStyle(fontFamily: 'monospace', fontSize: 7, color: slate)), const SizedBox(height: 3), Text(after, style: TextStyle(fontFamily: 'monospace', color: color, fontWeight: FontWeight.bold, fontSize: 10))]) ]));
}

class GradeEntryPage extends StatefulWidget {
  const GradeEntryPage({super.key});
  @override
  State<GradeEntryPage> createState() => _TeacherGradeEntryPageState();
}

class _TeacherGradeEntryPageState extends State<GradeEntryPage> {
  String selectedUe = 'INF301 : Algorithmique Avancée & Structures de Données';
  int tab = 0;
  bool verified = false;
  bool submitted = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const TeacherAppBar(section: TeacherSection.grades),
        body: _TFrame(children: [
          const _TContextBar(),
          const SizedBox(height: 18),
          _TGradeHeader(selectedUe: selectedUe, onChanged: (value) => setState(() => selectedUe = value)),
          const SizedBox(height: 16),
          _TGradeActions(onNotice: (message) => _tNotice(context, message)),
          const SizedBox(height: 12),
          _TGradeSummary(verified: verified, onVerify: () => setState(() => verified = true)),
          const SizedBox(height: 12),
          _TGradeTabs(tab: tab, onChanged: (value) => setState(() => tab = value)),
          const SizedBox(height: 8),
          _TGradeTable(tab: tab),
          const SizedBox(height: 18),
          _TGradeCommitment(verified: verified, submitted: submitted, onDraft: () => _tNotice(context, 'Brouillon enregistré localement.'), onSubmit: () => setState(() => submitted = true)),
          const _TFooter(),
        ]),
      );
}

class _TGradeHeader extends StatelessWidget {
  final String selectedUe;
  final ValueChanged<String> onChanged;
  const _TGradeHeader({required this.selectedUe, required this.onChanged});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 21, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(builder: (context, constraints) {
              const intro = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('REGISTRE OFFICIEL   CODE ÉPREUVE · INF301-REG-2024S1', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold, fontSize: 10)),
                SizedBox(height: 8),
                Text('Saisie & Contrôle Réglementaire des Notes', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink, fontSize: 27)),
                SizedBox(height: 7),
                Text('Bordereau officiel d’évaluation continue et terminale certifié par le responsable pédagogique de l’UE.', style: TextStyle(color: slate)),
              ]);
              final selector = SizedBox(width: 400, child: DropdownButtonFormField<String>(initialValue: selectedUe, isExpanded: true, decoration: const InputDecoration(labelText: 'UNITÉ D’ENSEIGNEMENT (UE)', filled: true, fillColor: paper, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9)), items: const [DropdownMenuItem(value: 'INF301 : Algorithmique Avancée & Structures de Données', child: Text('INF301 : Algorithmique Avancée & Structures de Données', overflow: TextOverflow.ellipsis)), DropdownMenuItem(value: 'INF305 : Systèmes & Réseaux', child: Text('INF305 : Systèmes & Réseaux')), DropdownMenuItem(value: 'INF201 : C/C++ Fondamental', child: Text('INF201 : C/C++ Fondamental'))], onChanged: (value) { if (value != null) onChanged(value); }));
              if (constraints.maxWidth < 760) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [intro, const SizedBox(height: 15), selector]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: intro), const SizedBox(width: 18), selector]);
            }),
            const Divider(height: 26),
            const Wrap(spacing: 10, runSpacing: 10, children: [
              _TGradeWeight(title: 'Contrôle Continu (CC)', percent: '20%', detail: 'Interrogations / Devoirs', color: red),
              _TGradeWeight(title: 'Travaux Pratiques (TP)', percent: '30%', detail: 'Laboratoires & Mini-projets', color: gold),
              _TGradeWeight(title: 'Examen Terminal (SN)', percent: '50%', detail: 'Session Normale d’amphithéâtre', color: ink),
              _TGradeWeight(title: 'Seuil éliminatoire', percent: '< 07.00/20', detail: 'Toute note < 07.00 en CC, TP ou SN invalide l’UE.', color: red),
            ]),
          ]),
        ),
      );
}

class _TGradeWeight extends StatelessWidget {
  final String title, percent, detail;
  final Color color;
  const _TGradeWeight({required this.title, required this.percent, required this.detail, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(width: 264, child: Container(padding: const EdgeInsets.all(13), color: paper, child: Row(children: [Container(padding: const EdgeInsets.all(6), color: color.withValues(alpha: .14), child: Text(percent, style: TextStyle(fontFamily: 'monospace', color: color, fontWeight: FontWeight.bold, fontSize: 10))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: ink, fontSize: 12)), const SizedBox(height: 3), Text(detail, style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 9))]))])));
}

class _TGradeActions extends StatelessWidget {
  final ValueChanged<String> onNotice;
  const _TGradeActions({required this.onNotice});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(10), child: Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.icon(onPressed: () => onNotice('Importation XLSX simulée.'), icon: const Icon(Icons.upload_file_outlined, size: 16), label: const Text('Importer une liste remplie de notes (.xlsx)')), OutlinedButton.icon(onPressed: () => onNotice('Liste vierge prête.'), icon: const Icon(Icons.download_outlined, size: 16), label: const Text('Télécharger la liste vierge des étudiants (.xlsx)')), OutlinedButton.icon(onPressed: () => onNotice('Bordereau certifié prêt.'), icon: const Icon(Icons.fact_check_outlined, size: 16), label: const Text('Bordereau certifié (.xlsx)')), TextButton.icon(onPressed: () => onNotice('Feuille d’émargement ouverte.'), icon: const Icon(Icons.print_outlined, size: 16), label: const Text('Feuille d’émargement & notes'))])));
}

class _TGradeSummary extends StatelessWidget {
  final bool verified;
  final VoidCallback onVerify;
  const _TGradeSummary({required this.verified, required this.onVerify});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(side: const BorderSide(color: gold, width: 2)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: LayoutBuilder(builder: (context, constraints) {
            const completion = Row(children: [CircleAvatar(radius: 20, backgroundColor: Color(0xFFE1E8DA), child: Text('96%', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10, color: ink))), SizedBox(width: 11), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Notes saisies : 81 / 84', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), Text('● Complétude globale : 96.4%', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: valid))]) ]);
            const missing = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('▣  3 notes manquantes', style: TextStyle(fontWeight: FontWeight.bold, color: red)), Text('1 absence justifiée (INC) · 2 non saisies', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)), SizedBox(height: 6), Text('⚠ 2 notes sous le seuil < 07.00/20', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9, color: red))]);
            final button = FilledButton.icon(onPressed: onVerify, icon: Icon(verified ? Icons.verified : Icons.settings_outlined, size: 17), label: Text(verified ? 'Saisie vérifiée' : 'Vérifier & Valider la saisie pour transmission'));
            if (constraints.maxWidth < 720) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [completion, const SizedBox(height: 13), missing, const SizedBox(height: 14), button]);
            return Row(children: [Expanded(child: completion), Expanded(child: missing), button]);
          }),
        ),
      );
}

class _TGradeTabs extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onChanged;
  const _TGradeTabs({required this.tab, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const labels = ['Vue Synthétique Globale (CC + TP + SN)', 'Contrôle Continu (CC 20%)', 'Travaux Pratiques (TP 30%)', 'Session Normale (SN 50%)'];
    return Card(elevation: 0, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), child: Wrap(spacing: 3, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [for (var i = 0; i < labels.length; i++) TextButton(onPressed: () => onChanged(i), style: TextButton.styleFrom(backgroundColor: tab == i ? paper : Colors.transparent, foregroundColor: tab == i ? ink : slate, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), child: Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: tab == i ? FontWeight.bold : FontWeight.normal))), const SizedBox(width: 8), const Text('GROUPE :', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate)), const _TFilter(label: 'Tous (84)', active: true), const _TFilter(label: 'Groupe 1 (42)'), const _TFilter(label: 'Groupe 2 (42)')])));
  }
}

class _TGradeTable extends StatelessWidget {
  final int tab;
  const _TGradeTable({required this.tab});
  static DataCell _text(String value, {Color color = ink, bool bold = false}) => DataCell(Text(value, style: TextStyle(fontFamily: 'monospace', color: color, fontSize: 10, fontWeight: bold ? FontWeight.bold : FontWeight.normal)));
  static DataCell _input(String value, {Color color = ink}) => DataCell(SizedBox(width: 68, height: 35, child: TextFormField(initialValue: value, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: color, fontWeight: FontWeight.bold, fontSize: 11), decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), border: OutlineInputBorder(borderSide: BorderSide(color: color.withValues(alpha: .45)))))));
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStatePropertyAll(paper),
          headingTextStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9, color: slate),
          columnSpacing: 16,
          dataRowMinHeight: 55,
          dataRowMaxHeight: 64,
          columns: const [DataColumn(label: Text('N°')), DataColumn(label: Text('MATRICULE')), DataColumn(label: Text('NOM & PRÉNOMS DE L’ÉTUDIANT')), DataColumn(label: Text('GRP')), DataColumn(label: Text('CC /20 (20%)')), DataColumn(label: Text('TP /20 (30%)')), DataColumn(label: Text('SN /20 (50%)')), DataColumn(label: Text('MOY. /20')), DataColumn(label: Text('DÉCISION LMD')), DataColumn(label: Text('VÉRIFICATION'))],
          rows: [
            _row('01', '21U2094', 'ABENA ESSOMBA Jean-Marc', 'G1', '15.50', '16.00', '14.50', '15.15', '✓ VALIDÉ (B+)', valid, 'VÉRIFIÉ'),
            _row('02', '21U2412', 'BIKOUÉ NDOUMBE Carine', 'G1', '12.00', 'INC', '--', '— / —', 'INCOMPLET JUSTIFIÉ', pending, 'À RÉGULARISER'),
            _row('03', '21U2991', 'EKANE TCHINDA Rostand', 'G2', '06.50', '11.00', '09.00', '09.10', 'ÉLIMINÉ (CC < 07)', red, 'ALERTE SEUIL'),
            _row('04', '21U3104', 'KAMDEM WABO Ulrich', 'G2', '17.25', '18.00', '16.50', '17.10', '✓ VALIDÉ (A)', valid, 'VÉRIFIÉ'),
            _row('05', '21U2849', 'DJOUKA FOTSO Franck Kevin', 'G1', '14.00', '13.50', '11.50', '12.60', '✓ VALIDÉ (C+)', valid, 'VÉRIFIÉ'),
            _row('06', '21U2118', 'MANGA ATANGANA Boris Cyrille', 'G2', '11.50', '10.00', '— /20', '— / —', 'NOTE SN MANQUANTE', red, 'À SAISIR'),
            _row('07', '21U2505', 'NGO MBOCK Madeleine Viviane', 'G1', '10.50', '12.00', '10.00', '10.70', '✓ VALIDÉ (C)', valid, 'VÉRIFIÉ'),
            _row('08', '21U3290', 'OWONA TSIMI Pierre-Charles', 'G2', '13.00', '05.50', '11.00', '09.75', 'ÉLIMINÉ (TP < 07)', red, 'ALERTE SEUIL'),
            _row('09', '21U1980', 'TCHOUMI KOUAM Patrick', 'G1', '14.00', '15.00', '13.50', '14.05', '✓ VALIDÉ (B)', valid, 'VÉRIFIÉ'),
            _row('10', '21U2754', 'ZAMBO ELA Christian Paul', 'G2', '12.50', '11.50', '12.00', '11.95', '✓ VALIDÉ (C+)', valid, 'VÉRIFIÉ'),
          ],
        )),
      );
  DataRow _row(String number, String id, String name, String group, String cc, String tp, String sn, String average, String decision, Color color, String verification) => DataRow(cells: [_text(number), _text(id, bold: true), DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: ink, fontSize: 11))), _text(group), _input(cc, color: cc == '06.50' ? red : ink), _input(tp, color: tp == '05.50' || tp == 'INC' ? red : ink), _input(sn, color: sn.startsWith('—') ? red : ink), _text(average, color: color, bold: true), DataCell(Text(decision, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color, fontSize: 9)),), DataCell(_TBadge(label: verification, color: color))]);
}

class _TGradeCommitment extends StatelessWidget {
  final bool verified, submitted;
  final VoidCallback onDraft, onSubmit;
  const _TGradeCommitment({required this.verified, required this.submitted, required this.onDraft, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: LayoutBuilder(builder: (context, constraints) {
            const text = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.fact_check_outlined, color: ink, size: 28), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Engagement & Responsabilité Pédagogique', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 4), Text('En certifiant ce bordereau, le Pr. NDJOCK B. atteste de l’exactitude des notes saisies conformément à la charte universitaire LMD.', style: TextStyle(fontSize: 10, color: slate))]))]);
            final actions = Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton(onPressed: onDraft, child: const Text('Enregistrer brouillon')), FilledButton(onPressed: verified ? onSubmit : null, child: Text(submitted ? 'Soumis au Décanat ✓' : 'Soumettre au Décanat'))]);
            if (constraints.maxWidth < 700) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 13), actions]);
            return Row(children: [Expanded(child: text), const SizedBox(width: 12), actions]);
          }),
        ),
      );
}
