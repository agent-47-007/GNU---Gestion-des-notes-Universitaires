import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'domain.dart';
import 'ui.dart';
import 'dialogs.dart';

class FeaturePage extends StatefulWidget {
  const FeaturePage({
    super.key,
    required this.page,
    required this.role,
    required this.store,
  });
  final String page;
  final UserRole role;
  final DemoStore store;
  @override
  State<FeaturePage> createState() => _FeaturePageState();
}

class _FeaturePageState extends State<FeaturePage> {
  String query = '', filter = 'Toutes', semester = 'Semestre 1';
  DemoStore get store => widget.store;
  bool get student => widget.role == UserRole.student;
  @override
  Widget build(BuildContext context) => switch (widget.page) {
    'results' => results(),
    'guide' => guide(),
    'profile' => profile(),
    'classes' => classes(),
    'enrollment' => enrollment(),
    'requests' => requests(),
    'grades' => grades(),
    'evaluations' => evaluations(),
    'retakes' => retakes(),
    'academic' => academic(),
    'accounts' => accounts(),
    'publications' => publications(),
    'bulletins' => bulletins(),
    'audit' => audit(),
    _ => const EmptyState(
      'Espace introuvable',
      'Choisissez une rubrique dans le menu.',
    ),
  };

  Future<void> exportText(String filename, String text) async {
    try {
      await FilePicker.platform.saveFile(
        fileName: filename,
        bytes: Uint8List.fromList(utf8.encode(text)),
        type: FileType.custom,
        allowedExtensions: [filename.split('.').last],
      );
    } catch (_) {
      if (mounted)
        toast(
          context,
          'Le téléchargement n’a pas abouti. Réessayez depuis votre navigateur.',
        );
    }
  }

