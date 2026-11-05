import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'api_client.dart';
import 'file_download.dart';
import 'ui.dart';

class AgentPortalPage extends StatefulWidget {
  const AgentPortalPage({
    super.key,
    required this.page,
    required this.api,
    this.onNavigate,
    this.onExit,
    this.onAcademicYearSelected,
  });

  final String page;
  final StudentApiClient api;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onExit;
  final ValueChanged<String?>? onAcademicYearSelected;

  @override
  State<AgentPortalPage> createState() => _AgentPortalPageState();
}

class _AgentPortalPageState extends State<AgentPortalPage> {
  int revision = 0;
  int? selectedClass;
  String period = 'S1';
  String accountSearch = '';
  String assignmentSearch = '';
  String assignmentYear = 'Toutes';
  String assignmentDepartment = 'Tous';
  String assignmentFaculty = 'Toutes';
  String assignmentLevel = 'Tous';
  String assignmentClass = 'Toutes';
  String assignmentSpecialty = 'Toutes';
  late final TextEditingController profileFirstName = TextEditingController(
    text: '${widget.api.user?['prenom'] ?? ''}',
  );
  late final TextEditingController profileLastName = TextEditingController(
    text: '${widget.api.user?['nom'] ?? ''}',
  );
  late final TextEditingController profileEmail = TextEditingController(
    text: '${widget.api.user?['courriel'] ?? ''}',
  );

  @override
  void dispose() {
    profileFirstName.dispose();
    profileLastName.dispose();
    profileEmail.dispose();
    super.dispose();
  }

  Future<Object> _load() => switch (widget.page) {
    'accounts' => Future.wait([
      widget.api.agentAccounts(),
      widget.api.agentAssignments(),
      widget.api.agentAssignmentProposals(),
    ]),
    'enrollment' => widget.api.agentEnrollments(),
    'academic' => Future.wait([
      widget.api.agentCatalog(),
      widget.api.agentLevels(),
      widget.api.academicYears(),
      widget.api.agentClasses(allYears: true),
      widget.api.agentAcademicStructure(),
    ]),
    'bulletins' || 'publications' => widget.api.agentClasses(),
    'audit' => widget.api.agentAudit(),
    'retakes' => Future.wait([
      widget.api.agentRetakeSessions(),
      widget.api.agentRetakeOpportunities(),
    ]),
    'normal-sessions' => widget.api.agentNormalExamSessions(),
    'requests' => Future.wait([
      widget.api.agentRequests(),
      widget.api.agentAccounts(),
    ]),
    'grade-transmissions' => widget.api.agentGradeTransmissions(),
    'profile' => Future.wait([
      widget.api.getProfile(),
      widget.api.academicYears(),
    ]),
    _ => widget.api.agentDashboard(),
  };

  void _reload() => setState(() => revision++);

