import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
    ]),
    'enrollment' => widget.api.agentEnrollments(),
    'academic' => Future.wait([
      widget.api.agentCatalog(),
      widget.api.agentLevels(),
      widget.api.academicYears(),
      widget.api.agentClasses(),
      widget.api.agentAcademicStructure(),
    ]),
    'bulletins' || 'publications' => widget.api.agentClasses(),
    'audit' => widget.api.agentAudit(),
    'retakes' => Future.wait([
      widget.api.agentRetakeSessions(),
      widget.api.agentRetakeOpportunities(),
    ]),
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
        data['peut_publier'] == true
            ? 'Votre compte dispose de l’habilitation distincte de publication. Vérifiez chaque aperçu avant de publier.'
            : 'La publication officielle nécessite une habilitation séparée attribuée par l’administration.',
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
                    'Colonnes CSV : matricule, note sur 20, situation (NUMERIQUE ou ABSENTE).',
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 420,
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
      for (final note in notes) {
        final absent = note['situation_numerisee'] == 'ABSENTE';
        final raw = controllers['${note['matricule']}']!.text.trim().replaceAll(
          ',',
          '.',
        );
        final value = absent ? null : double.tryParse(raw);
        if (!absent && (value == null || value < 0 || value > 20)) {
          toast(
            context,
            'Chaque note numérisée doit être comprise entre 0 et 20.',
          );
          return;
        }
        payload.add({
          'matricule': note['matricule'],
          'situation': absent ? 'ABSENTE' : 'NUMERIQUE',
          'valeur_note': value,
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
        final situation = columns.length > 2 && columns[2].isNotEmpty
            ? columns[2].toUpperCase()
            : columns[1].isEmpty
            ? 'ABSENTE'
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
                    label: const Text('Gérer la structure'),
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
              const SectionTitle('Classes du département'),
              if (classes.isEmpty)
                const EmptyState(
                  'Aucune classe',
                  'Créez une classe à partir d’un niveau qui vous est attribué.',
                ),
              ...classes.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(
                    '${item['code_classe']} · ${item['libelle_niv']}',
                  ),
                  subtitle: Text(
                    '${item['nom_univ']} · ${item['nom_fac']} · ${item['nom_depart']} · ${item['code_f']} · ${item['annee_academique']} · version ${item['version_programme']}',
                  ),
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
              const SectionTitle('Catalogue des UE et EC'),
              if (units.isEmpty)
                const EmptyState(
                  'Catalogue vide',
                  'Les unités créées en brouillon apparaîtront ici.',
                ),
              ...units.map((unit) {
                final children = elements
                    .where((element) => element['ue_id'] == unit['id'])
                    .toList();
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('${unit['code_ue']} · ${unit['intitule_ue']}'),
                  subtitle: Text(
                    '${unit['nom_univ']} · ${unit['nom_fac']} · ${unit['nom_depart']} · ${unit['code_f']} · ${unit['libelle_niv']}${unit['libelle_specialite'] == null ? '' : ' · ${unit['libelle_specialite']}'} · S${unit['numero_semestre']} · ${unit['credit_ue']} crédits · ${unit['statut_catalogue']} · Barème : ${_evaluationProfileLabel(unit['profil_evaluation'])}${unit['profil_propose'] == null ? '' : ' · Proposition à valider : ${_evaluationProfileLabel(unit['profil_propose'])}'}',
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
                        title: Text(
                          '${element['code_m']} · ${element['intitule_matiere']}',
                        ),
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
              }),
              OutlinedButton.icon(
                onPressed: levels.isEmpty ? null : () => _createUnit(levels),
                icon: const Icon(Icons.add),
                label: const Text('Créer une UE'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _manageAcademicStructure(Map<String, dynamic> structure) async {
    final admin = structure['administrateur'] == true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gérer la structure universitaire'),
        content: SizedBox(
          width: 720,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (!admin)
                const Notice(
                  'La création des universités et facultés est réservée à l’administrateur système. Vous pouvez modifier celles de votre département et gérer les filières.',
                  warning: true,
                ),
              _structureSection(
                dialogContext,
                structure,
                'universite',
                'Universités',
                'universites',
                admin,
              ),
              _structureSection(
                dialogContext,
                structure,
                'faculte',
                'Facultés',
                'facultes',
                admin,
              ),
              _structureSection(
                dialogContext,
                structure,
                'departement',
                'Départements',
                'departements',
                admin || _maps(structure['facultes']).isNotEmpty,
              ),
              _structureSection(
                dialogContext,
                structure,
                'filiere',
                'Filières',
                'filieres',
                true,
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
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text('$title (${rows.length})'),
      children: [
        ...rows.map(
          (item) => ListTile(
            title: Text(
              '${item['code_${kind == 'universite'
                  ? 'univ'
                  : kind == 'faculte'
                  ? 'fac'
                  : kind == 'departement'
                  ? 'de'
                  : 'f'}']} · ${item[kind == 'universite'
                  ? 'nom_univ'
                  : kind == 'faculte'
                  ? 'nom_fac'
                  : kind == 'departement'
                  ? 'nom_depart'
                  : 'nom_f']}',
            ),
            trailing: IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editAcademicStructureItem(
                dialogContext,
                structure,
                kind,
                item: item,
              ),
            ),
          ),
        ),
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
      _ => 'code_f',
    };
    final nameKey = switch (kind) {
      'universite' => 'nom_univ',
      'faculte' => 'nom_fac',
      'departement' => 'nom_depart',
      _ => 'nom_f',
    };
    final parentKey = switch (kind) {
      'faculte' => 'universite_id',
      'departement' => 'faculte_id',
      'filiere' => 'departement_id',
      _ => null,
    };
    final parentListKey = switch (kind) {
      'faculte' => 'universites',
      'departement' => 'facultes',
      'filiere' => 'departements',
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
              (parents.first['id'] as num).toInt();
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
                : 'une filière'}',
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
                          : 'Département',
                    ),
                    items: parents
                        .map(
                          (parent) => DropdownMenuItem<int>(
                            value: (parent['id'] as num).toInt(),
                            child: Text(
                              '${parent['code_univ'] ?? parent['code_fac'] ?? parent['code_de']} · ${parent['nom_univ'] ?? parent['nom_fac'] ?? parent['nom_depart']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialog(() => parentId = value),
                  ),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom'),
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

  Future<void> _createClass(
    List<Map<String, dynamic>> levels,
    List<Map<String, dynamic>> years,
  ) async {
    final code = TextEditingController();
    final version = TextEditingController(text: '1');
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
                TextField(
                  controller: version,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Version du programme',
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
                'code_classe': code.text.trim(),
                'niveau_id': level,
                'annee_id': year,
                'version_programme': int.tryParse(version.text),
              }),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    version.dispose();
    if (result == null ||
        result['code_classe'] == '' ||
        result['version_programme'] == null)
      return;
    await _mutate(() => widget.api.agentCreateClass(result));
  }

  Future<void> _createUnit(List<Map<String, dynamic>> levels) async {
    final code = TextEditingController();
    final title = TextEditingController();
    final version = TextEditingController(text: '1');
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
                    controller: version,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Version du programme',
                    ),
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
                'version_programme': int.tryParse(version.text),
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
    version.dispose();
    credit.dispose();
    if (result == null ||
        result['code_ue'] == '' ||
        result['version_programme'] == null ||
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
                  Notice(
                    preview['pret'] == true
                        ? 'Tous les bulletins sont calculables. Vérifiez la prévisualisation avant de publier.'
                        : 'Publication bloquée : ${preview['transmissions_en_attente'] ?? 0} transmission(s) attendent la cellule et ${preview['evaluations_non_verifiees'] ?? 0} évaluation(s) de cette période ne sont pas encore vérifiées par leur enseignant. Les inscriptions et notes doivent aussi être complètes.',
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
                                '${student['nom']} · ${student['matricule']}',
                              ),
                              subtitle: student['pret'] == true
                                  ? Text(
                                      'MGP ${period == 'ANNUELLE' ? 'annuelle' : period} : ${mgp ?? '—'} · ${content?['total_credits'] ?? 0} crédits · ${content?['decision_admission'] ?? ''}',
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
                  if (preview['peut_publier'] != true)
                    const Notice(
                      'Votre compte peut préparer et contrôler les résultats, mais il ne possède pas l’habilitation de publication.',
                      warning: true,
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
      final isAdmin = data['administrateur'] == true;
      final isApproved = data['approuvees'] == true;
      final agents = _maps(data['agents']);
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionTitle('Règles et habilitations de publication'),
                ),
                StatusBadge(
                  isApproved ? 'Règles approuvées' : 'Approbation requise',
                  color: isApproved ? emerald : const Color(0xFFB87516),
                ),
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
              'Rattrapage : ${rules['rattrapage']?['minimum_sur_20']} à ${rules['rattrapage']?['maximum_sur_20_inclus']}/20, ${rules['rattrapage']?['nombre_maximum_sessions']} session(s) maximum.',
            ),
            if (data['approbation'] != null)
              Text(
                'Dernière approbation : ${data['approbation']['par']} · ${data['approbation']['approuve_le']}',
              ),
            if (isAdmin && !isApproved) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _approvePublicationRules(
                  rules['version_moteur']?.toString() ?? 'GNU',
                ),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Approuver ces règles de calcul'),
              ),
            ],
            if (!isAdmin && !isApproved)
              const Notice(
                'Un administrateur système doit approuver les règles avant toute publication officielle.',
                warning: true,
              ),
            if (isAdmin) ...[
              const Divider(height: 28),
              const Text('Agents autorisés à publier les résultats'),
              if (agents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Aucun compte Agent actif.'),
                ),
              ...agents.map((agent) {
                final isCurrentUser =
                    (agent['id'] as num?)?.toInt() ==
                    (widget.api.user?['id'] as num?)?.toInt();
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${agent['nom']} · ${agent['login']}'),
                  subtitle: Text(
                    isCurrentUser
                        ? 'L’administrateur ne peut pas s’attribuer le droit de publication'
                        : agent['autorise'] == true
                        ? 'Habilitation active'
                        : 'Sans droit de publication',
                  ),
                  value: agent['autorise'] == true,
                  onChanged: isCurrentUser
                      ? null
                      : (active) => _setPublicationAuthorization(agent, active),
                );
              }),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _approvePublicationRules(String version) async {
    final approved = await confirm(
      context,
      'Approuver le barème actif ?',
      'Vous confirmez le barème MGP, les seuils d’admission et les règles de rattrapage affichés pour le moteur $version.',
    );
    if (!approved) return;
    await _mutate(
      () => widget.api.agentApprovePublicationRules(
        reason: 'Approbation des règles de calcul $version',
      ),
    );
  }

  Future<void> _setPublicationAuthorization(
    Map<String, dynamic> agent,
    bool active,
  ) async {
    await _mutate(
      () => widget.api.agentSetPublicationAuthorization(
        (agent['id'] as num).toInt(),
        authorized: active,
        reason: active
            ? 'Attribution du droit de publication'
            : 'Retrait du droit de publication',
      ),
    );
  }

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
                    '${item['intitule_ue'] ?? item['libelle']} · ${item['date_session']} · ${item['statut_session']}',
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
