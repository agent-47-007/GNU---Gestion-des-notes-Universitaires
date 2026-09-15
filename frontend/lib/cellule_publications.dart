part of 'main.dart';

class CellulePublicationsContent extends StatefulWidget {
  const CellulePublicationsContent({super.key});

  @override
  State<CellulePublicationsContent> createState() =>
      _CellulePublicationsContentState();
}

class _CellulePublicationsContentState
    extends State<CellulePublicationsContent> {
  bool _studentPortal = true;
  bool _noticeBoard = false;

  Future<void> _confirmPublication(CelluleWorkspace workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Simuler la publication des résultats'),
        content: Text(
          'Cette action termine le parcours de démonstration pour '
          '${workspace.students.length} étudiants. '
          'Aucun résultat ne sera publié, aucun message ne sera envoyé '
          'et aucun document ne sera signé.\n\n'
          'Canaux sélectionnés : '
          '${[
            if (_studentPortal) 'portail étudiant',
            if (_noticeBoard) 'panneau décanal',
          ].join(', ')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmer la simulation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = workspace.simulatePublication();
    celluleNotice(
      context,
      success
          ? 'Simulation terminée. Aucun résultat transmis au portail.'
          : 'La cohorte doit être complète, calculée et vérifiée au préalable.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = CelluleScope.of(context);
    final completed = workspace.students
        .where((student) => workspace.result(student).complete)
        .length;
    final allComplete = completed == workspace.students.length;
    final missing = workspace.students.length - completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CelluleHeading(
          eyebrow: 'REGISTRE DES RÉSULTATS · CELLULE INFORMATIQUE',
          title: 'Bulletins & Publications',
          subtitle:
              'Préparer les relevés, contrôler la cohorte et suivre le circuit de publication.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => workspace.openSection(CelluleSection.bulletin),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Prévisualiser un bulletin'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PublicationStatusStrip(
          title: 'MODULE BULLETINS & PUBLICATION LMD',
          detail: workspace.published
              ? 'Parcours de démonstration terminé · aucune diffusion réelle'
              : missing > 0
                  ? '$missing dossier(s) incomplet(s) · publication bloquée'
                  : 'Cohorte complète · contrôle préalable requis',
          color: workspace.published ? valid : pending,
        ),
        const SizedBox(height: 20),
        CelluleColumns(
          breakpoint: 1050,
          flex: const [4, 6],
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CellulePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PublicationPanelTitle(
                        icon: Icons.tune,
                        title: 'Cohorte & Session d’examen',
                      ),
                      const SizedBox(height: 18),
                      const _PublicationField(
                        label: 'FILIÈRE & NIVEAU',
                        value: 'Licence 3 · Informatique',
                      ),
                      const SizedBox(height: 12),
                      const _PublicationField(
                        label: 'PÉRIODE ACADÉMIQUE',
                        value: 'Semestre 5 · 2024–2025',
                      ),
                      const SizedBox(height: 12),
                      const _PublicationField(
                        label: 'SESSION D’EXAMEN',
                        value: 'Session normale (SN)',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.groups_outlined, color: red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${workspace.students.length} étudiants · '
                              '$completed dossiers complets',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: workspace.students.isEmpty
                            ? 0
                            : completed / workspace.students.length,
                        color: allComplete ? valid : gold,
                        backgroundColor: paper,
                        minHeight: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                CellulePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PublicationEyebrow('PROTOCOLE DE DÉMONSTRATION'),
                      const SizedBox(height: 5),
                      const _PublicationPanelTitle(
                        icon: Icons.fact_check_outlined,
                        title: 'Cycle de vérification',
                      ),
                      const SizedBox(height: 18),
                      _PublicationStep(
                        number: 1,
                        title: 'Brouillon technique LMD',
                        detail:
                            'Recalcul des résultats UE, crédits et MGP du semestre.',
                        done: workspace.calculated,
                        action: OutlinedButton.icon(
                          onPressed: () {
                            workspace.calculate();
                            celluleNotice(
                              context,
                              'Résultats recalculés. Les dossiers incomplets '
                              'restent signalés avant toute validation.',
                            );
                          },
                          icon: const Icon(Icons.calculate_outlined, size: 16),
                          label: Text(workspace.calculated
                              ? 'Recalculer les résultats'
                              : 'Calculer les résultats'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PublicationStep(
                        number: 2,
                        title: 'Vérification de la cohorte',
                        detail: allComplete
                            ? 'Contrôle local de complétude. Aucun visa décanal '
                                'ni signature numérique ne sont apposés.'
                            : '$missing dossier(s) à compléter dans Numérisation '
                                'avant de valider le lot.',
                        done: workspace.validated,
                        action: OutlinedButton.icon(
                          onPressed: allComplete && workspace.calculated
                              ? () {
                                  final success =
                                      workspace.validatePublication();
                                  celluleNotice(
                                    context,
                                    success
                                        ? 'Cohorte vérifiée pour la démonstration. '
                                            'La publication reste une étape distincte.'
                                        : 'Le calcul et la complétude sont requis.',
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.checklist, size: 16),
                          label: Text(workspace.validated
                              ? 'Cohorte vérifiée'
                              : 'Vérifier la cohorte'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PublicationStep(
                        number: 3,
                        title: 'Publication portails & affichage',
                        detail: workspace.published
                            ? 'Simulation enregistrée dans le journal local. '
                                'Aucune diffusion réelle.'
                            : 'Après vérification, tester la dernière étape '
                                'avec les canaux choisis ci-dessous.',
                        done: workspace.published,
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      const _PublicationEyebrow('CANAUX DE PUBLICATION · DÉMO'),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Portail étudiant en ligne',
                            style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Consultation dans l’espace personnel',
                            style: TextStyle(fontSize: 11)),
                        activeTrackColor: valid,
                        value: _studentPortal,
                        onChanged: (value) =>
                            setState(() => _studentPortal = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Affichage au panneau décanal',
                            style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Préparation des listes imprimées',
                            style: TextStyle(fontSize: 11)),
                        activeTrackColor: valid,
                        value: _noticeBoard,
                        onChanged: (value) =>
                            setState(() => _noticeBoard = value),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 18),
                        ),
                        onPressed: workspace.validated &&
                                allComplete &&
                                (_studentPortal || _noticeBoard) &&
                                !workspace.published
                            ? () => _confirmPublication(workspace)
                            : null,
                        icon: const Icon(Icons.campaign_outlined, size: 19),
                        label: Text(workspace.published
                            ? 'Publication simulée'
                            : 'Simuler la publication'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Démonstration locale · aucun envoi, aucun scellage, '
                        'aucune signature.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: slate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                CellulePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PublicationEyebrow('OPÉRATIONS EN MASSE'),
                      const SizedBox(height: 5),
                      const _PublicationPanelTitle(
                        icon: Icons.print_outlined,
                        title: 'Génération des documents',
                      ),
                      const SizedBox(height: 16),
                      _PublicationDocumentAction(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Générer les ${workspace.students.length} bulletins',
                        detail: 'Lot PDF · génération simulée',
                        dark: true,
                        onPressed: () => celluleDemoNotice(
                            context, 'La génération des bulletins PDF'),
                      ),
                      const SizedBox(height: 10),
                      _PublicationDocumentAction(
                        icon: Icons.description_outlined,
                        title: 'Procès-verbal de la cohorte',
                        detail: 'Spécimen · sans signatures',
                        onPressed: () => celluleDemoNotice(
                            context, 'L’export du procès-verbal'),
                      ),
                      const SizedBox(height: 18),
                      _PublicationStudentPicker(workspace: workspace),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CellulePanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      const _PublicationPanelTitle(
                        icon: Icons.article_outlined,
                        title: 'Spécimen du bulletin',
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            workspace.openSection(CelluleSection.bulletin),
                        icon: const Icon(Icons.open_in_full, size: 15),
                        label: const Text('Ouvrir l’aperçu'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _PublicationBulletinSheet(
                  workspace: workspace,
                  student: workspace.selectedStudent,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        CelluleColumns(
          flex: const [6, 4],
          children: [
            _PublicationArchives(workspace: workspace),
            _PublicationJournal(workspace: workspace),
          ],
        ),
      ],
    );
  }
}

class CelluleBulletinContent extends StatefulWidget {
  const CelluleBulletinContent({super.key});

  @override
  State<CelluleBulletinContent> createState() => _CelluleBulletinContentState();
}

class _CelluleBulletinContentState extends State<CelluleBulletinContent> {
  bool _bilingual = true;
  bool _watermark = true;
  bool _gradeScale = false;
  bool _signatureZones = true;
  String _period = 's5';

  @override
  Widget build(BuildContext context) {
    final workspace = CelluleScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CelluleHeading(
          eyebrow: 'REGISTRE DES RELEVÉS · SPÉCIMEN',
          title: 'Prévisualisation du bulletin',
          subtitle:
              'Paramètres d’édition et aperçu du relevé individuel de notes.',
          actions: [
            OutlinedButton.icon(
              onPressed: () =>
                  workspace.openSection(CelluleSection.publications),
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('Publications'),
            ),
            FilledButton.icon(
              onPressed: _period == 's5'
                  ? () => celluleDemoNotice(context, 'L’impression du bulletin')
                  : null,
              icon: const Icon(Icons.print_outlined, size: 17),
              label: const Text('Impression · démo'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _PublicationStatusStrip(
          title: 'APERÇU D’ÉDITION · SPÉCIMEN NON SIGNÉ',
          detail:
              'Résultats provisoires · aucune authentification décanale',
          color: gold,
        ),
        const SizedBox(height: 20),
        CelluleColumns(
          breakpoint: 1050,
          flex: const [3, 7],
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CellulePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PublicationPanelTitle(
                        icon: Icons.description_outlined,
                        title: 'Statut du document',
                      ),
                      const SizedBox(height: 16),
                      const CelluleBadge(
                          label: 'SPÉCIMEN · DÉMONSTRATION', color: gold),
                      const SizedBox(height: 14),
                      _PublicationField(
                        label: 'RÉFÉRENCE DE L’APERÇU',
                        value:
                            'DEMO-S5-${workspace.selectedStudent.matricule}',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ce document n’est ni signé ni scellé. '
                        'Les fonctions PDF, impression et certification '
                        'sont simulées.',
                        style: TextStyle(fontSize: 12, color: slate, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                CellulePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PublicationPanelTitle(
                        icon: Icons.tune,
                        title: 'Paramètres d’édition',
                      ),
                      const SizedBox(height: 18),
                      const _PublicationEyebrow('PÉRIODE ACADÉMIQUE'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _period,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 's5', child: Text('Semestre 5')),
                          DropdownMenuItem(
                              value: 's6', child: Text('Semestre 6 · à charger')),
                          DropdownMenuItem(
                              value: 'year', child: Text('Bilan annuel · à charger')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _period = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      const _PublicationEyebrow('PROTOCOLE LINGUISTIQUE'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Bilingue FR / EN'),
                            selected: _bilingual,
                            onSelected: (_) =>
                                setState(() => _bilingual = true),
                          ),
                          ChoiceChip(
                            label: const Text('Français seul'),
                            selected: !_bilingual,
                            onSelected: (_) =>
                                setState(() => _bilingual = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _PublicationEyebrow('PRÉSENTATION DU RELEVÉ'),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        activeColor: red,
                        title: const Text('Filigrane « SPÉCIMEN »'),
                        value: _watermark,
                        onChanged: (value) =>
                            setState(() => _watermark = value ?? true),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        activeColor: red,
                        title: const Text('Grille de conversion des grades'),
                        value: _gradeScale,
                        onChanged: (value) =>
                            setState(() => _gradeScale = value ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        activeColor: red,
                        title: const Text('Emplacements des visas'),
                        value: _signatureZones,
                        onChanged: (value) =>
                            setState(() => _signatureZones = value ?? true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                CellulePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PublicationStudentPicker(workspace: workspace),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style:
                            FilledButton.styleFrom(backgroundColor: red),
                        onPressed: _period == 's5'
                            ? () => celluleDemoNotice(
                                context, 'L’impression au format A4')
                            : null,
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Imprimer A4 · démo'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _period == 's5'
                            ? () => celluleDemoNotice(
                                context, 'L’export du bulletin PDF')
                            : null,
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            size: 18),
                        label: const Text('Exporter PDF · démo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_period == 's5')
                  _PublicationBulletinSheet(
                    workspace: workspace,
                    student: workspace.selectedStudent,
                    bilingual: _bilingual,
                    watermark: _watermark,
                    gradeScale: _gradeScale,
                    signatureZones: _signatureZones,
                  )
                else
                  CellulePanel(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.folder_open_outlined,
                            size: 48, color: gold),
                        const SizedBox(height: 18),
                        Text(
                          _period == 'year'
                              ? 'Bilan annuel indisponible'
                              : 'Semestre 6 non chargé',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 22,
                              color: ink),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cette démonstration contient uniquement les résultats '
                          'du semestre 5. Les deux semestres sont nécessaires '
                          'pour préparer un bilan annuel et examiner l’admission.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: slate, height: 1.5),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton(
                          onPressed: () => setState(() => _period = 's5'),
                          child: const Text('Afficher le semestre 5'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'GNU · Relevé de démonstration · Sans valeur administrative',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: slate),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _PublicationBulletinSheet extends StatelessWidget {
  final CelluleWorkspace workspace;
  final CelluleStudent student;
  final bool bilingual;
  final bool watermark;
  final bool gradeScale;
  final bool signatureZones;

  const _PublicationBulletinSheet({
    required this.workspace,
    required this.student,
    this.bilingual = false,
    this.watermark = true,
    this.gradeScale = false,
    this.signatureZones = true,
  });

  @override
  Widget build(BuildContext context) {
    final result = workspace.result(student);
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 520;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5EC),
          border: Border.all(color: ink.withValues(alpha: .1)),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: .1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (watermark)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Center(
                      child: Transform.rotate(
                        angle: -.42,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'SPÉCIMEN',
                            style: TextStyle(
                              color: red.withValues(alpha: .055),
                              fontFamily: 'Fraunces',
                              fontWeight: FontWeight.w800,
                              fontSize: 105,
                              letterSpacing: 5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(narrow ? 18 : 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PublicationDocumentHeader(bilingual: bilingual),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    color: red,
                    child: Column(
                      children: [
                        Text(
                          bilingual
                              ? 'RELEVÉ DE NOTES & RÉSULTATS'
                              : 'BULLETIN INDIVIDUEL DE NOTES',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Fraunces',
                            fontSize: narrow ? 19 : 23,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bilingual
                              ? 'ACADEMIC TRANSCRIPT · SEMESTER 5'
                              : 'RÉSULTATS PROVISOIRES DU SEMESTRE 5',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    color: paper.withValues(alpha: .55),
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 18,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _PublicationIdentity(
                          label: bilingual ? 'NOM / NAME' : 'NOM & PRÉNOMS',
                          value: student.name,
                          width: narrow ? constraints.maxWidth - 72 : 240,
                        ),
                        _PublicationIdentity(
                          label: bilingual
                              ? 'MATRICULE / STUDENT ID'
                              : 'MATRICULE ÉTUDIANT',
                          value: student.matricule,
                          color: red,
                          width: 170,
                        ),
                        const _PublicationIdentity(
                          label: 'FILIÈRE & CYCLE',
                          value: 'Licence 3 · Informatique',
                          width: 240,
                        ),
                        const _PublicationIdentity(
                          label: 'ANNÉE ACADÉMIQUE',
                          value: '2024–2025 · Session normale',
                          width: 220,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PublicationNotesTable(
                      workspace: workspace, student: student),
                  const SizedBox(height: 10),
                  const Text(
                    'Résultats UE arrondis sur 100 · Grades et points LMD. '
                    'EL : absence au rattrapage. Une note manquante n’est pas un zéro.',
                    style: TextStyle(fontSize: 10, color: slate, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(builder: (context, metricConstraints) {
                    final columns = metricConstraints.maxWidth >= 600 ? 4 : 2;
                    final width =
                        (metricConstraints.maxWidth - (columns - 1) * 10) /
                            columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _PublicationPaperMetric(
                            label: 'CRÉDITS ACQUIS',
                            value:
                                '${result.acquiredCredits} / ${result.totalCredits}',
                            detail: 'Capitalisation des UE',
                            color: valid,
                            width: width),
                        _PublicationPaperMetric(
                            label: 'MGP SEMESTRIELLE',
                            value: result.mgp?.toStringAsFixed(2) ?? '—',
                            detail: result.complete
                                ? 'Sur 4,00 · pondérée'
                                : 'Saisie incomplète',
                            color: red,
                            width: width),
                        _PublicationPaperMetric(
                            label: 'POINTS × CRÉDITS',
                            value: result.complete
                                ? result.pointsCredits.toStringAsFixed(1)
                                : '—',
                            detail: '${result.totalCredits} crédits prévus',
                            color: ink,
                            width: width),
                        _PublicationPaperMetric(
                            label: 'BILAN DU SEMESTRE',
                            value: result.complete ? 'Provisoire' : 'Incomplet',
                            detail: 'Admission annuelle à examiner',
                            color: gold,
                            width: width),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: .075),
                      border: const Border(left: BorderSide(color: gold, width: 3)),
                    ),
                    child: Text(
                      '${result.belowThreshold ? 'Alerte : au moins une UE est sous '
                          '35/100 (7/20). ' : ''}'
                      '${result.hasEl ? 'Une absence au rattrapage (EL) est signalée. ' : ''}'
                      'La décision d’admission annuelle nécessite les deux semestres '
                      'et la délibération du jury. Elle n’est pas prononcée sur cet aperçu.',
                      style:
                          const TextStyle(fontSize: 11, color: ink, height: 1.5),
                    ),
                  ),
                  if (gradeScale) ...[
                    const SizedBox(height: 20),
                    const _PublicationEyebrow('GRILLE DE CONVERSION LMD · /100'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final score in [80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30, 0])
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            color: paper.withValues(alpha: .55),
                            child: Text(
                              '≥ $score : ${GradeResult.gradeForScore(score)} '
                              '(${GradeResult.pointsForScore(score)!.toStringAsFixed(1)})',
                              style: const TextStyle(fontSize: 10, color: ink),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (signatureZones) ...[
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 14,
                      runSpacing: 18,
                      children: const [
                        _PublicationVisa(
                          title: 'AUTHENTIFICATION',
                          icon: Icons.qr_code_2,
                          detail: 'Emplacement réservé\nAucun code de vérification',
                        ),
                        _PublicationVisa(
                          title: 'LE PRÉSIDENT DU JURY',
                          icon: Icons.draw_outlined,
                          detail: 'Signature non apposée\nSpécimen',
                        ),
                        _PublicationVisa(
                          title: 'LE DOYEN DE LA FACULTÉ',
                          icon: Icons.workspace_premium_outlined,
                          detail: 'Sceau non apposé\nSpécimen',
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'SPÉCIMEN · DÉMONSTRATION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: red,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ce relevé de démonstration est sans valeur administrative. '
                    'Il ne constitue ni une publication officielle ni une décision de jury.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: slate, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PublicationNotesTable extends StatelessWidget {
  final CelluleWorkspace workspace;
  final CelluleStudent student;
  const _PublicationNotesTable({required this.workspace, required this.student});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 640 ? 640 : constraints.maxWidth,
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(62),
                1: FlexColumnWidth(3),
                2: FixedColumnWidth(55),
                3: FixedColumnWidth(63),
                4: FixedColumnWidth(53),
                5: FixedColumnWidth(51),
                6: FixedColumnWidth(82),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: ink),
                  children: [
                    _PublicationTableCell('CODE\nUE', header: true),
                    _PublicationTableCell('INTITULÉ DE L’UNITÉ\nD’ENSEIGNEMENT',
                        header: true),
                    _PublicationTableCell('CRÉDITS', header: true),
                    _PublicationTableCell('TOTAL\n/100', header: true),
                    _PublicationTableCell('GRADE', header: true),
                    _PublicationTableCell('POINTS', header: true),
                    _PublicationTableCell('ÉTAT UE', header: true),
                  ],
                ),
                for (var i = 0; i < workspace.courses.length; i++)
                  _row(workspace.courses[i], i),
              ],
            ),
          ),
        ),
      );

  TableRow _row(CelluleCourse course, int index) {
    final score = student.scores[course.code];
    final eliminated = student.eliminated.contains(course.code);
    final acquired = !eliminated && score != null && score >= 50;
    final state = eliminated
        ? 'EL'
        : score == null
            ? 'Manquante'
            : acquired
                ? 'Acquise'
                : score < 35
                    ? 'Sous 35'
                    : 'Non acquise';
    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven
            ? paper.withValues(alpha: .45)
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: ink.withValues(alpha: .08))),
      ),
      children: [
        _PublicationTableCell(course.code, color: red, bold: true),
        _PublicationTableCell(course.title),
        _PublicationTableCell('${course.credits}'),
        _PublicationTableCell(eliminated ? '—' : score?.toString() ?? '—',
            bold: true),
        _PublicationTableCell(
            eliminated ? 'EL' : GradeResult.gradeForScore(score) ?? '—',
            color: acquired ? valid : red),
        _PublicationTableCell(eliminated
            ? '0.0'
            : GradeResult.pointsForScore(score)?.toStringAsFixed(1) ?? '—'),
        _PublicationTableCell(state,
            color: acquired ? valid : score == null ? gold : red),
      ],
    );
  }
}

class _PublicationDocumentHeader extends StatelessWidget {
  final bool bilingual;
  const _PublicationDocumentHeader({required this.bilingual});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (bilingual)
            LayoutBuilder(builder: (context, constraints) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 520
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 80) / 2,
                    child: const _PublicationRepublic(english: false),
                  ),
                  if (constraints.maxWidth >= 520)
                    Image.asset('assets/logo_gnu.png', width: 52, height: 56),
                  SizedBox(
                    width: constraints.maxWidth < 520
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 80) / 2,
                    child: const _PublicationRepublic(english: true),
                  ),
                ],
              );
            })
          else ...[
            const Text(
              'RÉPUBLIQUE DU CAMEROUN · PAIX – TRAVAIL – PATRIE',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9, letterSpacing: .8),
            ),
            const SizedBox(height: 10),
            const Text(
              'UNIVERSITÉ DE DOUALA',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 26,
                  color: red,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            const Text(
              'FACULTÉ DES SCIENCES\nDÉPARTEMENT D’INFORMATIQUE',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  color: ink,
                  height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'SYSTÈME LMD · LICENCE – MASTER – DOCTORAT',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                letterSpacing: .8,
                color: slate),
          ),
        ],
      );
}

class _PublicationRepublic extends StatelessWidget {
  final bool english;
  const _PublicationRepublic({required this.english});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            english ? 'REPUBLIC OF CAMEROON' : 'RÉPUBLIQUE DU CAMEROUN',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: ink),
          ),
          const SizedBox(height: 5),
          Text(
            english ? 'Peace – Work – Fatherland' : 'Paix – Travail – Patrie',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                color: slate,
                fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            english ? 'UNIVERSITY OF DOUALA' : 'UNIVERSITÉ DE DOUALA',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            english
                ? 'Faculty of Science\nDepartment of Computer Science'
                : 'Faculté des Sciences\nDépartement d’Informatique',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Fraunces', fontSize: 11, color: red, height: 1.4),
          ),
        ],
      );
}

class _PublicationStudentPicker extends StatelessWidget {
  final CelluleWorkspace workspace;
  const _PublicationStudentPicker({required this.workspace});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PublicationEyebrow('APERÇU ÉTUDIANT'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey('bulletin-student-${workspace.selectedStudentIndex}'),
            initialValue: workspace.selectedStudentIndex,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: [
              for (var i = 0; i < workspace.students.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    workspace.students[i].name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            onChanged: (index) {
              if (index != null) workspace.selectStudent(index);
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Étudiant précédent',
                onPressed: workspace.selectedStudentIndex > 0
                    ? () => workspace
                        .selectStudent(workspace.selectedStudentIndex - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${workspace.selectedStudentIndex + 1} / '
                '${workspace.students.length}',
                style: const TextStyle(
                    color: red, fontFamily: 'monospace', fontSize: 12),
              ),
              IconButton(
                tooltip: 'Étudiant suivant',
                onPressed: workspace.selectedStudentIndex <
                        workspace.students.length - 1
                    ? () => workspace
                        .selectStudent(workspace.selectedStudentIndex + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
}

class _PublicationArchives extends StatelessWidget {
  final CelluleWorkspace workspace;
  const _PublicationArchives({required this.workspace});
  @override
  Widget build(BuildContext context) => CellulePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PublicationPanelTitle(
                icon: Icons.folder_copy_outlined,
                title: 'Procès-verbaux & Registre des documents'),
            const SizedBox(height: 6),
            const Text('Exemples du registre · aucun fichier officiel archivé',
                style: TextStyle(fontSize: 11, color: slate)),
            const SizedBox(height: 16),
            _PublicationDocumentAction(
              icon: Icons.article_outlined,
              title: 'Bulletin · ${workspace.selectedStudent.matricule}',
              detail: '${workspace.selectedStudent.name} · Spécimen S5',
              onPressed: () => workspace.openSection(CelluleSection.bulletin),
            ),
            const SizedBox(height: 10),
            _PublicationDocumentAction(
              icon: Icons.picture_as_pdf_outlined,
              title: 'PV — L3 Informatique — Semestre 5',
              detail:
                  '${workspace.students.length} dossiers · export de démonstration',
              onPressed: () =>
                  celluleDemoNotice(context, 'L’archivage du procès-verbal'),
            ),
            const SizedBox(height: 10),
            const _PublicationDocumentAction(
              icon: Icons.event_note_outlined,
              title: 'Bilan annuel de la promotion',
              detail: 'Indisponible · semestre 6 non chargé',
            ),
          ],
        ),
      );
}

class _PublicationJournal extends StatelessWidget {
  final CelluleWorkspace workspace;
  const _PublicationJournal({required this.workspace});
  @override
  Widget build(BuildContext context) => CellulePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PublicationPanelTitle(
                icon: Icons.history,
                title: 'Journal d’activité & Traçabilité'),
            const SizedBox(height: 6),
            const Text('Activité de démonstration · session courante',
                style: TextStyle(fontSize: 11, color: slate)),
            const SizedBox(height: 16),
            if (workspace.events.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: paper.withValues(alpha: .5),
                child: const Text(
                  'Les calculs, vérifications et simulations apparaîtront ici.',
                  style: TextStyle(fontSize: 12, color: slate, height: 1.5),
                ),
              )
            else
              for (final event in workspace.events.take(5))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  color: paper.withValues(alpha: .5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 7, color: valid),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(event,
                            style: const TextStyle(
                                fontSize: 11, color: ink, height: 1.5)),
                      ),
                    ],
                  ),
                ),
            if (workspace.events.length > 5)
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Journal de démonstration'),
                    content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                        child: Text(workspace.events.join('\n\n'),
                            style: const TextStyle(fontSize: 13, height: 1.5)),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                ),
                child: Text('Afficher les ${workspace.events.length} opérations'),
              ),
          ],
        ),
      );
}

class _PublicationStatusStrip extends StatelessWidget {
  final String title, detail;
  final Color color;
  const _PublicationStatusStrip(
      {required this.title, required this.detail, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: paperLight,
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title,
                style: TextStyle(
                    color: color,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w600)),
            Text(detail,
                style: const TextStyle(color: slate, fontSize: 12)),
          ],
        ),
      );
}

class _PublicationPanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _PublicationPanelTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: red),
          const SizedBox(width: 8),
          Flexible(
            child: Text(title,
                style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 18,
                    color: ink,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      );
}

class _PublicationEyebrow extends StatelessWidget {
  final String text;
  const _PublicationEyebrow(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: slate,
          fontFamily: 'monospace',
          fontSize: 10,
          letterSpacing: .9,
          height: 1.4));
}

class _PublicationField extends StatelessWidget {
  final String label, value;
  const _PublicationField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PublicationEyebrow(label),
          const SizedBox(height: 5),
          Container(
            color: paper.withValues(alpha: .6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: ink,
                    fontFamily: 'monospace',
                    height: 1.4)),
          ),
        ],
      );
}

class _PublicationStep extends StatelessWidget {
  final int number;
  final String title, detail;
  final bool done;
  final Widget? action;
  const _PublicationStep(
      {required this.number,
      required this.title,
      required this.detail,
      required this.done,
      this.action});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: done
              ? valid.withValues(alpha: .07)
              : paper.withValues(alpha: .45),
          border: Border(
              left: BorderSide(color: done ? valid : gold, width: 2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: done ? valid : gold.withValues(alpha: .15),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text('$number',
                      style: const TextStyle(
                          fontSize: 12,
                          color: gold,
                          fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Fraunces', fontSize: 15, color: ink)),
                  const SizedBox(height: 6),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 11, color: slate, height: 1.5)),
                  if (action != null) ...[
                    const SizedBox(height: 10),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _PublicationDocumentAction extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  final bool dark;
  final VoidCallback? onPressed;
  const _PublicationDocumentAction({
    required this.icon,
    required this.title,
    required this.detail,
    this.dark = false,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Material(
        color: dark ? ink : paper.withValues(alpha: .65),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 23, color: dark ? Colors.white : red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: dark ? Colors.white : ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(detail,
                          style: TextStyle(
                              color: dark
                                  ? Colors.white.withValues(alpha: .8)
                                  : slate,
                              fontSize: 10,
                              height: 1.4)),
                    ],
                  ),
                ),
                if (onPressed != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      size: 18, color: dark ? Colors.white : slate),
                ],
              ],
            ),
          ),
        ),
      );
}