  @override
  Widget build(BuildContext context) => FutureBuilder<Object>(
    key: ValueKey(revision),
    future: _load(),
    builder: (context, snapshot) {
      final title = switch (widget.page) {
        'academic' => 'Structure & catalogue',
        'accounts' => 'Comptes & affectations',
        'enrollment' => 'Inscriptions à examiner',
        'requests' => 'Requêtes étudiantes',
        'grade-transmissions' => 'Numérisation des notes',
        'bulletins' || 'publications' => 'Contrôle & publications',
        'audit' => 'Journal d’audit',
        'retakes' => 'Sessions de rattrapage',
        'normal-sessions' => 'Sessions normales',
        'profile' => 'Mon profil',
        _ => 'Espace agent',
      };
      final subtitle = switch (widget.page) {
        'academic' => 'Structure universitaire, filières et formations accessibles à votre compte.',
        'accounts' =>
          'Comptes rattachés au département et affectations pédagogiques.',
        'enrollment' => 'Examinez les choix soumis; vous pouvez ajouter un motif facultatif à la décision.',
        'requests' => 'Transmettez chaque dossier à un enseignant affecté à la classe et à l’UE.',
        'grade-transmissions' => 'Contrôlez les grilles transmises par les enseignants puis retournez-les pour leur vérification.',
        'bulletins' || 'publications' =>
          'Prévisualisez les calculs avant tout gel officiel des résultats.',
        'audit' =>
          'Historique des actions visibles dans votre périmètre départemental.',
        'retakes' => 'Planifiez et suivez les sessions du département.',
        'normal-sessions' => 'Choisissez une date, une heure et une salle libre; les enseignants et les étudiants inscrits seront notifiés.',
        'profile' =>
          'Consultez et mettez à jour les informations de votre compte.',
        _ => 'Suivi des inscriptions, programmes, bulletins et publications du département.',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            title,
            subtitle,
            action: IconButton(
              onPressed: _reload,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (snapshot.hasError) ...[
            Notice(_error(snapshot.error!), warning: true),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ] else if (!snapshot.hasData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _content(snapshot.data!),
        ],
      );
    },
  );

  Widget _content(Object data) => switch (widget.page) {
    'accounts' => _accounts(data as List),
    'enrollment' => _enrollments(data as List),
    'academic' => _academic(data as List),
    'bulletins' || 'publications' => _bulletins(data as List),
    'audit' => _audit(data as List),
    'retakes' => _retakes(data as List),
    'normal-sessions' => _normalSessions(data as List),
    'requests' => _requests(data as List),
    'grade-transmissions' => _gradeTransmissions(data as List),
    'profile' => _profile(data as List),
    _ => _dashboard(data as Map<String, dynamic>),
  };

  Widget _dashboard(Map<String, dynamic> data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if ((data['departements'] ?? 0) == 0)
        const Notice(
          'Aucun département n’est attribué à ce compte. Contactez l’administration pour configurer son périmètre.',
          warning: true,
        ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric('Classes', data['classes'], () => _showClasses()),
          _metric(
            'UE actives',
            data['ues_actives'],
            () => widget.onNavigate?.call('academic'),
          ),
          _metric(
            'Inscriptions à examiner',
            data['inscriptions_a_examiner'],
            () => widget.onNavigate?.call('enrollment'),
          ),
          _metric(
            'Publications',
            data['publications'],
            () => widget.onNavigate?.call('bulletins'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Notice(
        'Les règles de calcul et d’admission sont celles définies par l’Université. Vous pouvez publier les résultats de votre département après vérification des aperçus.',
        warning: data['peut_publier'] != true,
      ),
    ],
  );

  Widget _gradeTransmissions(List data) {
    final rows = _maps(data);
    if (rows.isEmpty) {
      return const EmptyState(
        'Aucune transmission à numériser',
        'Les notes transmises par les enseignants de votre département apparaîtront ici.',
      );
    }
    return Column(
      children: rows
          .map(
            (row) => Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${row['code_classe']} · ${row['code_ue']} · ${row['code_m']}',
                    ),
                    subtitle: Text(
                      '${row['intitule_matiere']}\n${row['enseignant_prenom']} ${row['enseignant_nom']} · ${row['evaluation']?['type_eval'] ?? 'Évaluation'} · ${row['poids_evaluation'] ?? '—'} % · version ${row['version']}',
                    ),
                    isThreeLine: true,
                    trailing: StatusBadge(
                      'À contrôler',
                      color: const Color(0xFFB87516),
                    ),
                  ),
                  Text('Motif de transmission : ${row['motif']}'),
                  const SizedBox(height: 8),
                  ..._maps(row['notes']).map(
                    (note) => ListTile(
                      dense: true,
                      title: Text(
                        '${note['matricule']} · ${note['prenom']} ${note['nom']}',
                      ),
                      trailing: Text(
                        '${note['situation'] == 'NUMERIQUE' ? '${note['valeur_note']} /20' : note['situation']}'
                        ' → ${note['situation_numerisee'] == 'NUMERIQUE' ? '${note['valeur_numerisee']} /20' : note['situation_numerisee'] ?? 'à numériser'}',
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _digitizeGradeTransmission(row),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Saisir ou importer la numérisation'),
                    ),
                  ),
                  if (!_maps(row['notes'])
                      .every((note) => note['situation_numerisee'] != null))
                    const Notice(
                      'Numérisez toutes les lignes avant de retourner la grille à l’enseignant.',
                      warning: true,
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          _maps(
                            row['notes'],
                          ).every((note) => note['situation_numerisee'] != null)
                          ? () => _returnGradeTransmission(row)
                          : null,
                      icon: const Icon(Icons.forward_to_inbox_outlined),
                      label: const Text(
                        'Terminer le contrôle et retourner à l’enseignant',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _digitizeGradeTransmission(Map<String, dynamic> row) async {
    final notes = _maps(row['notes'])
        .map((note) => Map<String, dynamic>.from(note))
        .toList();
    final controllers = <String, TextEditingController>{
      for (final note in notes)
        '${note['matricule']}': TextEditingController(
          text:
              note['valeur_numerisee']?.toString() ??
              note['valeur_note']?.toString() ??
              '',
        ),
    };
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: const Text('Numériser la grille de notes'),
            content: SizedBox(
              width: 620,
              height: MediaQuery.sizeOf(context).height * 0.54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _importDigitizedCsv(notes, controllers, setDialog),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Importer un CSV'),
                    ),
                  ),
                  const Text(
                    'CSV : matricule, note sur 20, situation. Une note hors barème est ramenée à 0 ou 20; une cellule vide devient EL.',
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final key = '${note['matricule']}';
                        final absent = note['situation_numerisee'] == 'ABSENTE';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${note['matricule']} · ${note['prenom']} ${note['nom']}',
                          ),
                          subtitle: Text(
                            'Enseignant : ${note['situation'] == 'NUMERIQUE' ? note['valeur_note'] : note['situation']}',
                          ),
                          trailing: SizedBox(
                            width: 190,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controllers[key],
                                    enabled: !absent,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Note /20',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: absent
                                      ? 'Marquer présente'
                                      : 'Marquer absente',
                                  onPressed: () => setDialog(() {
                                    note['situation_numerisee'] = absent
                                        ? 'NUMERIQUE'
                                        : 'ABSENTE';
                                    if (!absent) controllers[key]!.clear();
                                  }),
                                  icon: Icon(
                                    absent
                                        ? Icons.person_outline
                                        : Icons.person_off_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enregistrer la numérisation'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted) return;
      final payload = <Map<String, dynamic>>[];
      var clamped = 0;
      var eliminated = 0;
      for (final note in notes) {
        var absent = note['situation_numerisee'] == 'ABSENTE';
        final raw = controllers['${note['matricule']}']!.text.trim().replaceAll(
          ',',
          '.',
        );
        if (raw.isEmpty) absent = true;
        final value = absent ? null : double.tryParse(raw);
        if (!absent && value == null) {
          toast(
            context,
            'Chaque note numérisée doit être numérique ou marquée EL.',
          );
          return;
        }
        final normalized = value?.clamp(0.0, 20.0).toDouble();
        if (value != null && normalized != value) clamped++;
        if (absent) eliminated++;
        payload.add({
          'matricule': note['matricule'],
          'situation': absent ? 'ABSENTE' : 'NUMERIQUE',
          'valeur_note': normalized,
          'version_note': note['version_note'],
        });
      }
      final reason = await _reasonDialog('Motif de numérisation');
      if (reason == null) return;
      await _mutate(
        () => widget.api.agentDigitizeGradeTransmission(
          row['id'] as int,
          notes: payload,
          reason: reason,
        ),
      );
      if (mounted && (clamped > 0 || eliminated > 0)) {
        toast(
          context,
          '$clamped note(s) ramenée(s) dans l’intervalle 0–20 · $eliminated mention(s) EL.',
        );
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _importDigitizedCsv(
    List<Map<String, dynamic>> notes,
    Map<String, TextEditingController> controllers,
    StateSetter setDialog,
  ) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    if (selection == null || selection.files.isEmpty) return;
    final file = selection.files.first;
    if (file.bytes == null) return;
    try {
      final lines = const LineSplitter().convert(utf8.decode(file.bytes!));
      final byMatricule = {
        for (final note in notes)
          '${note['matricule']}'.trim().toUpperCase(): note,
      };
      var imported = 0;
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index].trim();
        if (line.isEmpty) continue;
        final separator = line.contains(';')
            ? ';'
            : line.contains('\t')
            ? '\t'
            : line.contains('|')
            ? '|'
            : ',';
        final columns = line
            .split(separator)
            .map((value) => value.trim().replaceAll('"', ''))
            .toList();
        if (index == 0 && columns.first.toLowerCase().contains('matricule'))
          continue;
        if (columns.length < 2) continue;
        final note = byMatricule[columns[0].toUpperCase()];
        if (note == null) continue;
        final declaredSituation = columns.length > 2 && columns[2].isNotEmpty
            ? columns[2].toUpperCase()
            : '';
        final rawMark = columns[1].toUpperCase();
        final situation = columns[1].isEmpty ||
                const ['EL', 'ELIMINE', 'ELIMINEE', 'ABS', 'ABSENT', 'ABSENTE']
                    .contains(rawMark)
            ? 'ABSENTE'
            : declaredSituation.isNotEmpty
            ? declaredSituation
            : 'NUMERIQUE';
        if (!const ['NUMERIQUE', 'ABSENTE'].contains(situation)) continue;
        note['situation_numerisee'] = situation;
        controllers['${note['matricule']}']!.text = situation == 'NUMERIQUE'
            ? columns[1].replaceAll(',', '.')
            : '';
        imported++;
      }
      setDialog(() {});
      if (mounted) toast(context, '$imported ligne(s) importée(s).');
    } catch (error) {
      if (mounted) toast(context, 'Fichier CSV illisible : $error');
    }
  }

  Future<void> _returnGradeTransmission(Map<String, dynamic> row) async {
    final reason = await _reasonDialog('Motif du retour à l’enseignant');
    if (reason == null) return;
    await _mutate(
      () => widget.api.agentReturnGradeTransmission(
        row['id'] as int,
        reason: reason,
      ),
    );
  }

  Widget _metric(String title, Object? value, VoidCallback onTap) => SizedBox(
    width: 190,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${value ?? '—'}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const Icon(Icons.open_in_new, size: 16),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showClasses() async {
    try {
      final results = await Future.wait([
        widget.api.agentClasses(),
        widget.api.agentAssignments(),
        widget.api.agentAccounts(),
      ]);
      if (!mounted) return;
      final classes = results[0];
      final assignments = results[1];
      final accounts = results[2];
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Classes de votre périmètre'),
          content: SizedBox(
            width: 620,
            child: classes.isEmpty
                ? const Text('Aucune classe n’est rattachée à votre périmètre.')
                : ListView(
                    shrinkWrap: true,
                    children: classes.map((row) {
                      final teachers = assignments
                          .where(
                            (a) =>
                                a['classe_id'] == row['id'] &&
                                a['actif'] == true,
                          )
                          .map(
                            (a) =>
                                '${a['prenom']} ${a['nom']} · ${a['code_ue']}/${a['code_m']}',
                          )
                          .toSet()
                          .join('\n');
                      final students = accounts
                          .where((account) => account['role'] == 'ETUDIANT')
                          .where(
                            (account) => _maps(account['classes_detail']).any(
                              (membership) =>
                                  membership['classe_id'] == row['id'],
                            ),
                          )
                          .map(
                            (account) =>
                                '${account['matricule'] ?? 'Sans matricule'} · ${account['prenom']} ${account['nom']}',
                          )
                          .join('\n');
                      return ListTile(
                        title: Text(
                          '${row['code_classe']} · ${row['annee_academique']}',
                        ),
                        subtitle: Text(
                          '${row['nom_depart']} · ${row['libelle_niv']}\nÉtudiants (${students.isEmpty ? '0' : students.split('\n').length}) : ${students.isEmpty ? 'aucun inscrit visible' : students}\nEnseignants : ${teachers.isEmpty ? 'aucune affectation active visible' : teachers}',
                        ),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Widget _profile(List data) {
    final profile = Map<String, dynamic>.from(data[0] as Map);
    final years = _maps(data[1]);
    final selectedYear = widget.api.activeAcademicYearId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informations personnelles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: profileFirstName,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: profileLastName,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: profileEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Courriel'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _mutate(() async {
                      final updated = await widget.api.updateProfile({
                        'prenom': profileFirstName.text.trim(),
                        'nom': profileLastName.text.trim(),
                        'courriel': profileEmail.text.trim().isEmpty
                            ? null
                            : profileEmail.text.trim(),
                      });
                      widget.api.user = updated;
                    }),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer le profil'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Changer le mot de passe'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Identifiant : ${profile['login'] ?? '—'} · Rôle : ${profile['role'] ?? 'AGENT'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Année académique consultée',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ce choix actualise les classes, inscriptions, affectations et résultats affichés dans votre espace.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    years.any((year) => '${year['id']}' == selectedYear)
                    ? selectedYear
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Année académique',
                ),
                items: years
                    .map(
                      (year) => DropdownMenuItem(
                        value: '${year['id']}',
                        child: Text('${year['libelle']}'),
                      ),
                    )
                    .toList(),
                onChanged: (year) async {
                  if (year == null) return;
                  final notifySelection = widget.onAcademicYearSelected;
                  if (notifySelection == null) {
                    await widget.api.selectAcademicYear(year);
                  } else {
                    notifySelection(year);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    final form = GlobalKey<FormState>();
    final current = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel',
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.length < 12 ||
                      !RegExp(r'[A-Za-z]').hasMatch(value) ||
                      !RegExp(r'\d').hasMatch(value)) {
                    return '12 caractères minimum, avec lettres et chiffres';
                  }
                  if (value == current.text) {
                    return 'Choisissez un nouveau mot de passe';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer'),
                validator: (v) =>
                    v != password.text ? 'Les mots de passe diffèrent' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      try {
        await widget.api.changePassword(
          currentPassword: current.text,
          password: password.text,
          passwordConfirmation: confirmation.text,
        );
        await widget.api.clearSession();
        if (!mounted) return;
        toast(
          context,
          'Mot de passe modifié. Reconnectez-vous avec le nouveau mot de passe.',
        );
        widget.onExit?.call();
      } catch (error) {
        if (mounted) toast(context, _error(error));
      }
    }
    current.dispose();
    password.dispose();
    confirmation.dispose();
  }

  Widget _accounts(List data) {
    final allAccounts = _maps(data[0]);
    final proposals = _maps(data[2]);
    final search = accountSearch.trim().toLowerCase();
    final accounts = allAccounts.where((account) {
      if (search.isEmpty) return true;
      final searchable = [
        account['nom'],
        account['prenom'],
        account['login'],
        account['matricule'],
        account['eid'],
        account['fonction_enseignant'],
        ...(account['classes'] as List? ?? []),
        ...(account['enseignements'] as List? ?? []),
      ].join(' ').toLowerCase();
      return searchable.contains(search);
    }).toList();
    final assignments = _maps(data[1]);
    final years =
        assignments
            .map((item) => '${item['annee_academique'] ?? ''}')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final departments =
        assignments
            .map((item) => '${item['nom_depart'] ?? ''}')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final faculties =
        assignments
            .map((item) => '${item['nom_fac'] ?? ''}')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final levels =
        assignments
            .map((item) => '${item['libelle_niv'] ?? ''}')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final classes =
        assignments
            .map((item) => '${item['code_classe'] ?? ''}')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final specialties =
        assignments
            .map((item) => '${item['libelle_specialite'] ?? ''}')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final visibleAssignments = assignments.where((item) {
      final query = assignmentSearch.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          [
            item['prenom'],
            item['nom'],
            item['eid'],
            item['code_classe'],
            item['code_ue'],
            item['code_m'],
            item['libelle_specialite'],
          ].join(' ').toLowerCase().contains(query);
      return matchesSearch &&
          (assignmentYear == 'Toutes' ||
              item['annee_academique'] == assignmentYear) &&
          (assignmentFaculty == 'Toutes' ||
              item['nom_fac'] == assignmentFaculty) &&
          (assignmentDepartment == 'Tous' ||
              item['nom_depart'] == assignmentDepartment) &&
          (assignmentLevel == 'Tous' ||
              item['libelle_niv'] == assignmentLevel) &&
          (assignmentClass == 'Toutes' ||
              item['code_classe'] == assignmentClass) &&
          (assignmentSpecialty == 'Toutes' ||
              item['libelle_specialite'] == assignmentSpecialty);
    }).toList();
    final groupedAccounts = <String, List<Map<String, dynamic>>>{};
    for (final account in accounts) {
      final classes = (account['classes'] as List? ?? [])
          .map((value) => '$value')
          .toList();
      if (classes.isEmpty) {
        groupedAccounts
            .putIfAbsent('Sans classe / sans affectation', () => [])
            .add(account);
      } else {
        for (final group in classes) {
          groupedAccounts.putIfAbsent(group, () => []).add(account);
        }
      }
    }
    final groupedAssignments = <String, List<Map<String, dynamic>>>{};
    for (final item in visibleAssignments) {
      final group = [
        item['annee_academique'],
        item['code_fac'],
        item['code_de'],
        item['libelle_niv'],
        item['libelle_specialite'],
        item['code_classe'],
      ].where((value) => value != null && '$value'.isNotEmpty).join(' · ');
      groupedAssignments.putIfAbsent(group, () => []).add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Comptes du département',
                subtitle: 'Comptes regroupés par classe et enseignements. Les données restent limitées à votre périmètre.',
              ),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Rechercher un étudiant ou un enseignant',
                ),
                onChanged: (value) => setState(() => accountSearch = value),
              ),
              if (accounts.isEmpty)
                const EmptyState(
                  'Aucun compte rattaché',
                  'Les étudiants apparaissent après leur inscription dans une classe du département.',
                ),
              ...groupedAccounts.entries.map(
                (group) => ExpansionTile(
                  initiallyExpanded: groupedAccounts.length == 1,
                  title: Text(group.key),
                  subtitle: Text('${group.value.length} compte(s)'),
                  children: group.value
                      .map(
                        (account) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _showAccountProfile(account),
                          leading: CircleAvatar(
                            child: Text(
                              '${account['prenom'] ?? '·'}'.characters.first
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(
                            '${account['prenom'] ?? ''} ${account['nom'] ?? ''}'
                                .trim(),
                          ),
                          subtitle: Text(
                            '${account['role']} · ${account['matricule'] ?? account['eid'] ?? account['login']}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusBadge(
                                account['actif'] == true ? 'Actif' : 'Suspendu',
                                color: account['actif'] == true
                                    ? emerald
                                    : muted,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed:
                                    account['role'] == 'AGENT' ||
                                        account['gestionnable'] == false
                                    ? null
                                    : () => _toggleAccount(account),
                                tooltip: account['gestionnable'] == false
                                    ? 'Gestion réservée à son périmètre de rattachement'
                                    : account['actif'] == true
                                    ? 'Suspendre'
                                    : 'Réactiver',
                                icon: Icon(
                                  account['actif'] == true
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Modifier le profil',
                                onPressed:
                                    account['gestionnable'] == false ||
                                        account['role'] == 'AGENT'
                                    ? null
                                    : () => _editAccount(account),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Choix d’enseignement à valider',
                subtitle:
                    '${proposals.length} choix en attente de validation.',
              ),
              if (proposals.isEmpty)
                const EmptyState(
                  'Aucun choix à valider',
                  'Les UE et EC acceptés par les enseignants apparaîtront ici.',
                ),
              ...proposals.map(
                (proposal) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pending_actions_outlined),
                  title: Text(
                    '${proposal['prenom_enseignant'] ?? ''} ${proposal['nom_enseignant'] ?? ''} · ${proposal['eid'] ?? ''}'
                        .trim(),
                  ),
                  subtitle: Text(
                    '${proposal['code_classe']} · ${proposal['libelle_niv']} · S${proposal['numero_semestre']} · ${proposal['code_ue']}/${proposal['code_m']}\nChoix confirmé par l’enseignant · ${proposal['annee_academique']}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Valider ce choix d’enseignement',
                        onPressed: () =>
                            _decideAssignmentProposal(proposal, 'APPROUVER'),
                        icon: const Icon(Icons.check),
                      ),
                      IconButton.outlined(
                        tooltip: 'Refuser ce choix',
                        onPressed: () =>
                            _decideAssignmentProposal(proposal, 'REJETER'),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Affectations pédagogiques',
                subtitle:
                    '${visibleAssignments.length} sur ${assignments.length} affectation(s) · filtrables par année et département.',
              ),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Rechercher classe, UE, EC ou enseignant',
                ),
                onChanged: (value) => setState(() => assignmentSearch = value),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _assignmentFilter(
                    'Faculté',
                    assignmentFaculty,
                    'Toutes',
                    faculties,
                    (value) => setState(() => assignmentFaculty = value),
                  ),
                  _assignmentFilter(
                    'Département',
                    assignmentDepartment,
                    'Tous',
                    departments,
                    (value) => setState(() => assignmentDepartment = value),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          years.contains(assignmentYear) ||
                              assignmentYear == 'Toutes'
                          ? assignmentYear
                          : 'Toutes',
                      decoration: const InputDecoration(
                        labelText: 'Année académique',
                      ),
                      items: ['Toutes', ...years]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => assignmentYear = value ?? 'Toutes'),
                    ),
                  ),
                  _assignmentFilter(
                    'Niveau',
                    assignmentLevel,
                    'Tous',
                    levels,
                    (value) => setState(() => assignmentLevel = value),
                  ),
                  _assignmentFilter(
                    'Classe',
                    assignmentClass,
                    'Toutes',
                    classes,
                    (value) => setState(() => assignmentClass = value),
                  ),
                  _assignmentFilter(
                    'Spécialité',
                    assignmentSpecialty,
                    'Toutes',
                    specialties,
                    (value) => setState(() => assignmentSpecialty = value),
                  ),
                ],
              ),
              ...groupedAssignments.entries.map(
                (group) => ExpansionTile(
                  title: Text(group.key),
                  subtitle: Text('${group.value.length} affectation(s)'),
                  children: group.value
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${item['code_classe']} · ${item['code_ue']} · ${item['code_m']}',
                          ),
                          subtitle: Text(
                            '${item['prenom'] ?? ''} ${item['nom'] ?? ''} · ${item['eid'] ?? ''} · ${item['nom_fac'] ?? ''} / ${item['nom_depart'] ?? ''}',
                          ),
                          trailing: Switch(
                            value: item['actif'] == true,
                            onChanged: (active) => _setAssignment(item, active),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _createAssignment(accounts, assignments),
                icon: const Icon(Icons.add),
                label: const Text('Affecter un enseignant'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleAccount(Map<String, dynamic> account) async {
    final active = account['actif'] != true;
    final reason = await _reasonDialog(
      active ? 'Réactiver le compte' : 'Suspendre le compte',
    );
    if (reason == null) return;
    await _mutate(
      () => widget.api.agentSetAccountStatus(
        account['id'] as int,
        active: active,
        reason: reason,
      ),
    );
  }

  Widget _assignmentFilter(
    String label,
    String selected,
    String allLabel,
    List<String> values,
    ValueChanged<String> onChanged,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      initialValue: values.contains(selected) || selected == allLabel
          ? selected
          : allLabel,
      decoration: InputDecoration(labelText: label),
      items: [allLabel, ...values]
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) => onChanged(value ?? allLabel),
    ),
  );

  Future<void> _setAssignment(Map<String, dynamic> item, bool active) async =>
      _mutate(
        () => widget.api.agentSetAssignmentStatus(item['id'] as int, active),
      );

  Future<void> _decideAssignmentProposal(
    Map<String, dynamic> proposal,
    String decision,
  ) async {
    final approve = decision == 'APPROUVER';
    final accepted = await confirm(
      context,
      approve ? 'Valider ce choix d’enseignement ?' : 'Refuser ce choix ?',
      approve
          ? 'L’enseignant pourra transmettre les notes préparées dans son carnet à la cellule pour validation.'
          : 'Les brouillons resteront conservés, mais l’affectation ne sera pas activée.',
    );
    if (!accepted) return;
    final reason = await _reasonDialog(
      approve ? 'Motif d’approbation (facultatif)' : 'Motif du refus',
    );
    if (reason == null) return;
    if (!approve && reason.trim().length < 8) {
      toast(
        context,
        'Veuillez indiquer un motif de refus d’au moins 8 caractères.',
      );
      return;
    }
    await _mutate(
      () => widget.api.agentDecideAssignmentProposal(
        proposal['id'] as int,
        decision: decision,
        reason: reason,
      ),
    );
  }

  Future<void> _createAssignment(
    List<Map<String, dynamic>> accounts,
    List<Map<String, dynamic>> assignments,
  ) async {
    try {
      final teachers = accounts
          .where(
            (item) =>
                item['role'] == 'ENSEIGNANT' &&
                item['actif'] == true &&
                item['enseignant_id'] != null,
          )
          .toList();
      final classes = await widget.api.agentClasses();
      final catalog = await widget.api.agentCatalog();
      if (!mounted) return;
      final elements = _maps(catalog['elements_constitutifs']);
      final units = _maps(catalog['ues']);
      List<Map<String, dynamic>> elementsForClass(int id) {
        final selectedClass = classes.firstWhere((item) => item['id'] == id);
        final validUnitIds = units
            .where(
              (unit) =>
                  unit['statut_catalogue'] == 'ACTIF' &&
                  unit['niveau_id'].toString() ==
                      selectedClass['niveau_id'].toString() &&
                  unit['version_programme'].toString() ==
                      selectedClass['version_programme'].toString(),
            )
            .map((unit) => unit['id'])
            .toSet();
        return elements
            .where((item) => validUnitIds.contains(item['ue_id']))
            .toList();
      }

      bool hasActiveAssignment(int classId, int courseId) => assignments.any(
        (assignment) =>
            assignment['actif'] == true &&
            '${assignment['classe_id']}' == '$classId' &&
            '${assignment['matiere_id']}' == '$courseId',
      );
      List<Map<String, dynamic>> availableElementsForClass(int classId) =>
          elementsForClass(classId)
              .where(
                (element) =>
                    !hasActiveAssignment(classId, element['id'] as int),
              )
              .toList();

      final eligibleClasses = classes
          .where((item) => elementsForClass(item['id'] as int).isNotEmpty)
          .toList();
      if (teachers.isEmpty || eligibleClasses.isEmpty) {
        toast(
          context,
          teachers.isEmpty ? 'Aucun compte enseignant actif n’est disponible.' : 'Aucune classe de votre département ne possède un EC dans un catalogue actif correspondant à son programme.',
        );
        return;
      }
      int teacher = teachers.first['enseignant_id'] as int;
      int classId = eligibleClasses.first['id'] as int;
      final selectedCourses = <int>{};
      final initialAvailable = availableElementsForClass(classId);
      if (initialAvailable.isNotEmpty) {
        selectedCourses.add(initialAvailable.first['id'] as int);
      }
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: const Text('Nouvelle affectation'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: teacher,
                    decoration: const InputDecoration(labelText: 'Enseignant'),
                    items: teachers
                        .map(
                          (item) => DropdownMenuItem(
                            value: item['enseignant_id'] as int,
                            child: Text(
                              '${item['prenom']} ${item['nom']} · ${item['eid']} · ${item['fonction_enseignant'] ?? 'Enseignant'}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialog(() => teacher = value!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: classId,
                    decoration: const InputDecoration(labelText: 'Classe'),
                    items: eligibleClasses
                        .map(
                          (item) => DropdownMenuItem(
                            value: item['id'] as int,
                            child: Text('${item['code_classe']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialog(() {
                      classId = value!;
                      selectedCourses.clear();
                      final available = availableElementsForClass(classId);
                      if (available.isNotEmpty) {
                        selectedCourses.add(available.first['id'] as int);
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Unités et éléments à confier',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Un EC déjà confié à un enseignant actif dans cette classe est désactivé. Désactivez son affectation pour le remplacer.',
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    child: ListView(
                      shrinkWrap: true,
                      children: units
                          .where(
                            (unit) => elementsForClass(
                              classId,
                            ).any((element) => element['ue_id'] == unit['id']),
                          )
                          .map((unit) {
                            final unitElements = elementsForClass(classId)
                                .where(
                                  (element) => element['ue_id'] == unit['id'],
                                )
                                .toList();
                            return ExpansionTile(
                              initiallyExpanded: true,
                              title: Text(
                                '${unit['code_ue']} · ${unit['intitule_ue']}',
                              ),
                              children: unitElements.map((element) {
                                final id = element['id'] as int;
                                final currentAssignment = assignments
                                    .where(
                                      (assignment) =>
                                          assignment['actif'] == true &&
                                          '${assignment['classe_id']}' ==
                                              '$classId' &&
                                          '${assignment['matiere_id']}' ==
                                              '$id',
                                    )
                                    .firstOrNull;
                                final locked = currentAssignment != null;
                                return CheckboxListTile(
                                  dense: true,
                                  value: selectedCourses.contains(id),
                                  title: Text(
                                    '${element['code_m']} · ${element['intitule_matiere']}',
                                  ),
                                  subtitle: locked
                                      ? Text(
                                          'Déjà confié à ${currentAssignment['prenom']} ${currentAssignment['nom']}',
                                        )
                                      : null,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: locked
                                      ? null
                                      : (checked) => setDialog(() {
                                          if (checked == true) {
                                            selectedCourses.add(id);
                                          } else {
                                            selectedCourses.remove(id);
                                          }
                                        }),
                                );
                              }).toList(),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: selectedCourses.isEmpty
                    ? null
                    : () => Navigator.pop(context, {
                        'enseignant_id': teacher,
                        'classe_id': classId,
                        'matiere_ids': selectedCourses.toList(),
                      }),
                child: const Text('Affecter'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (result != null)
        await _mutate(() => widget.api.agentCreateAssignment(result));
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Widget _enrollments(List data) {
    final rows = _maps(data);
    if (rows.isEmpty)
      return const EmptyState(
        'Aucune inscription à examiner',
        'Les nouvelles demandes apparaîtront ici.',
      );
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      '${row['prenom'] ?? ''} ${row['nom'] ?? ''} · ${row['matricule']}',
                      subtitle:
                          '${row['code_classe']} · ${row['libelle_niv']} · ${row['annee_academique'] ?? ''}',
                    ),
                    Text(
                      'Semestre ${row['numero_semestre']} · soumis le ${row['date_soumission'] ?? '—'}',
                    ),
                    if (row['fiche_academique_disponible'] == true) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadAcademicSheet(row),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Consulter la fiche annuelle'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _review(row, 'VALIDER'),
                          icon: const Icon(Icons.check),
                          label: const Text('Valider'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _review(row, 'REFUSER'),
                          icon: const Icon(Icons.undo),
                          label: const Text('Retourner l’inscription'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _review(Map<String, dynamic> row, String decision) async {
    final reason = await _reasonDialog(
      decision == 'VALIDER' ? 'Motif de validation' : 'Motif du retour',
    );
    if (reason == null) return;
    await _mutate(
      () => widget.api.agentReviewEnrollment(
        row['id'] as int,
        decision: decision,
        reason: reason,
      ),
    );
  }

  Future<void> _downloadAcademicSheet(Map<String, dynamic> row) async {
    try {
      final bytes = await widget.api.agentDownloadAcademicSheet(
        (row['inscription_classe_id'] as num).toInt(),
      );
      await downloadFile('fiche-academique-${row['matricule']}.pdf', bytes);
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Widget _academic(List data) {
    final catalog = Map<String, dynamic>.from(data[0] as Map);
    final units = _maps(catalog['ues']);
    final elements = _maps(catalog['elements_constitutifs']);
    final levels = _maps(data[1]);
    final years = _maps(data[2]);
    final classes = _maps(data[3]);
    final structure = Map<String, dynamic>.from(data[4] as Map);
    final classesByYear = <String, List<Map<String, dynamic>>>{};
    for (final item in classes) {
      final year = '${item['annee_academique'] ?? 'Année inconnue'}';
      classesByYear.putIfAbsent(year, () => []).add(item);
    }
    final academicYearsOrdered = classesByYear.keys.toList()
      ..sort((left, right) => right.compareTo(left));
    final unitsByLevel = <int, List<Map<String, dynamic>>>{};
    for (final unit in units) {
      final levelId = (unit['niveau_id'] as num?)?.toInt();
      if (levelId != null) unitsByLevel.putIfAbsent(levelId, () => []).add(unit);
    }
    for (final levelUnits in unitsByLevel.values) {
      levelUnits.sort((left, right) {
        final semesterOrder = (left['numero_semestre'] as num? ?? 0)
            .compareTo(right['numero_semestre'] as num? ?? 0);
        if (semesterOrder != 0) return semesterOrder;
        final codeOrder = '${left['code_ue']}'.compareTo('${right['code_ue']}');
        if (codeOrder != 0) return codeOrder;
        return (left['version_programme'] as num? ?? 0)
            .compareTo(right['version_programme'] as num? ?? 0);
      });
    }
    final programGroups = <String, List<Map<String, dynamic>>>{};
    for (final level in levels) {
      final key =
          '${level['faculte_id']}|${level['departement_id']}|${level['filiere_id']}';
      programGroups.putIfAbsent(key, () => []).add(level);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SectionTitle(
                      'Structure universitaire de votre périmètre',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _manageAcademicStructure(structure),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Gérer départements, filières et parcours'),
                  ),
                ],
              ),
              const Text(
                'Université · Faculté · Département · Filière · Niveau · Spécialité',
              ),
              if (programGroups.isEmpty)
                const EmptyState(
                  'Aucune structure accessible',
                  'Aucun département n’est associé au périmètre de ce compte Agent.',
                ),
              ...programGroups.values.map((programLevels) {
                final first = programLevels.first;
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('${first['code_fac']} · ${first['nom_fac']}'),
                  subtitle: Text(
                    '${first['nom_univ']}  ›  ${first['code_de']} · ${first['nom_depart']}  ›  ${first['code_f']} · ${first['nom_f']}',
                  ),
                  children: programLevels
                      .map(
                        (level) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.account_tree_outlined),
                          title: Text(
                            '${level['code_niv']} · ${level['libelle_niv']}',
                          ),
                          subtitle: Text(
                            '${level['cycle_niv']}${level['libelle_specialite'] == null ? '' : ' · ${level['libelle_specialite']}'}',
                          ),
                        ),
                      )
                      .toList(),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Classes par année académique',
                subtitle: 'Les classes restent consultables selon leur année de création.',
              ),
              if (classes.isEmpty)
                const EmptyState(
                  'Aucune classe',
                  'Créez une classe à partir d’un niveau qui vous est attribué.',
                ),
              ...academicYearsOrdered.map(
                (year) => ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: year == academicYearsOrdered.first,
                  title: Text('$year · ${classesByYear[year]!.length} classe(s)'),
                  children: classesByYear[year]!
                      .map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 16),
                          leading: const Icon(Icons.groups_outlined),
                          title: Text('${item['code_classe']} · ${item['libelle_niv']}'),
                          subtitle: Text(
                            '${item['nom_univ']} · ${item['nom_fac']} · ${item['nom_depart']} · ${item['code_f']}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: levels.isEmpty || years.isEmpty
                    ? null
                    : () => _createClass(levels, years),
                icon: const Icon(Icons.add),
                label: const Text('Créer une classe'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Catalogue des UE et EC',
                subtitle: 'Par niveau, puis selon l’approbation du barème par la cellule informatique.',
              ),
              if (units.isEmpty)
                const EmptyState(
                  'Catalogue vide',
                  'Les unités créées en brouillon apparaîtront ici.',
                ),
              ...levels.map((level) {
                final levelId = (level['id'] as num).toInt();
                final levelUnits = unitsByLevel[levelId] ?? const <Map<String, dynamic>>[];
                final approvedUnits = levelUnits
                    .where((unit) => unit['profil_evaluation'] != null)
                    .toList();
                final pendingUnits = levelUnits
                    .where((unit) => unit['profil_evaluation'] == null)
                    .toList();
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('${level['code_f']} · ${level['code_niv']} · ${level['libelle_niv']}'),
                  subtitle: Text(
                    '${level['nom_depart']} · ${level['nom_f']}${level['libelle_specialite'] == null ? '' : ' · ${level['libelle_specialite']}'} · ${approvedUnits.length} barème(s) approuvé(s) · ${pendingUnits.length} à traiter',
                  ),
                  children: [
                    _catalogueStatusGroup(
                      title: 'Barèmes approuvés par la cellule',
                      units: approvedUnits,
                      elements: elements,
                      initiallyExpanded: approvedUnits.isNotEmpty,
                    ),
                    _catalogueStatusGroup(
                      title: 'Barèmes non approuvés ou à définir',
                      units: pendingUnits,
                      elements: elements,
                    ),
                    if (levelUnits.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Aucune UE dans le catalogue pour ce niveau.'),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _createUnit([level]),
                        icon: const Icon(Icons.add),
                        label: const Text('Créer une UE dans ce niveau'),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _catalogueStatusGroup({
    required String title,
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> elements,
    bool initiallyExpanded = false,
  }) => ExpansionTile(
    tilePadding: const EdgeInsets.only(left: 16),
    initiallyExpanded: initiallyExpanded,
    title: Text('$title (${units.length})'),
    children: units.map((unit) {
      final children = elements
          .where((element) => element['ue_id'] == unit['id'])
          .toList();
      return ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 12),
        title: Text(
          '${unit['code_ue']} · ${unit['intitule_ue']} · version ${unit['version_programme']}',
        ),
        subtitle: Text(
          'S${unit['numero_semestre']} · ${unit['credit_ue']} crédits · ${unit['statut_catalogue']} · ${unit['profil_evaluation'] == null ? (unit['profil_propose'] == null ? 'Aucun barème proposé' : 'Proposition en attente : ${_evaluationProfileLabel(unit['profil_propose'])}') : _evaluationProfileLabel(unit['profil_evaluation'])}',
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _setUnitEvaluationProfile(unit),
              icon: const Icon(Icons.tune),
              label: const Text('Définir le barème officiel'),
            ),
          ),
          ...children.map(
            (element) => ListTile(
              dense: true,
              title: Text('${element['code_m']} · ${element['intitule_matiere']}'),
              subtitle: Text(
                'EC ${element['rang_ec']} · ${element['credit_matiere']} crédits',
              ),
            ),
          ),
          if (unit['statut_catalogue'] == 'BROUILLON') ...[
            TextButton.icon(
              onPressed: () => _createElement(unit),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un EC'),
            ),
            FilledButton.tonal(
              onPressed: children.isEmpty
                  ? null
                  : () => _setUnitStatus(unit, 'ACTIF'),
              child: const Text('Activer l’UE'),
            ),
          ] else if (unit['statut_catalogue'] == 'ACTIF')
            TextButton(
              onPressed: () => _setUnitStatus(unit, 'ARCHIVE'),
              child: const Text('Archiver l’UE'),
            ),
        ],
      );
    }).toList(),
  );

  Future<void> _manageAcademicStructure(Map<String, dynamic> structure) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gérer la structure universitaire'),
        content: SizedBox(
          width: 720,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Notice(
                'Créez les structures nécessaires à votre périmètre. Chaque nouveau département est automatiquement rattaché à votre compte Agent.',
              ),
              _structureSection(
                dialogContext,
                structure,
                'universite',
                'Universités',
                'universites',
                true,
              ),
              _structureSection(
                dialogContext,
                structure,
                'faculte',
                'Facultés',
                'facultes',
                true,
              ),
              _structureSection(
                dialogContext,
                structure,
                'departement',
                'Départements',
                'departements',
                _maps(structure['facultes']).isNotEmpty,
              ),
              _structureSection(
                dialogContext,
                structure,
                'filiere',
                'Filières',
                'filieres',
                true,
              ),
              _structureSection(
                dialogContext,
                structure,
                'specialite',
                'Spécialités',
                'specialites',
                _maps(structure['filieres']).isNotEmpty,
              ),
              _structureSection(
                dialogContext,
                structure,
                'niveau',
                'Niveaux',
                'niveaux',
                _maps(structure['filieres']).isNotEmpty,
              ),
              if (_maps(structure['filieres']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: () => _generateAcademicLevels(
                      dialogContext,
                      structure,
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Générer les niveaux d’une filière'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _structureSection(
    BuildContext dialogContext,
    Map<String, dynamic> structure,
    String kind,
    String title,
    String key,
    bool canCreate,
  ) {
    final rows = _maps(structure[key]);
    final codeField = switch (kind) {
      'universite' => 'code_univ',
      'faculte' => 'code_fac',
      'departement' => 'code_de',
      'filiere' => 'code_f',
      'specialite' => 'code_specialite',
      _ => 'code_niv',
    };
    final labelField = switch (kind) {
      'universite' => 'nom_univ',
      'faculte' => 'nom_fac',
      'departement' => 'nom_depart',
      'filiere' => 'nom_f',
      'specialite' => 'libelle_specialite',
      _ => 'libelle_niv',
    };
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text('$title (${rows.length})'),
      children: [
        ...rows.map((item) {
          final canEdit = (kind != 'universite' && kind != 'faculte') ||
              item['modifiable'] != false;
          return ListTile(
            leading: item['logo'] is Map && (item['logo'] as Map)['base64'] is String
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      base64Decode((item['logo'] as Map)['base64'] as String),
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  )
                : null,
            title: Text('${item[codeField]} · ${item[labelField]}'),
            subtitle: kind == 'niveau'
                ? Text(
                    '${item['code_f']} · ${item['cycle_niv']}${item['code_specialite'] == null ? '' : ' · ${item['code_specialite']}'}',
                  )
                : kind == 'specialite'
                ? Text('${item['code_f']} · ${item['nom_f']}')
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canEdit && const {'universite', 'faculte', 'departement'}.contains(kind))
                  IconButton(
                    tooltip: item['logo'] == null ? 'Ajouter le logo' : 'Remplacer le logo',
                    icon: Icon(item['logo'] == null ? Icons.add_photo_alternate_outlined : Icons.image_outlined),
                    onPressed: () => _uploadStructureLogo(kind, item),
                  ),
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: canEdit
                      ? () => _editAcademicStructureItem(
                          dialogContext,
                          structure,
                          kind,
                          item: item,
                        )
                      : null,
                ),
              ],
            ),
          );
        }),
        if (canCreate)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  _editAcademicStructureItem(dialogContext, structure, kind),
              icon: const Icon(Icons.add),
              label: Text('Ajouter'),
            ),
          ),
      ],
    );
  }

  Future<void> _uploadStructureLogo(
    String kind,
    Map<String, dynamic> structureItem,
  ) async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (selected == null || selected.files.isEmpty) return;
    final file = selected.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) toast(context, 'Impossible de lire le fichier sélectionné.');
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) toast(context, 'Le logo doit peser au maximum 2 Mo.');
      return;
    }
    try {
      final response = await widget.api.agentUploadStructureLogo(
        kind,
        (structureItem['id'] as num).toInt(),
        filename: file.name,
        file: bytes,
      );
      structureItem['logo'] = response['data'] is Map
          ? (response['data'] as Map)['logo']
          : null;
      if (mounted) {
        setState(() => revision++);
        toast(context, 'Logo rattaché à la structure.');
        _reload();
      }
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _editAcademicStructureItem(
    BuildContext parentDialog,
    Map<String, dynamic> structure,
    String kind, {
    Map<String, dynamic>? item,
  }) async {
    final codeKey = switch (kind) {
      'universite' => 'code_univ',
      'faculte' => 'code_fac',
      'departement' => 'code_de',
      'filiere' => 'code_f',
      'specialite' => 'code_specialite',
      _ => 'code_niv',
    };
    final nameKey = switch (kind) {
      'universite' => 'nom_univ',
      'faculte' => 'nom_fac',
      'departement' => 'nom_depart',
      'filiere' => 'nom_f',
      'specialite' => 'libelle_specialite',
      _ => 'libelle_niv',
    };
    final parentKey = switch (kind) {
      'faculte' => 'universite_id',
      'departement' => 'faculte_id',
      'filiere' => 'departement_id',
      'specialite' || 'niveau' => 'filiere_id',
      _ => null,
    };
    final parentListKey = switch (kind) {
      'faculte' => 'universites',
      'departement' => 'facultes',
      'filiere' => 'departements',
      'specialite' || 'niveau' => 'filieres',
      _ => null,
    };
    final parents = parentListKey == null
        ? <Map<String, dynamic>>[]
        : _maps(structure[parentListKey]);
    if (parentKey != null && parents.isEmpty) {
      toast(context, 'Aucun rattachement parent n’est accessible.');
      return;
    }
    final code = TextEditingController(text: '${item?[codeKey] ?? ''}');
    final name = TextEditingController(text: '${item?[nameKey] ?? ''}');
    int? parentId = parentKey == null
        ? null
        : (item?[parentKey] as num?)?.toInt() ??
              (kind == 'niveau' ? null : (parents.first['id'] as num).toInt());
    var cycle = '${item?['cycle_niv'] ?? 'LICENCE'}';
    int? specialtyId = (item?['specialite_id'] as num?)?.toInt();
    var specialtyRows = _maps(structure['specialites'])
        .where(
          (specialty) =>
              specialty['actif'] == true && specialty['filiere_id'] == parentId,
        )
        .toList();
    final result = await showDialog<Map<String, dynamic>>(
      context: parentDialog,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            '${item == null ? 'Créer' : 'Modifier'} ${kind == 'universite'
                ? 'une université'
                : kind == 'faculte'
                ? 'une faculté'
                : kind == 'departement'
                ? 'un département'
                : kind == 'filiere'
                ? 'une filière'
                : kind == 'specialite'
                ? 'une spécialité'
                : 'un niveau'}',
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (parentKey != null)
                  DropdownButtonFormField<int>(
                    initialValue: parentId,
                    decoration: InputDecoration(
                      labelText: kind == 'faculte'
                          ? 'Université'
                          : kind == 'departement'
                          ? 'Faculté'
                          : kind == 'filiere'
                          ? 'Département'
                          : kind == 'niveau'
                          ? 'Filière obligatoire'
                          : 'Filière',
                    ),
                    items: parents
                        .map(
                          (parent) => DropdownMenuItem<int>(
                            value: (parent['id'] as num).toInt(),
                            child: Text(
                              '${parent['code_univ'] ?? parent['code_fac'] ?? parent['code_de'] ?? parent['code_f']} · ${parent['nom_univ'] ?? parent['nom_fac'] ?? parent['nom_depart'] ?? parent['nom_f']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialog(() {
                      parentId = value;
                      if (kind == 'niveau') {
                        specialtyId = null;
                        specialtyRows = _maps(structure['specialites'])
                            .where(
                              (specialty) =>
                                  specialty['actif'] == true &&
                                  specialty['filiere_id'] == value,
                            )
                            .toList();
                      }
                    }),
                  ),
                if (kind == 'niveau') ...[
                  DropdownButtonFormField<String>(
                    initialValue: cycle,
                    decoration: const InputDecoration(labelText: 'Cycle'),
                    items: const [
                      DropdownMenuItem(value: 'LICENCE', child: Text('Licence')),
                      DropdownMenuItem(value: 'MASTER', child: Text('Master')),
                      DropdownMenuItem(value: 'DOCTORAT', child: Text('Doctorat')),
                    ],
                    onChanged: (value) => setDialog(() => cycle = value ?? cycle),
                  ),
                  if (specialtyRows.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      initialValue: specialtyId,
                      decoration: const InputDecoration(
                        labelText: 'Spécialité (facultatif)',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tronc commun'),
                        ),
                        ...specialtyRows.map(
                          (specialty) => DropdownMenuItem<int?>(
                            value: (specialty['id'] as num).toInt(),
                            child: Text(
                              '${specialty['code_specialite']} · ${specialty['libelle_specialite']}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialog(() => specialtyId = value),
                    ),
                ],
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Code'),
                  onChanged: (_) => setDialog(() {}),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  onChanged: (_) => setDialog(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed:
                  code.text.trim().isEmpty ||
                      name.text.trim().isEmpty ||
                      (parentKey != null && parentId == null)
                  ? null
                  : () => Navigator.pop(context, {
                      codeKey: code.text.trim(),
                      nameKey: name.text.trim(),
                      if (parentKey != null) parentKey: parentId,
                      if (kind == 'niveau') 'cycle_niv': cycle,
                      if (kind == 'niveau') 'specialite_id': specialtyId,
                    }),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    if (result == null || !mounted) return;
    try {
      await _mutate(
        () => widget.api.agentSaveAcademicStructure(
          kind,
          id: (item?['id'] as num?)?.toInt(),
          data: result,
        ),
      );
      if (parentDialog.mounted) Navigator.pop(parentDialog);
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _generateAcademicLevels(
    BuildContext parentDialog,
    Map<String, dynamic> structure,
  ) async {
    final tracks = _maps(structure['filieres']);
    if (tracks.isEmpty) return;
    int? trackId;
    var cycle = 'LICENCE';
    int? specialtyId;
    String? startLevel;
    var specialties = _maps(structure['specialites'])
        .where(
          (item) =>
              trackId != null &&
              item['actif'] == true &&
              item['filiere_id'] == trackId,
        )
        .toList();
    final result = await showDialog<Map<String, dynamic>>(
      context: parentDialog,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final levelCodes = switch (cycle) {
            'LICENCE' => const ['L1', 'L2', 'L3'],
            'MASTER' => const ['M1', 'M2'],
            _ => const ['D1', 'D2', 'D3'],
          };
          return AlertDialog(
            title: const Text('Générer le parcours'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: trackId,
                    decoration: const InputDecoration(
                      labelText: 'Filière obligatoire',
                    ),
                    items: tracks
                        .map(
                          (item) => DropdownMenuItem<int?>(
                            value: (item['id'] as num).toInt(),
                            child: Text('${item['code_f']} · ${item['nom_f']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialog(() {
                      trackId = value ?? trackId;
                      specialties = _maps(structure['specialites'])
                          .where(
                            (item) =>
                                trackId != null &&
                                item['actif'] == true &&
                                item['filiere_id'] == trackId,
                          )
                          .toList();
                      specialtyId = null;
                      startLevel = null;
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: cycle,
                    decoration: const InputDecoration(labelText: 'Cycle'),
                    items: const [
                      DropdownMenuItem(value: 'LICENCE', child: Text('Licence · 3 niveaux')),
                      DropdownMenuItem(value: 'MASTER', child: Text('Master · 2 niveaux')),
                      DropdownMenuItem(value: 'DOCTORAT', child: Text('Doctorat · 3 niveaux')),
                    ],
                    onChanged: (value) => setDialog(() {
                      cycle = value ?? cycle;
                      startLevel = null;
                    }),
                  ),
                  if (specialties.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      initialValue: specialtyId,
                      decoration: const InputDecoration(
                        labelText: 'Spécialiser le parcours (facultatif)',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Parcours commun'),
                        ),
                        ...specialties.map(
                          (item) => DropdownMenuItem<int?>(
                            value: (item['id'] as num).toInt(),
                            child: Text('${item['code_specialite']} · ${item['libelle_specialite']}'),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialog(() {
                        specialtyId = value;
                        startLevel = null;
                      }),
                    ),
                  if (specialtyId != null)
                    DropdownButtonFormField<String>(
                      initialValue: startLevel,
                      decoration: const InputDecoration(
                        labelText: 'Début de la spécialisation',
                      ),
                      items: levelCodes
                          .map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialog(() => startLevel = value),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Les niveaux déjà présents sont conservés. Les niveaux avant le début choisi restent communs; les suivants portent le code de la spécialité.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: trackId == null ||
                        (specialtyId != null && startLevel == null)
                    ? null
                    : () => Navigator.pop(context, {
                        'filiere_id': trackId!,
                        'cycle_niv': cycle,
                        if (specialtyId != null) ...{
                          'specialite_id': specialtyId,
                          'niveau_debut_specialite': startLevel,
                        },
                      }),
                child: const Text('Générer'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _mutate(() => widget.api.agentGenerateTrackLevels(result));
      if (parentDialog.mounted) Navigator.pop(parentDialog);
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _createClass(
    List<Map<String, dynamic>> levels,
    List<Map<String, dynamic>> years,
  ) async {
    final code = TextEditingController();
    int level = levels.first['id'] as int;
    int year = years.first['id'] as int;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Nouvelle classe'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'Code de classe',
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'Niveau'),
                  items: levels
                      .map(
                        (v) => DropdownMenuItem(
                          value: v['id'] as int,
                          child: Text('${v['code_f']} · ${v['code_niv']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => level = v!),
                ),
                DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: const InputDecoration(
                    labelText: 'Année académique',
                  ),
                  items: years
                      .map(
                        (v) => DropdownMenuItem(
                          value: v['id'] as int,
                          child: Text('${v['libelle']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => year = v!),
                ),
                const SizedBox(height: 12),
                const Text(
                  'La classe est créée pour l’année académique choisie. Les UE et EC suivent le syllabus du niveau; les affectations des enseignants sont propres à cette classe.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'code_classe': code.text.trim(),
                'niveau_id': level,
                'annee_id': year,
              }),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    if (result == null || result['code_classe'] == '') return;
    await _mutate(() => widget.api.agentCreateClass(result));
  }

  Future<void> _createUnit(List<Map<String, dynamic>> levels) async {
    final code = TextEditingController();
    final title = TextEditingController();
    final credit = TextEditingController(text: '3');
    int level = levels.first['id'] as int;
    int semester = 1;
    String category = 'FONDAMENTALE';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Créer une UE en brouillon'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Code UE'),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Intitulé'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: level,
                    decoration: const InputDecoration(labelText: 'Niveau'),
                    items: levels
                        .map(
                          (v) => DropdownMenuItem(
                            value: v['id'] as int,
                            child: Text('${v['code_f']} · ${v['code_niv']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => level = v!),
                  ),
                  TextField(
                    controller: credit,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Crédits UE'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: semester,
                    decoration: const InputDecoration(labelText: 'Semestre'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('S1')),
                      DropdownMenuItem(value: 2, child: Text('S2')),
                    ],
                    onChanged: (v) => setDialog(() => semester = v!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: const [
                      DropdownMenuItem(
                        value: 'FONDAMENTALE',
                        child: Text('Fondamentale'),
                      ),
                      DropdownMenuItem(
                        value: 'OPTIONNELLE',
                        child: Text('Optionnelle'),
                      ),
                    ],
                    onChanged: (v) => setDialog(() => category = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'code_ue': code.text.trim(),
                'intitule_ue': title.text.trim(),
                'niveau_id': level,
                'numero_semestre': semester,
                'categorie_ue': category,
                'credit_ue': double.tryParse(credit.text.replaceAll(',', '.')),
              }),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    title.dispose();
    credit.dispose();
    if (result == null ||
        result['code_ue'] == '' ||
        result['credit_ue'] == null)
      return;
    await _mutate(() => widget.api.agentCreateUnit(result));
  }

  Future<void> _createElement(Map<String, dynamic> unit) async {
    final code = TextEditingController();
    final title = TextEditingController();
    final credit = TextEditingController(text: '1');
    int rank = 1;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Ajouter un EC · ${unit['code_ue']}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Code EC'),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Intitulé'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: rank,
                  decoration: const InputDecoration(labelText: 'Rang'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('EC 1')),
                    DropdownMenuItem(value: 2, child: Text('EC 2')),
                  ],
                  onChanged: (v) => setDialog(() => rank = v!),
                ),
                TextField(
                  controller: credit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Crédits EC'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'code_m': code.text.trim(),
                'intitule_matiere': title.text.trim(),
                'rang_ec': rank,
                'credit_matiere': double.tryParse(
                  credit.text.replaceAll(',', '.'),
                ),
              }),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    title.dispose();
    credit.dispose();
    if (result == null ||
        result['code_m'] == '' ||
        result['credit_matiere'] == null)
      return;
    await _mutate(
      () => widget.api.agentCreateElement(unit['id'] as int, result),
    );
  }

  Future<void> _setUnitStatus(Map<String, dynamic> unit, String status) async {
    final ok = await confirm(
      context,
      status == 'ACTIF' ? 'Activer cette UE ?' : 'Archiver cette UE ?',
      'Les règles du catalogue seront contrôlées par PostgreSQL.',
    );
    if (ok)
      await _mutate(
        () => widget.api.agentSetUnitStatus(unit['id'] as int, status),
      );
  }

  String _evaluationProfileLabel(Object? profile) => switch (profile) {
    'CC_SN' => 'CC 30 % + SN 70 %',
    'CC_TP_SN' => 'CC 20 % + TP 30 % + SN 50 %',
    'CC_TPE_SN' => 'CC 20 % + TPE 20 % + SN 60 %',
    _ => 'À définir',
  };

  Future<void> _setUnitEvaluationProfile(Map<String, dynamic> unit) async {
    const profiles = <String, String>{
      'CC_SN': 'CC 30 % + SN 70 % · UE théorique/pratique',
      'CC_TP_SN': 'CC 20 % + TP 30 % + SN 50 % · UE mixte',
      'CC_TPE_SN': 'CC 20 % + TPE 20 % + SN 60 % · avec TPE',
    };
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Profil officiel de notation'),
        children: profiles.entries
            .map(
              (entry) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(entry.value),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    await _mutate(
      () =>
          widget.api.agentSetUnitEvaluationProfile(unit['id'] as int, selected),
    );
  }

  Widget _bulletins(List data) {
    final classes = _maps(data);
    if (classes.isEmpty)
      return Column(
        children: [
          _publicationRulesCard(),
          const EmptyState(
            'Aucune classe dans ce périmètre',
            'Les classes disponibles apparaîtront ici.',
          ),
        ],
      );
    selectedClass ??= classes.first['id'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _publicationRulesCard(),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedClass,
                decoration: const InputDecoration(labelText: 'Classe'),
                items: classes
                    .map(
                      (item) => DropdownMenuItem(
                        value: item['id'] as int,
                        child: Text(
                          '${item['code_classe']} · ${item['annee_academique']}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  selectedClass = value;
                  revision++;
                }),
              ),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Période'),
                items: const [
                  DropdownMenuItem(value: 'S1', child: Text('Semestre 1')),
                  DropdownMenuItem(value: 'S2', child: Text('Semestre 2')),
                  DropdownMenuItem(value: 'ANNUELLE', child: Text('Annuelle')),
                ],
                onChanged: (value) => setState(() {
                  period = value!;
                  revision++;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (selectedClass != null)
          FutureBuilder<Map<String, dynamic>>(
            future: widget.api.agentBulletinPreview(selectedClass!, period),
            key: ValueKey('$selectedClass-$period-$revision'),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Notice(_error(snapshot.error!), warning: true);
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final preview = snapshot.data!;
              final students = _maps(preview['etudiants']);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    'Bulletin ${period == 'ANNUELLE' ? 'annuel' : 'du semestre ${period.substring(1)}'} · ${preview['code_classe'] ?? ''}',
                    subtitle:
                        '${preview['annee_academique'] ?? ''} · ${students.length} étudiant(s) inscrit(s)',
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _exportBulletinsExcel(preview),
                          icon: const Icon(Icons.grid_on_outlined),
                          label: const Text('Exporter l’aperçu Excel'),
                        ),
                        OutlinedButton.icon(
                          onPressed: preview['pret'] == true
                              ? () => _exportBulletinPreviewsPdf(preview)
                              : null,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Prévisualiser les bulletins PDF'),
                        ),
                        if ((preview['version_courante'] as num?) != null)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _exportBulletinsExcel(preview, published: true),
                            icon: const Icon(Icons.verified_outlined),
                            label: Text(
                              'Exporter la version officielle ${preview['version_courante']}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  Notice(
                    preview['pret'] == true
                        ? 'Tous les bulletins sont calculables. Vérifiez la prévisualisation avant de publier.'
                        : 'Publication bloquée : ${preview['transmissions_en_attente'] ?? 0} transmission(s) doivent encore être traitées et ${preview['evaluations_non_verifiees'] ?? 0} évaluation(s) de cette période ne sont pas encore vérifiées par leur enseignant. Les inscriptions et notes doivent aussi être complètes.',
                    warning: preview['pret'] != true,
                  ),
                  ...students.map((student) {
                    final content = student['contenu'];
                    final mgpKey = period == 'ANNUELLE'
                        ? 'mgp_total'
                        : period == 'S1'
                        ? 'mgp_s1'
                        : 'mgp_s2';
                    final mgp = content == null ? null : content[mgpKey];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: 8,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${student['prenom'] ?? ''} ${student['nom'] ?? ''} · ${student['matricule']}',
                              ),
                              subtitle: student['pret'] == true
                                  ? Text(
                                      'Rang ${student['rang'] ?? '—'} · MGP ${period == 'ANNUELLE' ? 'annuelle' : period} : ${mgp ?? '—'} · ${content?['total_credits'] ?? 0} crédits · ${content?['decision_admission'] ?? ''}',
                                    )
                                  : Text('${student['message'] ?? 'Non prêt'}'),
                              trailing: StatusBadge(
                                student['pret'] == true
                                    ? 'Calculé'
                                    : 'À compléter',
                                color: student['pret'] == true
                                    ? emerald
                                    : const Color(0xFFB33B43),
                              ),
                            ),
                            if (student['pret'] == true)
                              ExpansionTile(
                                title: const Text('Détail des UE et des notes'),
                                children: _maps(content?['ues']).map((unit) {
                                  final mark = unit['arrondi'];
                                  final converted = mark is num
                                      ? (mark / 5).toStringAsFixed(2)
                                      : '—';
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      '${unit['code_ue'] ?? ''} · ${unit['grade'] ?? ''}',
                                    ),
                                    subtitle: Text(
                                      '${unit['credit'] ?? 0} crédits · note ${converted}/20 · points ${unit['points'] ?? '—'}',
                                    ),
                                    trailing: Text(
                                      '${unit['arrondi'] ?? '—'} /100',
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (preview['peut_publier'] == true &&
                      preview['pret'] == true)
                    FilledButton.icon(
                      onPressed: () => _publish(preview),
                      icon: const Icon(Icons.publish),
                      label: Text(
                        (preview['version_courante'] ?? 0) == 0
                            ? 'Publier les résultats'
                            : 'Publier une nouvelle version',
                      ),
                    ),
                  if (preview['publication_bloquee'] != null)
                    Notice('${preview['publication_bloquee']}', warning: true),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _publicationRulesCard() => FutureBuilder<Map<String, dynamic>>(
    key: ValueKey('publication-rules-$revision'),
    future: widget.api.agentPublicationRules(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Notice(_error(snapshot.error!), warning: true);
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final data = snapshot.data!;
      final rules = Map<String, dynamic>.from(data['regles'] as Map? ?? {});
      final bareme = _maps(rules['bareme_points_qualite_sur_100'])
          .map((row) => '${row['minimum']}→${row['points']}')
          .join(' · ');
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionTitle('Règles de publication'),
                ),
                const StatusBadge('Règles universitaires', color: emerald),
              ],
            ),
            Text(
              'Moteur ${rules['version_moteur']} · MGP ${rules['version_bareme']}',
            ),
            Text('Barème UE /100 : $bareme'),
            Text(
              'Admission annuelle : MGP ≥ ${rules['admission_annuelle']?['mgp_minimum']} et chaque UE ≥ ${rules['admission_annuelle']?['minimum_ue_sur_100']}/100, sans élimination.',
            ),
            Text(
              'Rattrapage : de ${rules['rattrapage']?['minimum_sur_20']} à moins de ${rules['rattrapage']?['maximum_sur_20_exclus']}/20; obligatoire jusqu’à ${rules['rattrapage']?['seuil_rattrapage_obligatoire_sur_20']}/20, facultatif au-dessus; ${rules['rattrapage']?['nombre_maximum_sessions']} session(s) maximum.',
            ),
            Text('${data['source'] ?? 'Règles académiques officielles de l’Université'}.'),
          ],
        ),
      );
    },
  );

  Future<void> _exportBulletinsExcel(
    Map<String, dynamic> preview, {
    bool published = false,
  }) async {
    final classId = (preview['classe_id'] as num?)?.toInt() ?? selectedClass;
    if (classId == null) return;
    try {
      final bytes = await widget.api.agentExportBulletins(
        classId,
        period,
        published: published,
      );
      final code = '${preview['code_classe'] ?? 'classe'}';
      await downloadFile(
        'bulletins-$code-$period-${published ? 'officiel' : 'apercu'}.xlsx',
        bytes,
      );
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _exportBulletinPreviewsPdf(
    Map<String, dynamic> preview,
  ) async {
    final students = _maps(preview['etudiants']);
    if (students.isEmpty || students.any((student) => student['pret'] != true)) {
      toast(context, 'Tous les dossiers doivent être calculables pour générer les aperçus PDF.');
      return;
    }
    final structure = Map<String, dynamic>.from(preview['structure'] as Map? ?? {});
    final logoData = Map<String, dynamic>.from(structure['logo'] as Map? ?? {});
    Uint8List? logoBytes;
    if (logoData['base64'] is String) {
      logoBytes = base64Decode(logoData['base64'] as String);
    } else if ('${structure['universite'] ?? ''}'.toUpperCase().contains('YAOUNDÉ I') ||
        '${structure['universite'] ?? ''}'.toUpperCase().contains('YAOUNDE I')) {
      logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer.asUint8List();
    }
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final periodLabel = switch (period) {
      'S1' => 'SEMESTRE 1 / SEMESTER 1',
      'S2' => 'SEMESTRE 2 / SEMESTER 2',
      _ => 'ANNUEL / ANNUAL',
    };
    final academicYear = '${preview['annee_academique'] ?? '—'}';
    final examYear = academicYear.split(RegExp('[-/]')).last;
    final institution = '${structure['universite'] ?? 'UNIVERSITÉ'}'.toUpperCase();
    final document = pw.Document();

    for (final student in students) {
      final content = Map<String, dynamic>.from(student['contenu'] as Map? ?? {});
      final units = _maps(content['ues']);
      final totalCredits = (content['total_credits'] as num?)?.toDouble() ?? 0;
      final capitalizedCredits = units.fold<double>(
        0,
        (sum, unit) => sum + (((unit['arrondi'] as num?) ?? 0) >= 35
            ? ((unit['credit'] as num?)?.toDouble() ?? 0)
            : 0),
      );
      final mgp = content[period == 'ANNUELLE' ? 'mgp_total' : 'mgp_${period.toLowerCase()}'] ?? '—';
      document.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(35, 22, 35, 28),
          header: (_) => pw.Column(children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: _transcriptHeaderSide('RÉPUBLIQUE DU CAMEROUN', 'Paix - Travail - Patrie', institution)),
              pw.SizedBox(width: 70, height: 70, child: logo == null ? null : pw.Image(logo, fit: pw.BoxFit.contain)),
              pw.Expanded(child: _transcriptHeaderSide('REPUBLIC OF CAMEROON', 'Peace - Work - Fatherland', institution)),
            ]),
            pw.SizedBox(height: 3),
            pw.Text('${structure['faculte'] ?? ''}'.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('${structure['departement'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Text('RELEVÉ DE NOTES / TRANSCRIPT', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
            pw.Text('APERÇU DE TRAVAIL · NON OFFICIEL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 1.2),
          ]),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('GNU · ${academicYear} · ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: pdf.PdfColors.grey)),
          ),
          build: (_) => [
            pw.Row(children: [
              pw.Expanded(child: _transcriptInfo('Noms et prénoms / Surname and Name', '${student['nom'] ?? ''} ${student['prenom'] ?? ''}'.trim())),
              pw.Expanded(child: _transcriptInfo('Matricule / Registration N°', '${student['matricule'] ?? '—'}')),
            ]),
            pw.Row(children: [
              pw.Expanded(child: _transcriptInfo('Domaine / Domain', '${structure['domaine'] ?? '—'}')),
              pw.Expanded(child: _transcriptInfo('Niveau / Level', '${structure['niveau'] ?? '—'}')),
            ]),
            pw.Row(children: [
              pw.Expanded(child: _transcriptInfo('Filière / Discipline', '${structure['filiere'] ?? '—'}')),
              pw.Expanded(child: _transcriptInfo('Spécialité / Option', '${structure['specialite'] ?? '—'}')),
            ]),
            pw.Row(children: [
              pw.Expanded(child: _transcriptInfo('Année académique / Academic Year', academicYear)),
              pw.Expanded(child: _transcriptInfo('Période / Period', periodLabel)),
            ]),
            pw.SizedBox(height: 7),
            pw.TableHelper.fromTextArray(
              headers: ['Code UE', 'Intitulé de l’UE / UE Title', 'Crédits', 'Moy /100', 'Mention', 'Sem.', 'Année', 'Décision'],
              data: [
                for (final unit in units)
                  [
                    '${unit['code_ue'] ?? ''}', '${unit['intitule_ue'] ?? ''}', '${unit['credit'] ?? 0}',
                    unit['arrondi'] == null ? '—' : (unit['arrondi'] as num).toStringAsFixed(2),
                    '${unit['grade'] ?? '—'}', '${unit['semestre'] ?? ''}', examYear,
                    ((unit['arrondi'] as num?) ?? 0) >= 35 ? 'CA' : (unit['grade'] == 'EL' ? 'EL' : 'NC'),
                  ],
              ],
              headerStyle: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 6.1),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {1: pw.Alignment.centerLeft},
              border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .45),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              columnWidths: {
                0: const pw.FixedColumnWidth(48), 1: const pw.FlexColumnWidth(3.5),
                2: const pw.FixedColumnWidth(30), 3: const pw.FixedColumnWidth(42),
                4: const pw.FixedColumnWidth(38), 5: const pw.FixedColumnWidth(28),
                6: const pw.FixedColumnWidth(35), 7: const pw.FixedColumnWidth(38),
              },
            ),
            pw.SizedBox(height: 10),
            pw.Text('Crédits capitalisés : ${capitalizedCredits.toStringAsFixed(0)} / ${totalCredits.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text('Moyenne Générale Pondérée (MGP) : $mgp / 4', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text('Décision : ${content['decision_admission'] ?? '—'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Légende / Legend', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Note /100', 'Code', 'Points de qualité', 'Mention'],
              data: const [
                ['80–100', 'A', '4.00', 'Très bien / Excellent'],
                ['75–79', 'A-', '3.70', 'Très bien / Very good'],
                ['70–74', 'B+', '3.30', 'Bien / Good'],
                ['65–69', 'B', '3.00', 'Bien / Good'],
                ['60–64', 'B-', '2.70', 'Assez bien / Fairly good'],
                ['55–59', 'C+', '2.30', 'Passable / Satisfactory'],
                ['50–54', 'C', '2.00', 'Passable / Satisfactory'],
                ['45–49', 'C-', '1.70', 'Capitalisé non transférable'],
                ['40–44', 'D+', '1.30', 'Capitalisé non transférable'],
                ['35–39', 'D', '1.00', 'Capitalisé non transférable'],
                ['30–34', 'E', '0.00', 'Échec / Fail'],
                ['< 30', 'F', '0.00', 'Échec / Fail'],
              ],
              headerStyle: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 6),
              border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .35),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            ),
            pw.SizedBox(height: 15),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(child: _transcriptSignature('Le Président du Jury / President of the Jury')),
              pw.SizedBox(width: 35),
              pw.Expanded(child: _transcriptSignature('Le Chef de Département / Head of Department')),
            ]),
            pw.Center(child: pw.Text('Les signatures et le cachet seront apposés après validation officielle.', style: const pw.TextStyle(fontSize: 7))),
          ],
        ),
      );
    }

    try {
      final filename = 'apercus-bulletins-${preview['code_classe'] ?? 'classe'}-$period.pdf';
      await FilePicker.platform.saveFile(
        fileName: filename,
        bytes: await document.save(),
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  pw.Widget _transcriptHeaderSide(String title, String motto, String institution) => pw.Column(
    children: [
      pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      pw.Text(motto, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
      pw.SizedBox(height: 5),
      pw.Text(institution, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ],
  );

  pw.Widget _transcriptInfo(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(2, 3, 5, 3),
    child: pw.RichText(text: pw.TextSpan(children: [
      pw.TextSpan(text: '$label : ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 8)),
    ])),
  );

  pw.Widget _transcriptSignature(String title) => pw.Column(children: [
    pw.SizedBox(height: 25),
    pw.Container(height: 1, color: pdf.PdfColors.black),
    pw.SizedBox(height: 3),
    pw.Text(title, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
    pw.SizedBox(height: 42),
  ]);

  Future<void> _publish(Map<String, dynamic> preview) async {
    final current = preview['version_courante'];
    final confirmed = await confirm(
      context,
      current == null
          ? 'Confirmer la publication ?'
          : 'Créer une nouvelle version ?',
      current == null
          ? 'Les bulletins calculés seront figés pour toute la classe.'
          : 'La nouvelle version remplacera la version courante sans effacer l’historique.',
    );
    if (!confirmed) return;
    await _mutate(
      () => widget.api.agentPublish(
        selectedClass!,
        period,
        confirmNewVersion: current != null,
      ),
    );
  }

  Widget _audit(List data) {
    final rows = _maps(data);
    if (rows.isEmpty)
      return const EmptyState(
        'Aucune action trouvée',
        'Le journal se remplira avec les opérations effectuées dans votre périmètre.',
      );
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                padding: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${row['action']} · ${row['type_objet']} #${row['identifiant_objet']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${row['date_action'] ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${row['motif'] ?? ''}'),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _normalSessions(List data) {
    final sessions = _maps(data);
    if (sessions.isEmpty) {
      return const EmptyState(
        'Aucune session normale à planifier',
        'Les évaluations SN prévues par les enseignants apparaîtront ici.',
      );
    }
    return Column(
      children: sessions.map((item) {
        final scheduled = item['heure_debut'] != null && item['salle'] != null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: Text(
                '${item['code_classe']} · ${item['code_ue']} · ${item['code_m']}',
              ),
              subtitle: Text(
                '${item['enseignant_prenom'] ?? ''} ${item['enseignant_nom'] ?? ''} · ${item['intitule_matiere']}\n'
                '${item['date_evaluation'] ?? 'Date à fixer'}'
                '${scheduled ? ' · ${item['heure_debut']}–${item['heure_fin']} · Salle ${item['salle']}' : ' · Horaire et salle à fixer'}',
              ),
              isThreeLine: true,
              trailing: OutlinedButton.icon(
                onPressed: () => _scheduleNormalSession(item),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(scheduled ? 'Modifier' : 'Planifier'),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _scheduleNormalSession(Map<String, dynamic> item) async {
    final room = TextEditingController(text: '${item['salle'] ?? ''}');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existingDate = DateTime.tryParse('${item['date_evaluation'] ?? ''}');
    var date = existingDate == null || existingDate.isBefore(today)
        ? today
        : DateTime(existingDate.year, existingDate.month, existingDate.day);
    var start = const TimeOfDay(hour: 8, minute: 0);
    var end = const TimeOfDay(hour: 10, minute: 0);
    var validationMessage = '';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Planifier la session · ${item['code_ue']}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['code_classe']} · ${item['code_m']} · Session normale'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 730)),
                    );
                    if (selected != null) setDialog(() => date = selected);
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('Date : ${date.toIso8601String().substring(0, 10)}'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showTimePicker(
                            context: dialogContext,
                            initialTime: start,
                          );
                          if (selected != null) setDialog(() => start = selected);
                        },
                        child: Text('Début : ${start.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showTimePicker(
                            context: dialogContext,
                            initialTime: end,
                          );
                          if (selected != null) setDialog(() => end = selected);
                        },
                        child: Text('Fin : ${end.format(context)}'),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: room,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: 'Salle (code alphanumérique)',
                    hintText: 'A101 ou LAB-02',
                    helperText: 'Lettres, chiffres et tirets.',
                  ),
                ),
                if (validationMessage.isNotEmpty)
                  Text(
                    validationMessage,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final startMinutes = start.hour * 60 + start.minute;
                final endMinutes = end.hour * 60 + end.minute;
                final normalizedRoom = room.text.trim().toUpperCase();
                if (endMinutes <= startMinutes) {
                  setDialog(() => validationMessage = 'L’heure de fin doit suivre l’heure de début.');
                  return;
                }
                if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{0,31}$').hasMatch(normalizedRoom)) {
                  setDialog(() => validationMessage = 'Saisissez un code de salle simple, par exemple A101 ou LAB-02.');
                  return;
                }
                Navigator.pop(dialogContext, {
                  'date': date.toIso8601String().substring(0, 10),
                  'start': _timeForApi(start),
                  'end': _timeForApi(end),
                  'room': normalizedRoom,
                });
              },
              child: const Text('Enregistrer et notifier'),
            ),
          ],
        ),
      ),
    );
    room.dispose();
    if (result == null) return;
    final evaluationId = (item['evaluation_id'] as num?)?.toInt();
    if (evaluationId == null) return;
    await _mutate(
      () => widget.api.agentScheduleNormalExam(
        evaluationId,
        date: result['date']!,
        start: result['start']!,
        end: result['end']!,
        room: result['room']!,
      ),
    );
  }

  String _timeForApi(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Widget _retakes(List data) {
    final sessions = _maps(data[0]);
    final opportunities = _maps(data[1]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Rattrapages à préparer',
                subtitle: 'Une grille transmise permet d’anticiper une session ; les étudiants admissibles sont confirmés après publication.',
              ),
              if (opportunities.isEmpty)
                const EmptyState(
                  'Aucune UE à préparer',
                  'Les UE avec des grilles de notes transmises apparaîtront ici.',
                ),
              ...opportunities.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(
                    '${item['code_classe']} · ${item['code_ue']} · S${item['semestre']}',
                  ),
                  subtitle: Text(
                    '${item['intitule_ue']} · ${item['eligibilite_confirmee'] == true ? '${item['etudiants_eligibles']} étudiant(s) éligible(s)' : 'Éligibilité à confirmer après publication'}',
                  ),
                  trailing: Text('${item['credits']} crédits'),
                ),
              ),
              const Divider(height: 24),
              const SectionTitle('Sessions programmées'),
              if (sessions.isEmpty)
                const EmptyState(
                  'Aucune session',
                  'Les sessions programmées pour une UE précise apparaîtront ici.',
                ),
              ...sessions.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item['code_ue'] ?? 'Session générale'} · ${item['code_classe']}',
                  ),
                  subtitle: Text(
                    '${item['intitule_ue'] ?? item['libelle']} · ${item['date_session']}'
                    '${item['heure_debut'] == null ? '' : ' · ${item['heure_debut']}–${item['heure_fin']} · Salle ${item['salle']}'}'
                    ' · ${item['statut_session']}',
                  ),
                  trailing: _sessionAction(item),
                ),
              ),
              OutlinedButton.icon(
                onPressed: opportunities.isEmpty
                    ? null
                    : () => _createSession(opportunities),
                icon: const Icon(Icons.add),
                label: const Text('Planifier une session'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _sessionAction(Map<String, dynamic> item) {
    final next = switch (item['statut_session']) {
      'PREVUE' => 'OUVERTE',
      'OUVERTE' => 'CLOTUREE',
      _ => null,
    };
    if (next == null) return null;
    return TextButton(
      onPressed: () => _mutate(
        () => widget.api.agentSetRetakeSessionStatus(item['id'] as int, next),
      ),
      child: Text(next == 'OUVERTE' ? 'Ouvrir' : 'Clôturer'),
    );
  }

  Future<void> _createSession(List<Map<String, dynamic>> opportunities) async {
    final label = TextEditingController();
    final date = TextEditingController();
    int opportunityIndex = 0;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Planifier un rattrapage'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: opportunityIndex,
                  decoration: const InputDecoration(
                    labelText: 'UE avec étudiants éligibles',
                  ),
                  items: List.generate(opportunities.length, (index) {
                    final item = opportunities[index];
                    return DropdownMenuItem(
                      value: index,
                      child: Text(
                        '${item['code_classe']} · ${item['code_ue']} · ${item['etudiants_eligibles']} éligible(s)',
                      ),
                    );
                  }),
                  onChanged: (v) => setDialog(() => opportunityIndex = v!),
                ),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(
                    labelText: 'Libellé de session',
                  ),
                ),
                TextField(
                  controller: date,
                  decoration: const InputDecoration(
                    labelText: 'Date (AAAA-MM-JJ)',
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'La liste est calculée à partir des bulletins officiels courants et du barème de rattrapage.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'classe_id': opportunities[opportunityIndex]['classe_id'],
                'ue_id': opportunities[opportunityIndex]['ue_id'],
                'libelle': label.text.trim(),
                'date_session': date.text.trim(),
              }),
              child: const Text('Planifier'),
            ),
          ],
        ),
      ),
    );
    label.dispose();
    date.dispose();
    if (result == null ||
        result['libelle'] == '' ||
        result['date_session'] == '')
      return;
    await _mutate(() => widget.api.agentCreateRetakeSession(result));
  }

  Widget _requests(List data) {
    final requests = _maps(data[0]);
    final teachers = _maps(data[1])
        .where(
          (item) =>
              item['role'] == 'ENSEIGNANT' &&
              item['actif'] == true &&
              item['enseignant_id'] != null,
        )
        .toList();
    if (requests.isEmpty)
      return const EmptyState(
        'Aucune requête à transmettre',
        'Les requêtes envoyées à la cellule apparaîtront ici.',
      );
    return Column(
      children: requests
          .map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      '${request['type_requete']} · ${request['matricule']}',
                      subtitle:
                          '${request['code_classe']} · ${request['code_ue']} · ${request['statut_requete']}',
                    ),
                    Text(
                      '${request['objet'] ?? ''}\n${request['description'] ?? ''}',
                    ),
                    const SizedBox(height: 12),
                    if (request['statut_requete'] == 'SOUMISE' &&
                        request['matiere_id'] != null &&
                        teachers.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _routeRequest(request, teachers),
                          icon: const Icon(Icons.forward_to_inbox),
                          label: const Text('Transmettre à l’enseignant'),
                        ),
                      ),
                    if (request['matiere_id'] == null)
                      const Notice(
                        'Le dossier ne précise pas l’élément constitutif concerné. Il doit être complété avant transmission.',
                        warning: true,
                      ),
                    if (teachers.isEmpty)
                      const Notice(
                        'Aucun enseignant actif dans le périmètre pour traiter cette requête.',
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _routeRequest(
    Map<String, dynamic> request,
    List<Map<String, dynamic>> teachers,
  ) async {
    int teacherId = teachers.first['enseignant_id'] as int;
    final reason = TextEditingController(
      text:
          'Veuillez examiner cette requête dans votre affectation pédagogique.',
    );
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Transmettre la requête'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: teacherId,
                  decoration: const InputDecoration(labelText: 'Enseignant'),
                  items: teachers
                      .map(
                        (v) => DropdownMenuItem(
                          value: v['enseignant_id'] as int,
                          child: Text('${v['prenom']} ${v['nom']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => teacherId = v!),
                ),
                TextField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motif de transmission (facultatif)',
                    helperText: 'Si renseigné, 8 caractères minimum.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final value = reason.text.trim();
                if (value.isEmpty || value.length >= 8) {
                  Navigator.pop(context, (teacherId, value));
                }
              },
              child: const Text('Transmettre'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (result == null) return;
    await _mutate(
      () => widget.api.agentRouteRequest(
        request['id'] as int,
        teacherId: result.$1,
        reason: result.$2,
      ),
    );
  }

  Future<void> _showAccountProfile(Map<String, dynamic> account) async {
    final classes = (account['classes'] as List? ?? [])
        .map((value) => '$value')
        .toList();
    final teaching = (account['enseignements'] as List? ?? [])
        .map((value) => '$value')
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${account['prenom'] ?? ''} ${account['nom'] ?? ''}'.trim(),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rôle : ${account['role']}'),
                Text('Identifiant : ${account['login']}'),
                if (account['matricule'] != null)
                  Text('Matricule : ${account['matricule']}'),
                if (account['eid'] != null)
                  Text('Code enseignant : ${account['eid']}'),
                if (account['courriel'] != null)
                  Text('Courriel : ${account['courriel']}'),
                if (account['fonction_enseignant'] != null)
                  Text('Fonction déclarée : ${account['fonction_enseignant']}'),
                const SizedBox(height: 16),
                Text(
                  account['role'] == 'ETUDIANT'
                      ? 'Classes rattachées'
                      : 'Classes enseignées',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (classes.isEmpty) const Text('Aucune classe rattachée.'),
                ...classes.map((value) => Text('• $value')),
                if (account['role'] == 'ENSEIGNANT') ...[
                  const SizedBox(height: 16),
                  Text(
                    'Affectations pédagogiques',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (teaching.isEmpty)
                    const Text('Aucune affectation enregistrée.'),
                  ...teaching.map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $value'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (account['gestionnable'] != false && account['role'] != 'AGENT')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _editAccount(account);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAccount(Map<String, dynamic> account) async {
    final nom = TextEditingController(text: '${account['nom'] ?? ''}');
    final prenom = TextEditingController(text: '${account['prenom'] ?? ''}');
    final courriel = TextEditingController(
      text: '${account['courriel'] ?? ''}',
    );
    final motif = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nom,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                TextField(
                  controller: prenom,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                TextField(
                  controller: courriel,
                  decoration: const InputDecoration(labelText: 'Courriel'),
                ),
                TextField(
                  controller: motif,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motif de modification (facultatif)',
                    helperText: 'Si renseigné, 8 caractères minimum.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final optionalMotif = motif.text.trim();
              if (nom.text.trim().isNotEmpty &&
                  prenom.text.trim().isNotEmpty &&
                  (optionalMotif.isEmpty || optionalMotif.length >= 8)) {
                Navigator.pop(context, {
                  'nom': nom.text.trim(),
                  'prenom': prenom.text.trim(),
                  'courriel': courriel.text.trim(),
                  'motif': motif.text.trim(),
                });
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    nom.dispose();
    prenom.dispose();
    courriel.dispose();
    motif.dispose();
    if (result == null) return;
    await _mutate(
      () => widget.api.agentUpdateAccount(account['id'] as int, {
        ...result,
        'courriel': result['courriel']!.isEmpty ? null : result['courriel'],
      }),
    );
  }

  Future<String?> _reasonDialog(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Motif (facultatif)',
            helperText: 'Si renseigné, 8 caractères minimum.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty || value.length >= 8) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) {
        toast(context, 'Opération enregistrée.');
        _reload();
      }
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  String _error(Object? error) => error is ApiFailure
      ? error.message
      : 'L’API GNU ne peut pas effectuer cette opération. Vérifiez le serveur puis réessayez.';
}