  Widget searchBox(String hint) => TextField(
    onChanged: (text) => setState(() => query = text),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search, size: 20),
    ),
  );
  bool matches(String text) =>
      text.toLowerCase().contains(query.trim().toLowerCase());
  Widget stack(List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  Widget table(List<String> headings, List<List<Widget>> rows) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(canvas),
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
          dataTextStyle: const TextStyle(fontSize: 13, color: navy),
          horizontalMargin: 16,
          columnSpacing: 28,
          dataRowMinHeight: 66,
          dataRowMaxHeight: 88,
          columns: headings
              .map((title) => DataColumn(label: Text(title)))
              .toList(),
          rows: rows
              .map(
                (row) =>
                    DataRow(cells: row.map((cell) => DataCell(cell)).toList()),
              )
              .toList(),
        ),
      ),
    ),
  );

  Widget results() {
    final isFirst = semester == 'Semestre 1';
    final available = isFirst || store.publicationVersion > 0;
    final courses = (isFirst ? store.courses : store.courses.take(1))
        .where((c) => matches('${c.code} ${c.title}'))
        .toList();
    return stack([
      PageHeading(
        'Notes & bulletins',
        'Consultez uniquement les résultats publiés de votre parcours.',
        action: OutlinedButton.icon(
          onPressed: !available
              ? null
              : () => exportText(
                  'gnu-releve-demo.csv',
                  'DOCUMENT DE DEMONSTRATION - SANS VALEUR OFFICIELLE\nEtudiant;Alex Mouna\nPeriode;$semester\nCode;UE;Note sur 100\n${(isFirst ? store.courses : store.courses.take(1)).map((c) => '${c.code};${c.title};${isFirst ? c.score : store.publishedScores.first * 5}').join('\n')}',
                ),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Exporter le relevé démo'),
        ),
      ),
      const Notice(
        'Les résultats présentés sont fictifs. L’export CSV est un aperçu, pas un bulletin officiel.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: ['Semestre 1', 'Semestre 2']
            .map(
              (label) => ChoiceChip(
                label: Text(label),
                selected: semester == label,
                onSelected: (_) => setState(() => semester = label),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      if (!available)
        const Panel(
          child: EmptyState(
            'Résultats non publiés',
            'Le semestre 2 sera visible après validation, transmission et publication du registre de démonstration.',
          ),
        )
      else
        Panel(
          child: stack([
            SectionTitle(
              isFirst
                  ? 'Relevé du semestre 1'
                  : 'Publication · version ${store.publicationVersion}',
              subtitle: isFirst
                  ? 'Informatique · Licence 2 · 30 crédits'
                  : 'Périmètre de démonstration : INF 201 uniquement',
            ),
            searchBox('Rechercher une unité d’enseignement'),
            const SizedBox(height: 20),
            if (courses.isEmpty)
              const EmptyState(
                'Aucun résultat',
                'Essayez un autre code ou intitulé.',
              )
            else
              table(
                [
                  'CODE',
                  'UNITÉ D’ENSEIGNEMENT',
                  'CRÉDITS',
                  'NOTE / 100',
                  'RÉSULTAT',
                ],
                courses.map((c) {
                  final score = isFirst
                      ? c.score!
                      : store.publishedScores.first * 5;
                  return [
                    Text(c.code),
                    SizedBox(width: 230, child: Text(c.title)),
                    Text('${c.credits}'),
                    Text(
                      score.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    StatusBadge(
                      score >= 50 ? 'Acquise' : 'À reprendre',
                      color: score >= 50 ? emerald : const Color(0xFFA26917),
                    ),
                  ];
                }).toList(),
              ),
          ]),
        ),
    ]);
  }

  Widget enrollment() => stack([
    PageHeading(
      student ? 'Mon inscription pédagogique' : 'Suivi des inscriptions',
      'Licence 2 · Informatique · Semestre 2',
    ),
    if (!student) ...[
      Panel(
        child: stack([
          const SectionTitle('Demandes à vérifier'),
          if (!store.enrollmentSubmitted)
            const EmptyState(
              'Aucune inscription en attente',
              'Soumettez les choix pédagogiques depuis l’espace étudiant pour tester ce parcours.',
            )
          else ...[
            const Text(
              'Alex Mouna · 24I001',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${store.selectedCourses.length} UE sélectionnées · ${store.selectedCredits} crédits',
            ),
            const SizedBox(height: 16),
            ...store.courses
                .where((c) => store.selectedCourses.contains(c.code))
                .map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.title),
                    subtitle: Text(c.code),
                    trailing: Text('${c.credits} crédits'),
                  ),
                ),
            const SizedBox(height: 16),
            if (store.enrollmentApproved)
              const StatusBadge('Inscription vérifiée')
            else
              FilledButton(
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Vérifier cette inscription ?',
                    'Confirmer les choix pédagogiques de cet étudiant dans la démonstration.',
                  ))
                    store.approveEnrollment();
                },
                child: const Text('Valider l’inscription'),
              ),
          ],
        ]),
      ),
    ] else ...[
      Notice(
        store.enrollmentApproved
            ? 'Votre inscription a été vérifiée par la cellule informatique.'
            : store.enrollmentSubmitted
            ? 'Vos choix ont été transmis. Ils sont en attente de vérification.'
            : 'Vérifiez vos UE obligatoires et choisissez votre UE optionnelle avant de soumettre.',
      ),
      ResponsiveSplit(
        main: Panel(
          child: stack([
            const SectionTitle(
              'Mes unités d’enseignement',
              subtitle: 'Les UE obligatoires sont présélectionnées.',
            ),
            ...store.courses.map(
              (c) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: store.selectedCourses.contains(c.code),
                onChanged: c.required || store.enrollmentSubmitted
                    ? null
                    : (value) => store.selectCourse(c, value ?? false),
                title: Text(
                  c.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${c.code} · ${c.credits} crédits · ${c.required ? 'Obligatoire' : 'Optionnelle'}',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ),
            const Divider(),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event_repeat, color: Color(0xFFA26917)),
              title: Text('UE à reprendre : MAT 201'),
              subtitle: Text(
                'Incluse dans votre sélection obligatoire de démonstration.',
              ),
            ),
          ]),
        ),
        aside: Panel(
          child: stack([
            const SectionTitle('Mon récapitulatif'),
            Text(
              '${store.selectedCredits}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const Text('crédits sélectionnés', style: TextStyle(color: muted)),
            const SizedBox(height: 20),
            Text('${store.selectedCourses.length} unités d’enseignement'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: store.enrollmentSubmitted
                    ? null
                    : () async {
                        if (await confirm(
                          context,
                          'Soumettre mes choix ?',
                          'Vous avez sélectionné ${store.selectedCourses.length} UE pour ${store.selectedCredits} crédits. Les choix seront verrouillés dans cette session.',
                        ))
                          store.submitEnrollment();
                      },
                child: Text(
                  store.enrollmentSubmitted
                      ? 'Choix transmis'
                      : 'Soumettre mes choix',
                ),
              ),
            ),
          ]),
        ),
      ),
    ],
  ]);

  Widget requests() {
    final visible = store.requests
        .where(
          (r) =>
              (student || r.course == 'INF 201') &&
              (filter == 'Toutes' || r.status == filter) &&
              matches('${r.id} ${r.course} ${r.message}'),
        )
        .toList();
    return stack([
      PageHeading(
        student ? 'Mes requêtes' : 'Requêtes étudiantes',
        student
            ? 'Une demande, une réponse et un suivi transparent.'
            : 'Examinez les demandes concernant votre enseignement INF 201.',
        action: student
            ? FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RequestDialog(store: store),
                ),
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Nouvelle requête'),
              )
            : null,
      ),
      const Notice(
        'Une preuve est obligatoire pour une absence. Les délais de recevabilité et les autorisations seront contrôlés par le serveur.',
        warning: true,
      ),
      Panel(
        child: stack([
          searchBox('Rechercher une requête'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Toutes', 'À examiner', 'Acceptée', 'Rejetée']
                .map(
                  (status) => ChoiceChip(
                    label: Text(status),
                    selected: filter == status,
                    onSelected: (_) => setState(() => filter = status),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          if (visible.isEmpty)
            const EmptyState(
              'Aucune requête',
              'Aucune demande ne correspond à vos filtres.',
            ),
          ...visible.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: stroke),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: stack([
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        request.id,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      StatusBadge(
                        request.status,
                        color: request.status == 'Rejetée'
                            ? Colors.red.shade700
                            : request.status == 'À examiner'
                            ? const Color(0xFFA26917)
                            : emerald,
                      ),
                      Text(
                        request.course,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    request.type,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(request.message),
                  if (request.proofName != null)
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await FilePicker.platform.saveFile(
                            fileName: request.proofName!,
                            bytes: request.proofBytes,
                          );
                        } catch (_) {
                          if (mounted)
                            toast(
                              context,
                              'Impossible de télécharger la pièce jointe.',
                            );
                        }
                      },
                      icon: const Icon(Icons.attach_file, size: 17),
                      label: Text(request.proofName!),
                    ),
                  if (request.decision != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Réponse : ${request.decision}',
                      style: const TextStyle(color: emerald),
                    ),
                  ],
                  if (!student && request.status == 'À examiner') ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            DecisionDialog(store: store, request: request),
                      ),
                      child: const Text('Examiner la demande'),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget markField(int index, bool cc) {
    final row = store.marks[index];
    final raw = cc ? row.cc : row.exam;
    final invalid = raw.isNotEmpty && DemoStore.parseMark(raw) == null;
    return SizedBox(
      width: 104,
      child: TextFormField(
        key: ValueKey('${row.id}-$cc'),
        initialValue: raw,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) => store.changeMark(index, cc, value),
        decoration: InputDecoration(
          labelText: cc ? 'CC / 20' : 'Examen / 20',
          hintText: '—',
          errorText: invalid
              ? (raw.toUpperCase() == 'ABS' ? 'À régulariser' : '0 à 20')
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget grades() => stack([
    PageHeading(
      'Saisie des notes',
      'INF 201 · Algorithmique avancée · Licence 2',
      action: StatusBadge(
        store.gradesSubmitted
            ? 'Transmis'
            : store.gradesValidated
            ? 'Validé'
            : 'Brouillon',
        color: store.gradesValidated ? emerald : const Color(0xFFA26917),
      ),
    ),
    Notice(
      store.missingMarks > 0
          ? '${store.missingMarks} note(s) à compléter ou régulariser. Saisissez une valeur de 0 à 20. ABS signale une absence et bloque la validation.'
          : 'Toutes les notes sont renseignées. Contrôlez le registre avant de le transmettre.',
      warning: store.missingMarks > 0,
    ),
    Panel(
      child: stack([
        SectionTitle(
          'Registre des étudiants',
          subtitle:
              'Contrôle continu ${store.ccWeight} % · Examen ${store.examWeight} % · Moyennes indicatives sur 20',
        ),
        table(
          ['MATRICULE', 'ÉTUDIANT', 'CONTRÔLE CONTINU', 'EXAMEN', 'MOYENNE'],
          List.generate(
            store.marks.length,
            (i) => [
              Text(store.marks[i].id),
              Text(store.marks[i].name),
              markField(i, true),
              markField(i, false),
              Text(
                store.total(store.marks[i])?.toStringAsFixed(2) ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: store.gradesValidated || store.missingMarks > 0
                  ? null
                  : () {
                      store.validateGrades();
                      toast(context, 'Registre validé dans cette session.');
                    },
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Valider les notes'),
            ),
            FilledButton.icon(
              onPressed: !store.gradesValidated || store.gradesSubmitted
                  ? null
                  : () async {
                      if (await confirm(
                        context,
                        'Transmettre le registre ?',
                        'Le registre validé sera disponible dans l’espace agent pour publication de démonstration.',
                      ))
                        store.submitGrades();
                    },
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Transmettre le registre'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Enregistrement automatique dans la session. Toute modification annule la validation et la transmission précédentes.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ]),
    ),
  ]);

  Widget evaluations() => stack([
    const PageHeading(
      'Plans d’évaluation',
      'Définissez la répartition des évaluations de votre enseignement.',
    ),
    const Notice(
      'Ce premier parcours couvre un plan CC + examen. Les plans multi-EC, TP et les dérogations individuelles restent à intégrer.',
      warning: true,
    ),
    Panel(
      child: stack([
        const SectionTitle(
          'INF 201 · Algorithmique avancée',
          subtitle: 'Plan de démonstration · Semestre 2',
        ),
        MetricGrid([
          (
            'Contrôle continu',
            '${store.ccWeight} %',
            'Évaluation en cours de semestre',
            Icons.edit_note,
          ),
          (
            'Examen',
            '${store.examWeight} %',
            'Session normale',
            Icons.description_outlined,
          ),
        ]),
        const SizedBox(height: 24),
        const Text('Pondération du contrôle continu'),
        Slider(
          value: store.ccWeight.toDouble(),
          min: 10,
          max: 90,
          divisions: 16,
          label: '${store.ccWeight} %',
          onChanged: (value) => store.changeWeights(value.round()),
        ),
        const Text(
          'Le poids de l’examen est ajusté automatiquement pour un total de 100 %. Une modification nécessite une nouvelle validation des notes.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
      ]),
    ),
  ]);

  Widget retakes() {
    final eligible = store.publicationVersion == 0
        ? <StudentMark>[]
        : List.generate(store.marks.length, (i) => i)
              .where((i) => store.publishedScores[i] < 10)
              .map((i) => store.marks[i])
              .toList();
    return stack([
      const PageHeading(
        'Rattrapages',
        'Consultez la liste publiée et préparez une évaluation autorisée.',
      ),
      const Notice(
        'Éligibilité simplifiée pour cet aperçu : moyenne publiée inférieure à 10/20. Les règles officielles et l’autorisation d’organiser une session doivent venir du serveur.',
        warning: true,
      ),
      Panel(
        child: stack([
          const SectionTitle('INF 201 · Liste de démonstration'),
          if (store.publicationVersion == 0)
            const EmptyState(
              'Liste non publiée',
              'La cellule informatique doit d’abord publier les résultats.',
            )
          else if (eligible.isEmpty)
            const EmptyState(
              'Aucun étudiant à reprendre',
              'Aucune moyenne publiée n’est inférieure au seuil de démonstration.',
            )
          else
            ...eligible.map(
              (row) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: emerald),
                title: Text(row.name),
                subtitle: Text(row.id),
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: eligible.isEmpty
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) => ScheduleDialog(store: store),
                  ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Préparer une évaluation'),
          ),
          ...store.sessions.map(
            (session) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_available_outlined,
                color: emerald,
              ),
              title: Text(session),
              subtitle: const Text(
                'Préparation locale · autorisation non vérifiée',
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget academic() => stack([
    PageHeading(
      'Structure & programmes',
      'Organisez le catalogue pédagogique de votre campus.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => ProgramDialog(store: store),
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Ajouter un programme'),
      ),
    ),
    ResponsiveSplit(
      main: Panel(
        child: stack([
          const SectionTitle('Catalogue des programmes'),
          ...store.programs.map(
            (program) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_tree_outlined, color: emerald),
              title: Text(program),
              subtitle: Text(
                program == store.programs.first
                    ? '${store.courses.length} UE · 30 crédits · Démonstration'
                    : 'Nouveau programme · Brouillon',
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),
          const SectionTitle('UE · Informatique Licence 2'),
          ...store.courses.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.title, style: const TextStyle(fontSize: 14)),
              subtitle: Text(c.code),
              trailing: Text('${c.credits} crédits'),
            ),
          ),
        ]),
      ),
      aside: const Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Structure de référence'),
            Text('Université de démonstration'),
            Divider(height: 28),
            Text('Faculté des sciences'),
            SizedBox(height: 12),
            Text('↳ Département informatique'),
            SizedBox(height: 12),
            Text('    ↳ Filière informatique'),
            SizedBox(height: 12),
            Text('        ↳ Licence 2'),
            SizedBox(height: 24),
            Text(
              'La création détaillée des facultés, EC et versions de programmes sera raccordée au catalogue serveur.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  ]);

  Widget accounts() {
    final visible = store.accounts
        .where((a) => matches('${a.name} ${a.email} ${a.role.label}'))
        .toList();
    return stack([
      PageHeading(
        'Comptes & affectations',
        'Gérez les profils et les responsabilités pédagogiques.',
        action: FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AccountDialog(store: store),
          ),
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('Ajouter un compte'),
        ),
      ),
      const Notice(
        'Les comptes créés ici sont des fiches de démonstration. Aucun identifiant réel ni invitation ne sera envoyé.',
      ),
      Panel(
        child: stack([
          searchBox('Rechercher un nom, une adresse ou un rôle'),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            const EmptyState('Aucun compte trouvé', 'Modifiez votre recherche.')
          else
            table(
              ['UTILISATEUR', 'RÔLE', 'STATUT', 'ACTION'],
              visible
                  .map(
                    (a) => [
                      SizedBox(
                        width: 210,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              a.email,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(a.role.label),
                      StatusBadge(
                        a.active ? 'Actif' : 'Suspendu',
                        color: a.active ? emerald : muted,
                      ),
                      TextButton(
                        onPressed: a.role == UserRole.agent
                            ? null
                            : () async {
                                if (await confirm(
                                  context,
                                  a.active
                                      ? 'Suspendre ce profil ?'
                                      : 'Réactiver ce profil ?',
                                  'Modifier le statut de ${a.name} dans la démonstration.',
                                ))
                                  store.toggleAccount(a);
                              },
                        child: Text(a.active ? 'Suspendre' : 'Réactiver'),
                      ),
                    ],
                  )
                  .toList(),
            ),
        ]),
      ),
      const SizedBox(height: 24),
      Panel(
        child: stack([
          const SectionTitle('Affectations pédagogiques'),
          ...store.assignments.map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link, color: emerald),
              title: Text(a, style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AssignmentDialog(store: store),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter une affectation'),
          ),
        ]),
      ),
    ]);
  }

  Widget publications() {
    final ready =
        store.gradesSubmitted &&
        store.gradesValidated &&
        store.missingMarks == 0;
    return stack([
      const PageHeading(
        'Validation & publication',
        'Contrôlez, prévisualisez et rendez les résultats consultables.',
      ),
      const Notice(
        'Publication locale limitée à INF 201. Le calcul officiel des bulletins, les arrondis réglementaires et le gel en base seront assurés par le serveur.',
        warning: true,
      ),
      ResponsiveSplit(
        main: Panel(
          child: stack([
            const SectionTitle(
              'Contrôles avant publication',
              subtitle: 'Informatique · Licence 2 · Semestre 2',
            ),
            ...[
              (
                store.missingMarks == 0,
                'Toutes les notes sont renseignées',
                '${store.missingMarks} note(s) à régulariser',
              ),
              (
                store.gradesValidated,
                'Registre validé par l’enseignant',
                'Validation pédagogique attendue',
              ),
              (
                store.gradesSubmitted,
                'Registre transmis à la cellule',
                'Transmission attendue',
              ),
            ].map(
              (check) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  check.$1
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                  color: check.$1 ? emerald : const Color(0xFFA26917),
                ),
                title: Text(check.$2, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  check.$1 ? 'Contrôle satisfait' : check.$3,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              ready ? 'Le registre est prêt pour publication.' : 'La publication est bloquée tant que les contrôles ne sont pas satisfaits.',
              style: TextStyle(color: ready ? emerald : muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: !ready
                  ? null
                  : () async {
                      if (await confirm(
                        context,
                        store.publicationVersion == 0
                            ? 'Publier ces résultats ?'
                            : 'Republier les résultats ?',
                        'Une copie des résultats sera figée en mémoire et visible dans le semestre 2 de l’espace étudiant. Ce n’est pas une publication officielle.',
                      ))
                        store.publish();
                    },
              icon: const Icon(Icons.publish_outlined, size: 18),
              label: Text(
                store.publicationVersion == 0
                    ? 'Publier les résultats démo'
                    : 'Republier une nouvelle version',
              ),
            ),
          ]),
        ),
        aside: Panel(
          child: stack([
            const SectionTitle('Dernière publication'),
            if (store.publicationVersion == 0)
              const EmptyState(
                'Aucune version publiée',
                'Le registre reste privé dans cet aperçu.',
              )
            else ...[
              StatusBadge('Version ${store.publicationVersion} · Publiée'),
              const SizedBox(height: 18),
              Text('${store.publishedScores.length} résultats figés'),
              const SizedBox(height: 8),
              const Text(
                'INF 201 · Semestre 2',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              const Text(
                'Les modifications ultérieures du registre ne changent pas cette copie. Une nouvelle validation et publication sont nécessaires.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
      Panel(
        child: stack([
          const SectionTitle(
            'Prévisualisation du registre',
            subtitle: 'Moyennes indicatives, sans valeur officielle',
          ),
          table(
            ['ÉTUDIANT', 'MOYENNE / 20', 'CONTRÔLE'],
            store.marks
                .map(
                  (row) => [
                    Text(row.name),
                    Text(store.total(row)?.toStringAsFixed(2) ?? '—'),
                    StatusBadge(
                      store.total(row) == null ? 'Incomplet' : 'Complet',
                      color: store.total(row) == null
                          ? const Color(0xFFA26917)
                          : emerald,
                    ),
                  ],
                )
                .toList(),
          ),
        ]),
      ),
    ]);
  }

  Widget guide() => stack([
    const PageHeading(
      'Guide & normes',
      'Les règles essentielles pour comprendre votre parcours LMD.',
    ),
    ResponsiveSplit(
      main: Panel(
        child: stack([
          const SectionTitle('Barème de démonstration'),
          table(
            ['NOTE / 100', 'GRADE', 'POINTS'],
            const [
              [Text('80 – 100'), Text('A+'), Text('4.0')],
              [Text('70 – 79'), Text('B+'), Text('3.3')],
              [Text('60 – 69'), Text('B−'), Text('2.7')],
              [Text('50 – 59'), Text('C'), Text('2.0')],
              [Text('35 – 49'), Text('D−'), Text('1.0')],
              [Text('0 – 34'), Text('F / EL'), Text('0.0')],
            ],
          ),
        ]),
      ),
      aside: const Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('À retenir'),
            Text(
              'Une UE est acquise à partir de 50/100. Une note manquante ou une absence doit être régularisée avant la publication.',
            ),
            SizedBox(height: 18),
            Text(
              'Les résultats présentés sont indicatifs et ne remplacent pas un bulletin officiel.',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      ),
    ),
  ]);

  Widget profile() => stack([
    const PageHeading(
      'Profil & notifications',
      'Gérez vos informations de contact et vos alertes académiques.',
    ),
    ResponsiveSplit(
      main: Panel(
        child: stack([
          const SectionTitle('Profil étudiant'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Color(0xFFE9F4F0),
              child: Text('AM', style: TextStyle(color: emerald)),
            ),
            title: Text('Alex Mouna'),
            subtitle: Text('24I001 · Licence 2 Informatique'),
          ),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.mail_outline, color: emerald),
            title: Text('alex@example.test'),
            subtitle: Text('Adresse de contact'),
          ),
          OutlinedButton.icon(
            onPressed: () => toast(
              context,
              'La modification sera raccordée à l’API Laravel.',
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Modifier mes informations'),
          ),
        ]),
      ),
      aside: const Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Notifications'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.notifications_active_outlined,
                color: emerald,
              ),
              title: Text('Résultats disponibles'),
              subtitle: Text('Votre relevé du semestre 1 est consultable.'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline, color: Color(0xFFA26917)),
              title: Text('Inscription à compléter'),
              subtitle: Text('Soumettez vos choix pédagogiques.'),
            ),
          ],
        ),
      ),
    ),
  ]);

  Widget classes() => stack([
    const PageHeading(
      'Classes & matières affectées',
      'Retrouvez vos groupes et les unités dont vous êtes responsable.',
    ),
    Panel(
      child: stack([
        const SectionTitle('Affectations actives'),
        table(
          ['CLASSE', 'MATIÈRE', 'ÉTUDIANTS', 'STATUT'],
          const [
            [
              Text('L2 Informatique · Groupe A'),
              Text('INF 201 · Algorithmique avancée'),
              Text('4'),
              StatusBadge('Active'),
            ],
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => toast(
            context,
            'Les affectations sont administrées par la cellule.',
          ),
          icon: const Icon(Icons.filter_list, size: 18),
          label: const Text('Filtrer les affectations'),
        ),
      ]),
    ),
  ]);

  Widget bulletins() => stack([
    const PageHeading(
      'Gestion des bulletins',
      'Préparez les bulletins issus des résultats publiés.',
    ),
    const Notice(
      'Le calcul officiel du bulletin annuel sera exécuté par l’API Laravel et PostgreSQL.',
      warning: true,
    ),
    Panel(
      child: stack([
        const SectionTitle('Campagnes de bulletins'),
        table(
          ['PÉRIODE', 'CLASSE', 'RÉSULTATS', 'ÉTAT'],
          [
            [
              const Text('Semestre 1 · 2026–2027'),
              const Text('L2 Informatique'),
              const Text('24 étudiants'),
              const StatusBadge('Prêt'),
            ],
            [
              const Text('Semestre 2 · 2026–2027'),
              const Text('L2 Informatique'),
              Text(store.publicationVersion > 0 ? '4 résultats' : 'En attente'),
              StatusBadge(
                store.publicationVersion > 0 ? 'Prévisualisable' : 'Bloqué',
                color: store.publicationVersion > 0
                    ? emerald
                    : const Color(0xFFA26917),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: store.publicationVersion == 0
              ? null
              : () => toast(context, 'Prévisualisation du bulletin ouverte.'),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Prévisualiser les bulletins'),
        ),
      ]),
    ),
  ]);

  Widget audit() => stack([
    const PageHeading(
      'Journal d’audit',
      'Suivez les opérations réalisées dans votre périmètre.',
    ),
    const Notice(
      'Cette vue est une démonstration locale. Le journal inviolable sera alimenté côté serveur.',
      warning: true,
    ),
    Panel(
      child: stack([
        const SectionTitle('Activité récente'),
        ...store.activity.asMap().entries.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE9F4F0),
              child: Text(
                '${entry.key + 1}',
                style: const TextStyle(fontSize: 11, color: emerald),
              ),
            ),
            title: Text(entry.value, style: const TextStyle(fontSize: 13)),
            subtitle: const Text('Session locale · acteur de démonstration'),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () =>
              toast(context, 'L’export sera disponible après intégration API.'),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Exporter le journal'),
        ),
      ]),
    ),
  ]);
}