class _PublicationIdentity extends StatelessWidget {
  final String label, value;
  final double width;
  final Color color;
  const _PublicationIdentity(
      {required this.label,
      required this.value,
      required this.width,
      this.color = ink});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PublicationEyebrow(label),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontFamily: 'Fraunces',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3)),
          ],
        ),
      );
}

class _PublicationTableCell extends StatelessWidget {
  final String text;
  final bool header, bold;
  final Color color;
  const _PublicationTableCell(this.text,
      {this.header = false, this.bold = false, this.color = ink});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 7, vertical: header ? 13 : 14),
        child: Text(text,
            style: TextStyle(
                fontFamily: header ? 'monospace' : null,
                fontSize: header ? 9 : 11,
                fontWeight:
                    header || bold ? FontWeight.w600 : FontWeight.normal,
                height: 1.4,
                color: header ? Colors.white : color)),
      );
}

class _PublicationPaperMetric extends StatelessWidget {
  final String label, value, detail;
  final Color color;
  final double width;
  const _PublicationPaperMetric(
      {required this.label,
      required this.value,
      required this.detail,
      required this.color,
      required this.width});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(12),
        color: paper.withValues(alpha: .45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: slate,
                    letterSpacing: .5)),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 24,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 7),
            Text(detail,
                style:
                    const TextStyle(fontSize: 10, color: slate, height: 1.3)),
          ],
        ),
      );
}

class _PublicationVisa extends StatelessWidget {
  final String title, detail;
  final IconData icon;
  const _PublicationVisa(
      {required this.title, required this.icon, required this.detail});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 155,
        child: Column(
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 9, color: slate)),
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: .45)),
              ),
              child: Icon(icon, size: 26, color: gold.withValues(alpha: .7)),
            ),
            const SizedBox(height: 9),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: slate, height: 1.5)),
          ],
        ),
      );
}
