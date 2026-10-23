import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'api_client.dart';
import 'file_download.dart';
import 'ui.dart';

class TeacherAssignmentsPage extends StatefulWidget {
  const TeacherAssignmentsPage({super.key, required this.api});

  final StudentApiClient api;

  @override
  State<TeacherAssignmentsPage> createState() => _TeacherAssignmentsPageState();
}

class _TeacherAssignmentsPageState extends State<TeacherAssignmentsPage> {
  late Future<List<Map<String, dynamic>>> assignments;
  late Future<List<Map<String, dynamic>>> requests;

  @override
  void initState() {
    super.initState();
    assignments = widget.api.teacherAssignments();
    requests = widget.api.teacherRequests();
  }

  void _reload() => setState(() {
    assignments = widget.api.teacherAssignments();
    requests = widget.api.teacherRequests();
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        'Mes affectations',
        'Classes, matières et plans visibles selon vos affectations actives.',
      ),
      const Notice(
        'Configurez le calendrier et les pondérations, saisissez ou importez les notes, puis transmettez-les pour actualiser les résultats provisoires de vos EC.',
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: assignments,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Panel(
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_message(snapshot.error!))),
                  IconButton(
                    onPressed: _reload,
                    tooltip: 'Réessayer',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Panel(
              child: EmptyState(
                'Aucune affectation active',
                'Demandez à un Agent de vous affecter une classe et un élément constitutif actif. Vos évaluations, notes et rattrapages apparaîtront ensuite ici.',
              ),
            );
          }
          return Column(children: items.map(_assignmentCard).toList());
        },
      ),
      const SizedBox(height: 28),
      const SectionTitle(
        'Requêtes qui vous sont transmises',
        subtitle: 'Les décisions sont motivées et communiquées à l’étudiant.',
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: requests,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Panel(child: Text(_message(snapshot.error!)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Panel(
              child: EmptyState(
                'Aucune requête en attente',
                'Les transmissions de la cellule apparaîtront ici.',
              ),
            );
          }
          return Column(children: items.map(_requestCard).toList());
        },
      ),
    ],
  );

  Widget _assignmentCard(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '${item['code_ue'] ?? ''} · ${item['intitule_ue'] ?? ''}',
            subtitle:
                '${item['code_classe'] ?? ''} · ${item['annee_academique'] ?? ''}',
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(
              '${item['code_m'] ?? ''} · ${item['intitule_matiere'] ?? ''}',
            ),
            subtitle: const Text('Affectation active'),
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _scheduleRetake(item),
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Programmer un rattrapage'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _manageRetakes(item),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Candidats et notes'),
                ),
                FilledButton.icon(
                  onPressed: () => _showGradebook(item),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Carnet de notes'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _scheduleRetake(Map<String, dynamic> assignment) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Date de la session de rattrapage',
    );
    if (!mounted || date == null) return;
    final id = assignment['affectation_id'];
    if (id is! num) return;
    final code = '${assignment['code_m'] ?? assignment['code_ue'] ?? 'Cours'}';
    try {
      await widget.api.teacherCreateRetakeSession(
        id.toInt(),
        label: 'Rattrapage $code',
        date: date.toIso8601String().substring(0, 10),
      );
      if (mounted) toast(context, 'Session de rattrapage programmée.');
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Future<void> _manageRetakes(Map<String, dynamic> assignment) async {
    final id = assignment['affectation_id'];
    if (id is! num) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _TeacherRetakesDialog(
        api: widget.api,
        assignment: assignment,
        assignmentId: id.toInt(),
      ),
    );
    if (mounted) _reload();
  }

  Widget _requestCard(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '${item['type_requete']} · ${item['matricule']}',
            subtitle: [
              item['code_classe'],
              item['code_ue'],
              item['code_m'],
              item['type_eval'],
              item['date_evaluation'],
              item['session_rattrapage'],
              item['date_session_rattrapage'],
            ].where((value) => value != null).join(' · '),
          ),
          Text('${item['objet']}\n${item['description']}'),
          const SizedBox(height: 8),
          Text(
            'Transmission de la cellule : ${item['motif_transmission'] ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (item['type_requete'] == 'NOTE_MANQUANTE' &&
              item['action_decision'] == 'AUTORISER_EVALUATION') ...[
            const Text(
              'Correction autorisée. Complétez la note ci-dessous, puis retransmettez-la pour contrôle et vérification.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showGradebook(item, request: item),
              icon: const Icon(Icons.edit_note),
              label: const Text('Corriger dans le carnet'),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _decideRequest(item, 'AUTORISER_EVALUATION'),
                  child: Text(
                    item['type_requete'] == 'NOTE_MANQUANTE'
                        ? 'Autoriser la correction'
                        : item['type_requete'] == 'CANDIDATURE_RATTRAPAGE'
                        ? 'Autoriser la candidature'
                        : 'Autoriser une évaluation',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _decideRequest(item, 'REJETER'),
                  child: const Text('Rejeter la requête'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _decideRequest(
    Map<String, dynamic> item,
    String decision,
  ) async {
    final reason = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          decision == 'REJETER'
              ? 'Rejeter la requête'
              : item['type_requete'] == 'CANDIDATURE_RATTRAPAGE'
              ? 'Autoriser le rattrapage'
              : 'Autoriser une évaluation',
        ),
        content: TextField(
          controller: reason,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motif de la décision (facultatif)',
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
              final value = reason.text.trim();
              if (value.isEmpty || value.length >= 8) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Transmettre la décision'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (!mounted || result == null) return;
    try {
      await widget.api.teacherDecideRequest(
        item['id'] as int,
        decision: decision,
        reason: result,
      );
      if (mounted) {
        toast(context, 'Décision transmise à l’étudiant.');
        _reload();
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Future<void> _showGradebook(
    Map<String, dynamic> assignment, {
    Map<String, dynamic>? request,
  }) async {
    final id = (assignment['affectation_id'] as num?)?.toInt();
    if (id == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: _GradebookDialog(
          api: widget.api,
          assignment: assignment,
          assignmentId: id,
          request: request,
        ),
      ),
    );
    if (mounted) _reload();
  }

  String _message(Object error) => error is ApiFailure
      ? error.message
      : 'Le serveur ne peut pas charger les affectations. Réessayez.';
}

class _TeacherRetakesDialog extends StatefulWidget {
  const _TeacherRetakesDialog({
    required this.api,
    required this.assignment,
    required this.assignmentId,
  });

  final StudentApiClient api;
  final Map<String, dynamic> assignment;
  final int assignmentId;

  @override
  State<_TeacherRetakesDialog> createState() => _TeacherRetakesDialogState();
}

class _TeacherRetakesDialogState extends State<_TeacherRetakesDialog> {
  late Future<List<Map<String, dynamic>>> data;
  final Map<String, TextEditingController> values = {};
  final Map<String, bool> absences = {};

  @override
  void initState() {
    super.initState();
    data = widget.api.teacherRetakeCandidates(widget.assignmentId);
  }

  @override
  void dispose() {
    for (final controller in values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void reload() => setState(() {
    data = widget.api.teacherRetakeCandidates(widget.assignmentId);
  });

  String _message(Object error) => error is ApiFailure
      ? error.message
      : 'Le serveur ne peut pas charger les candidatures de rattrapage. Réessayez.';

  String _key(int evaluationId, String matricule) => '$evaluationId:$matricule';

  TextEditingController _controller(int evaluationId, Map student) {
    final key = _key(evaluationId, '${student['matricule']}');
    return values.putIfAbsent(
      key,
      () =>
          TextEditingController(text: student['valeur_note']?.toString() ?? ''),
    );
  }

  bool _absent(int evaluationId, Map student) {
    final key = _key(evaluationId, '${student['matricule']}');
    return absences.putIfAbsent(key, () => student['situation'] == 'ABSENTE');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Rattrapages · ${widget.assignment['code_m']}'),
    content: SizedBox(
      width: 880,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text(_message(snapshot.error!));
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data!.isEmpty) {
            return const EmptyState(
              'Aucune candidature autorisée',
              'Les étudiants autorisés par vous pour une session apparaîtront ici.',
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: snapshot.data!.map(_sessionCard).toList(),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ],
  );

  Widget _sessionCard(Map<String, dynamic> session) {
    final evaluations = (session['evaluations'] as List? ?? [])
        .whereType<Map>()
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              '${session['libelle']} · ${session['date_session']}',
              subtitle:
                  'Session ${session['statut_session']} · ${session['candidatures_en_attente']} candidature(s) à préparer',
            ),
            if ((session['candidatures_en_attente'] as num? ?? 0) > 0)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: session['statut_session'] == 'OUVERTE'
                      ? () => _createEvaluations((session['id'] as num).toInt())
                      : null,
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  label: const Text('Préparer les épreuves autorisées'),
                ),
              ),
            ...evaluations.map(_evaluationCard),
          ],
        ),
      ),
    );
  }

  Widget _evaluationCard(Map evaluation) {
    final evaluationId = (evaluation['evaluation_id'] as num?)?.toInt();
    final students = (evaluation['etudiants'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final transmission = evaluation['transmission'] as Map?;
    final transmissionStatus = transmission?['statut']?.toString();
    final locked = [
      'TRANSMISE',
      'A_VERIFIER',
      'VERIFIEE',
    ].contains(transmissionStatus);
    if (evaluationId == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Origine SN ${evaluation['evaluation_origine_id']} · préparez l’épreuve après la date de la session.',
        ),
      );
    }
    final ready =
        students.isNotEmpty &&
        students.every((student) {
          final absent = _absent(evaluationId, student);
          return absent ||
              double.tryParse(
                    _controller(
                      evaluationId,
                      student,
                    ).text.replaceAll(',', '.'),
                  ) !=
                  null;
        });
    return ExpansionTile(
      title: Text('Épreuve de rattrapage · ${students.length} candidat(s)'),
      subtitle: Text(
        'Évaluation $evaluationId · ${transmission?['statut'] ?? 'Brouillon'}',
      ),
      children: [
        ...students.map(
          (student) => ListTile(
            title: Text('${student['matricule']} · ${student['nom']}'),
            subtitle: Text(
              [
                '${student['statut_candidature']}',
                if (student['situation_numerisee'] != null)
                  'Cellule : ${student['situation_numerisee'] == 'NUMERIQUE' ? '${student['valeur_numerisee']} /20' : student['situation_numerisee']}',
              ].join(' · '),
            ),
            trailing: SizedBox(
              width: 250,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller(evaluationId, student),
                      enabled: !locked && !_absent(evaluationId, student),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Note /20'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Checkbox(
                    value: _absent(evaluationId, student),
                    onChanged: locked
                        ? null
                        : (value) => setState(() {
                            absences[_key(
                                  evaluationId,
                                  '${student['matricule']}',
                                )] =
                                value == true;
                            if (value == true)
                              _controller(evaluationId, student).clear();
                          }),
                  ),
                  const Text('Absent'),
                ],
              ),
            ),
          ),
        ),
        if (!locked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _saveGrades(evaluationId, students),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer les notes'),
                ),
                FilledButton.icon(
                  onPressed: ready ? () => _transmit(evaluationId) : null,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Transmettre à la cellule'),
                ),
              ],
            ),
          ),
        if (transmissionStatus == 'A_VERIFIER')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: transmission?['id'] is num
                      ? () => _verifyRetakeTransmission(
                          (transmission!['id'] as num).toInt(),
                          'VERIFIER',
                        )
                      : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Confirmer la numérisation'),
                ),
                OutlinedButton.icon(
                  onPressed: transmission?['id'] is num
                      ? () => _verifyRetakeTransmission(
                          (transmission!['id'] as num).toInt(),
                          'CORRIGER',
                        )
                      : null,
                  icon: const Icon(Icons.reply_outlined),
                  label: const Text('Demander une correction'),
                ),
              ],
            ),
          ),
        if (locked)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Circuit de contrôle : ${transmission?['statut']}. Les notes sont verrouillées jusqu’au retour de la cellule.',
            ),
          ),
      ],
    );
  }

  Future<void> _createEvaluations(int sessionId) async {
    try {
      await widget.api.teacherCreateRetakeEvaluations(
        widget.assignmentId,
        sessionId,
      );
      if (mounted) {
        toast(context, 'Épreuves préparées.');
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Future<void> _saveGrades(int evaluationId, List<Map> students) async {
    final grades = <Map<String, dynamic>>[];
    for (final student in students) {
      final absent = _absent(evaluationId, student);
      final value = double.tryParse(
        _controller(evaluationId, student).text.replaceAll(',', '.'),
      );
      if (!absent && (value == null || value < 0 || value > 20)) {
        toast(context, 'Chaque note doit être comprise entre 0 et 20.');
        return;
      }
      grades.add({
        'matricule': student['matricule'],
        'situation': absent ? 'ABSENTE' : 'NUMERIQUE',
        'valeur_note': absent ? null : value,
        'version_note': student['version_note'],
      });
    }
    try {
      await widget.api.teacherSaveRetakeGrades(
        widget.assignmentId,
        evaluationId,
        grades: grades,
        reason: 'Saisie des notes de rattrapage',
      );
      if (mounted) {
        toast(context, 'Notes enregistrées en brouillon.');
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Future<void> _transmit(int evaluationId) async {
    try {
      await widget.api.teacherTransmitGrades(
        widget.assignmentId,
        evaluationId,
        reason: 'Transmission des notes de rattrapage',
      );
      if (mounted) {
        toast(context, 'Notes transmises à la cellule.');
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Future<void> _verifyRetakeTransmission(
    int transmissionId,
    String decision,
  ) async {
    try {
      await widget.api.teacherDecideGradeTransmission(
        transmissionId,
        decision: decision,
        reason: decision == 'VERIFIER'
            ? 'Numérisation de la grille de rattrapage vérifiée'
            : 'Correction requise après vérification de la grille de rattrapage',
      );
      if (mounted) {
        toast(
          context,
          decision == 'VERIFIER'
              ? 'Notes vérifiées et résultats recalculés.'
              : 'La grille est retournée à la cellule.',
        );
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }
}

class _GradebookDialog extends StatefulWidget {
  const _GradebookDialog({
    required this.api,
    required this.assignment,
    required this.assignmentId,
    this.request,
  });
  final StudentApiClient api;
  final Map<String, dynamic> assignment;
  final int assignmentId;
  final Map<String, dynamic>? request;
  @override
  State<_GradebookDialog> createState() => _GradebookDialogState();
}

class _GradebookDialogState extends State<_GradebookDialog> {
  late Future<Map<String, dynamic>> data;
  int gradebookRevision = 0;
  late String provisionalPeriod;
  @override
  void initState() {
    super.initState();
    provisionalPeriod = widget.assignment['numero_semestre']?.toString() == '2'
        ? 'S2'
        : 'S1';
    data = _loadGradebook();
  }

  Future<Map<String, dynamic>> _loadGradebook() async {
    return widget.api.teacherGradebook(widget.assignmentId);
  }

  void reload() => setState(() {
    gradebookRevision++;
    data = _loadGradebook();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.request == null
            ? 'Carnet · ${widget.assignment['code_ue']}'
            : 'Correction · ${widget.request!['matricule']} · ${widget.request!['type_eval']}',
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final book = snapshot.data!;
        final allStudents = (book['etudiants'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final targetMatricule = widget.request?['matricule']
            ?.toString()
            .trim()
            .toUpperCase();
        final students = widget.request == null
            ? allStudents
            : allStudents
                  .where(
                    (student) =>
                        '${student['matricule']}'.trim().toUpperCase() ==
                        targetMatricule,
                  )
                  .toList();
        final plan = book['plan'] as Map? ?? {};
        final allEvaluations = (plan['composantes'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final targetEvaluationId = (widget.request?['evaluation_id'] as num?)
            ?.toInt();
        final evaluations = widget.request == null
            ? allEvaluations
            : allEvaluations
                  .where(
                    (evaluation) =>
                        (evaluation['evaluation_id'] as num?)?.toInt() ==
                        targetEvaluationId,
                  )
                  .toList();
        const evaluationOrder = {'CC': 0, 'TP': 1, 'TPE': 2, 'SN': 3};
        evaluations.sort((a, b) {
          final byType = (evaluationOrder[a['type_eval']] ?? 4).compareTo(
            evaluationOrder[b['type_eval']] ?? 4,
          );
          return byType != 0
              ? byType
              : '${a['date_evaluation']}'.compareTo('${b['date_evaluation']}');
        });
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (students.any(
                    (student) => student['fiche_academique_disponible'] == true,
                  ))
                    ...students
                        .where(
                          (student) =>
                              student['fiche_academique_disponible'] == true,
                        )
                        .map(
                          (student) => OutlinedButton.icon(
                            onPressed: () => _downloadAcademicSheet(student),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: Text('Fiche · ${student['matricule']}'),
                          ),
                        ),
                  Chip(
                    avatar: const Icon(Icons.groups_outlined, size: 18),
                    label: Text('${students.length} étudiant(s) inscrit(s)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: students.isEmpty
                        ? null
                        : () => _exportCsv(students, evaluations),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Exporter CSV pour Excel'),
                  ),
                  if (widget.request == null)
                    OutlinedButton.icon(
                      onPressed:
                          students.isEmpty || book['profil_evaluation'] == null
                          ? null
                          : () => _importWholeGradebook(evaluations),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Importer le fichier de la classe'),
                    ),
                  OutlinedButton.icon(
                    onPressed: students.isEmpty
                        ? null
                        : () => _exportPdf(students, evaluations),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Exporter PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: students.isEmpty || evaluations.isEmpty
                        ? null
                        : () => _exportMinutes(students, evaluations),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Procès-verbal des notes'),
                  ),
                  ...evaluations.map(_transmissionAction),
                  DropdownButton<String>(
                    value: provisionalPeriod,
                    items: [
                      DropdownMenuItem(
                        value: 'S${widget.assignment['numero_semestre'] ?? 1}',
                        child: Text(
                          'Résultat S${widget.assignment['numero_semestre'] ?? 1}',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ANNUELLE',
                        child: const Text('Résultat annuel'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => provisionalPeriod = value);
                        _showProvisionals(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            if (book['profil_evaluation'] == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: MaterialBanner(
                  content: Text(
                    'Aucun barème officiel n’est défini pour cette UE. Demandez à la cellule de choisir le profil dans le catalogue avant de saisir ou importer les notes.',
                  ),
                  actions: [SizedBox.shrink()],
                ),
              ),
            Expanded(
              child: students.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          widget.request == null
                              ? 'Aucun étudiant inscrit et validé dans cette UE pour cette classe. Les inscriptions validées apparaîtront ici.'
                              : 'L’étudiant lié à cette requête est introuvable dans le carnet. Actualisez la page et vérifiez l’affectation.',
                        ),
                      ),
                    )
                  : evaluations.isEmpty
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_note_outlined, size: 42),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucune composante de note disponible',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.request == null
                                      ? 'Le carnet affiche les évaluations prévues pour cette matière. Importez le fichier de notes préconfiguré associé à cette UE ou faites enregistrer son calendrier par la cellule de scolarité.'
                                      : 'L’évaluation liée à cette requête n’est plus présente dans le plan actif. Vérifiez le plan de notes avant de poursuivre.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : _GradebookGrid(
                      key: ValueKey('gradebook-grid-$gradebookRevision'),
                      api: widget.api,
                      assignmentId: widget.assignmentId,
                      students: students,
                      evaluations: evaluations,
                      isCorrection: widget.request != null,
                      onSaved: reload,
                    ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _downloadAcademicSheet(Map<String, dynamic> student) async {
    try {
      final bytes = await widget.api.teacherDownloadAcademicSheet(
        assignmentId: widget.assignmentId,
        registrationId: (student['inscription_classe_id'] as num).toInt(),
      );
      await downloadFile('fiche-academique-${student['matricule']}.pdf', bytes);
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

  Widget _transmissionAction(Map<String, dynamic> evaluation) {
    final transmission = evaluation['transmission'] as Map?;
    final status = transmission?['statut']?.toString();
    final id = (evaluation['evaluation_id'] as num?)?.toInt();
    if (id == null) return const SizedBox.shrink();
    if (status == 'A_VERIFIER' && transmission?['id'] is num) {
      return OutlinedButton.icon(
        onPressed: () =>
            _verifyTransmission((transmission!['id'] as num).toInt()),
        icon: const Icon(Icons.fact_check_outlined),
        label: Text('Vérifier ${evaluation['type_eval']}'),
      );
    }
    if (status == 'VERIFIEE' && evaluation['correction_autorisee'] == true) {
      return OutlinedButton.icon(
        onPressed: evaluation['correction_prete'] == true
            ? () => _transmitEvaluation(id, evaluation['type_eval'].toString())
            : null,
        icon: const Icon(Icons.send_outlined),
        label: Text(
          evaluation['correction_prete'] == true
              ? 'Transmettre la correction · ${evaluation['type_eval']}'
              : 'Correction en cours · ${evaluation['type_eval']}',
        ),
      );
    }
    if (status == 'TRANSMISE' || status == 'VERIFIEE') {
      return Chip(
        label: Text(
          '${evaluation['type_eval']} · ${_transmissionLabel(status)}',
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: canTransmit(status)
          ? () => _transmitEvaluation(id, evaluation['type_eval'].toString())
          : null,
      icon: const Icon(Icons.send_outlined),
      label: Text('Transmettre ${evaluation['type_eval']}'),
    );
  }

  Future<void> _importWholeGradebook(
    List<Map<String, dynamic>> evaluations,
  ) async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv', 'txt'],
      withData: true,
    );
    if (!mounted || selected == null || selected.files.single.bytes == null) {
      return;
    }
    try {
      final response = await widget.api.teacherPreviewGradebookImport(
        widget.assignmentId,
        filename: selected.files.single.name,
        file: selected.files.single.bytes!,
      );
      final data = response['data'] as Map;
      final weights = data['ponderations'] as Map?;
      final columns = (data['colonnes'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final importedTypes = columns
          .map((row) => '${row['type_eval']}')
          .toList();
      final imported = (data['notes'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final errors = (data['erreurs'] as List? ?? [])
          .whereType<Map>()
          .map((row) => 'Ligne ${row['ligne']} : ${row['message']}')
          .join('\n');
      if (weights == null) {
        if (mounted) {
          toast(
            context,
            'Les colonnes ne correspondent pas à une grille officielle.',
          );
        }
        return;
      }
      final currentProfileTypes = evaluations
          .map((row) => '${row['type_eval']}')
          .toSet();
      final importedProfileTypes = importedTypes.toSet();
      if (currentProfileTypes.isEmpty ||
          currentProfileTypes.length != importedProfileTypes.length ||
          !currentProfileTypes.containsAll(importedProfileTypes)) {
        if (mounted) {
          final profile = _profileCodeFromWeights(weights);
          if (profile == null) {
            toast(
              context,
              'La grille détectée n’est pas une grille officielle connue.',
            );
          } else {
            await widget.api.teacherProposeEvaluationProfile(
              widget.assignmentId,
              profile,
            );
            if (!mounted) return;
            toast(
              context,
              'Proposition ${weights.entries.map((e) => '${e.key} ${e.value}%').join(' · ')} transmise à la cellule. L’import sera disponible après validation.',
            );
          }
        }
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vérifier le fichier de la classe'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Text(
                '${data['importables']} étudiant(s) importable(s) sur ${data['total']}.\nColonnes reconnues : ${importedTypes.join(' · ')}.\nGrille détectée : ${weights.entries.map((e) => '${e.key} ${e.value}%').join(' · ')}.\nLes cellules vides sont ignorées. Les notes seront enregistrées en brouillon.${errors.isEmpty ? '' : '\n\n$errors'}',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: imported.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Importer et enregistrer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final refreshed = await widget.api.teacherGradebook(widget.assignmentId);
      final activeEvaluations =
          ((refreshed['plan'] as Map?)?['composantes'] as List? ?? [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
      final studentsByMatricule = {
        for (final student
            in (refreshed['etudiants'] as List? ?? []).whereType<Map>())
          '${student['matricule']}'.trim().toUpperCase(): student,
      };
      final occurrences = <String, int>{};
      for (final column in columns) {
        final type = '${column['type_eval']}';
        final occurrence = occurrences.update(
          type,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        final evaluation = activeEvaluations
            .where((row) => row['type_eval'] == type)
            .skip(occurrence - 1)
            .firstOrNull;
        if (evaluation == null) {
          throw StateError('Composante $type introuvable après import.');
        }
        final notes = <Map<String, dynamic>>[];
        for (final studentRow in imported) {
          final matricule = '${studentRow['matricule']}'.trim().toUpperCase();
          final student = studentsByMatricule[matricule];
          if (student == null) continue;
          final mark = (studentRow['notes'] as List? ?? [])
              .whereType<Map>()
              .where((row) => row['index'] == column['index'])
              .firstOrNull;
          if (mark == null) continue;
          final existing = (student['notes'] as List? ?? [])
              .whereType<Map>()
              .where(
                (row) => row['evaluation_id'] == evaluation['evaluation_id'],
              )
              .firstOrNull;
          notes.add({
            'matricule': matricule,
            'situation': mark['situation'],
            'valeur_note': mark['valeur_note'],
            if (existing?['version_note'] is num &&
                (existing!['version_note'] as num) > 0)
              'version_note': existing['version_note'],
          });
        }
        if (notes.isNotEmpty) {
          await widget.api.teacherSaveGrades(
            widget.assignmentId,
            (evaluation['evaluation_id'] as num).toInt(),
            grades: notes,
          );
        }
      }
      if (mounted) {
        toast(
          context,
          '${imported.length} étudiant(s) importé(s) en brouillon.',
        );
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

  bool canTransmit(String? status) => status == null || status == 'A_CORRIGER';

  String? _profileCodeFromWeights(Map<dynamic, dynamic> weights) {
    final profile = <String, double>{
      for (final entry in weights.entries)
        '${entry.key}'.toUpperCase(): (entry.value as num).toDouble(),
    };
    if (profile.length == 2 && profile['CC'] == 30 && profile['SN'] == 70) {
      return 'CC_SN';
    }
    if (profile.length == 3 &&
        profile['CC'] == 20 &&
        profile['TP'] == 30 &&
        profile['SN'] == 50) {
      return 'CC_TP_SN';
    }
    if (profile.length == 3 &&
        profile['CC'] == 20 &&
        profile['TPE'] == 20 &&
        profile['SN'] == 60) {
      return 'CC_TPE_SN';
    }
    return null;
  }

  String _transmissionLabel(String? status) => switch (status) {
    'TRANSMISE' => 'Envoyée à la cellule',
    'A_VERIFIER' => 'À vérifier',
    'VERIFIEE' => 'Vérifiée',
    'A_CORRIGER' => 'À corriger',
    _ => 'Brouillon',
  };

  Future<void> _transmitEvaluation(int evaluationId, String type) async {
    final why = await _reasonDialog('Transmettre les notes · $type');
    if (!mounted || why == null) return;
    try {
      await widget.api.teacherTransmitGrades(
        widget.assignmentId,
        evaluationId,
        reason: why,
      );
      if (mounted) {
        toast(context, 'Notes transmises à la cellule informatique.');
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

  Future<void> _verifyTransmission(int transmissionId) async {
    final why = await _reasonDialog('Vérifier le retour de la cellule');
    if (!mounted || why == null) return;
    try {
      await widget.api.teacherDecideGradeTransmission(
        transmissionId,
        decision: 'VERIFIER',
        reason: why,
      );
      if (mounted) {
        toast(
          context,
          'Notes vérifiées et intégrées aux résultats provisoires.',
        );
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

  Future<void> _exportCsv(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> evaluations,
  ) async {
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final lines = <String>[
      'Matricule;Nom;Évaluation;Poids (%);Note (/20);Situation;Statut',
    ];
    for (final student in students) {
      final notes = (student['notes'] as List? ?? []).whereType<Map>();
      for (final evaluation in evaluations) {
        final note = notes
            .cast<Map>()
            .where((n) => n['evaluation_id'] == evaluation['evaluation_id'])
            .firstOrNull;
        lines.add(
          [
            student['matricule'],
            student['nom'],
            evaluation['type_eval'],
            evaluation['poids_evaluation'],
            note?['valeur_note'],
            note?['situation'] ?? 'MANQUANTE',
            note?['statut_note'] ?? 'ABSENTE',
          ].map(cell).join(';'),
        );
      }
    }
    await FilePicker.platform.saveFile(
      fileName: 'notes-${widget.assignment['code_ue']}.csv',
      bytes: Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}')),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
  }

  Future<void> _exportPdf(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> evaluations,
  ) async {
    final rows = <List<String>>[
      ['Matricule', 'Étudiant', 'Évaluation', 'Poids', 'Note /20', 'Situation'],
    ];
    for (final student in students) {
      final notes = (student['notes'] as List? ?? []).whereType<Map>();
      for (final evaluation in evaluations) {
        final note = notes
            .cast<Map>()
            .where((n) => n['evaluation_id'] == evaluation['evaluation_id'])
            .firstOrNull;
        rows.add([
          '${student['matricule'] ?? ''}',
          '${student['nom'] ?? ''}',
          '${evaluation['type_eval'] ?? ''}',
          '${evaluation['poids_evaluation'] ?? ''}%',
          '${note?['valeur_note'] ?? '—'}',
          '${note?['situation'] ?? 'MANQUANTE'}',
        ]);
      }
    }
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Carnet de notes — ${widget.assignment['code_ue']} · ${widget.assignment['code_classe'] ?? widget.assignment['classe'] ?? ''}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Document de travail enseignant — les notes ne sont publiées qu’après transmission et validation institutionnelle.',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    await FilePicker.platform.saveFile(
      fileName: 'notes-${widget.assignment['code_ue']}.pdf',
      bytes: await document.save(),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  }

  Future<void> _exportMinutes(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> evaluations,
  ) async {
    String markFor(Map student, Map evaluation) {
      final note = (student['notes'] as List? ?? [])
          .whereType<Map>()
          .where((row) => row['evaluation_id'] == evaluation['evaluation_id'])
          .firstOrNull;
      if (note == null) return '—';
      if (note['situation'] == 'ABSENTE') return 'ABS';
      final value = note['valeur_note'];
      return value is num ? value.toStringAsFixed(2) : '—';
    }

    final headers = <String>[
      'Matricule',
      'Nom et prénom',
      ...evaluations.map(
        (e) => '${e['type_eval']} (${e['poids_evaluation']}%)',
      ),
      'Total /20',
      'État',
    ];
    final rows = <List<String>>[headers];
    for (final student in students) {
      final notes = (student['notes'] as List? ?? []).whereType<Map>();
      var weighted = 0.0;
      var enteredWeight = 0.0;
      var complete = true;
      for (final evaluation in evaluations) {
        final note = notes
            .where((n) => n['evaluation_id'] == evaluation['evaluation_id'])
            .firstOrNull;
        final value = note?['valeur_note'];
        final weight =
            (evaluation['poids_evaluation'] as num?)?.toDouble() ?? 0;
        if (value is num && note?['situation'] == 'NUMERIQUE') {
          weighted += value * weight;
          enteredWeight += weight;
        } else {
          complete = false;
        }
      }
      rows.add([
        '${student['matricule'] ?? ''}',
        '${student['nom'] ?? ''}',
        ...evaluations.map((e) => markFor(student, e)),
        complete && enteredWeight > 0
            ? (weighted / 100).toStringAsFixed(2)
            : 'En attente',
        complete ? 'Complet · à valider' : 'Incomplet',
      ]);
    }

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Procès-verbal provisoire des notes',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${widget.assignment['code_ue']} · ${widget.assignment['code_classe'] ?? widget.assignment['classe'] ?? ''} · Semestre ${widget.assignment['numero_semestre'] ?? '—'}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(
              color: pdf.PdfColor(0.85, 0.91, 0.89),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Document provisoire de travail. Les notes deviennent officielles après transmission et validation institutionnelle.',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    await FilePicker.platform.saveFile(
      fileName: 'PV-notes-${widget.assignment['code_ue']}.pdf',
      bytes: await document.save(),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  }

  Future<String?> _reasonDialog(String title) async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          minLines: 2,
          maxLines: 3,
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
              final value = c.text.trim();
              if (value.isEmpty || value.length >= 8) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    c.dispose();
    return value;
  }

  Future<void> _showProvisionals(String period) async {
    try {
      final rows = await widget.api.teacherProvisionalBulletins(
        widget.assignmentId,
        period: period,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Résultats provisoires de l’EC · $period'),
          content: SizedBox(
            width: 640,
            child: ListView(
              shrinkWrap: true,
              children: rows
                  .map(
                    (r) => ListTile(
                      title: Text('${r['matricule']} · ${r['nom']}'),
                      subtitle: Text(
                        'Résultat de l’EC : ${((r['resultat_ec_provisoire'] as Map?)?['arrondi']) ?? '—'} /100 · ${((r['resultat_ec_provisoire'] as Map?)?['el'] == true) ? 'incomplet' : 'provisoire'}',
                      ),
                    ),
                  )
                  .toList(),
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
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }
}

class _GradebookGrid extends StatefulWidget {
  const _GradebookGrid({
    super.key,
    required this.api,
    required this.assignmentId,
    required this.students,
    required this.evaluations,
    required this.isCorrection,
    required this.onSaved,
  });

  final StudentApiClient api;
  final int assignmentId;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> evaluations;
  final bool isCorrection;
  final VoidCallback onSaved;

  @override
  State<_GradebookGrid> createState() => _GradebookGridState();
}

class _GradebookGridState extends State<_GradebookGrid> {
  late final Map<String, Map<String, dynamic>> drafts;
  bool saving = false;

  String _key(String matricule, Object? evaluationId) =>
      '${matricule.trim().toUpperCase()}:$evaluationId';

  @override
  void initState() {
    super.initState();
    drafts = {};
    for (final student in widget.students) {
      for (final evaluation in widget.evaluations) {
        final note = (student['notes'] as List? ?? [])
            .whereType<Map>()
            .where((row) => row['evaluation_id'] == evaluation['evaluation_id'])
            .firstOrNull;
        final key = _key(
          '${student['matricule']}',
          evaluation['evaluation_id'],
        );
        final value = note?['valeur_note'];
        drafts[key] = {
          'valeur_note': value?.toString() ?? '',
          'situation': note?['situation'] ?? 'MANQUANTE',
          'version_note': note?['version_note'],
          'correction_autorisee': note?['correction_autorisee'] == true,
          'initial_value': value?.toString() ?? '',
          'initial_situation': note?['situation'] ?? 'MANQUANTE',
          'revision': 0,
        };
      }
    }
  }

  bool _locked(Map<String, dynamic> evaluation, [Map<String, dynamic>? draft]) {
    final status = (evaluation['transmission'] as Map?)?['statut'];
    if (status == 'VERIFIEE' && draft?['correction_autorisee'] == true) {
      return false;
    }
    return ['TRANSMISE', 'A_VERIFIER', 'VERIFIEE'].contains(status);
  }

  String _total(Map<String, dynamic> student) {
    var sum = 0.0;
    for (final evaluation in widget.evaluations) {
      final draft =
          drafts[_key('${student['matricule']}', evaluation['evaluation_id'])]!;
      if (draft['situation'] == 'ABSENTE') return 'ABS';
      final value = double.tryParse(
        '${draft['valeur_note']}'.replaceAll(',', '.'),
      );
      if (draft['situation'] != 'NUMERIQUE' || value == null) return '—';
      final weight = (evaluation['poids_evaluation'] as num?)?.toDouble() ?? 0;
      sum += value * weight;
    }
    return '${(sum / 100).toStringAsFixed(2)} /20';
  }

  bool get _hasChanges => drafts.values.any(
    (draft) =>
        draft['valeur_note']?.toString() !=
            draft['initial_value']?.toString() ||
        draft['situation'] != draft['initial_situation'],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.isCorrection
                    ? 'Correction ciblée · les autres notes validées restent verrouillées'
                    : 'Saisie en grille · ${widget.students.length} étudiants · les notes sont enregistrées en brouillon',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: saving || !_hasChanges ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                saving
                    ? 'Enregistrement…'
                    : widget.isCorrection
                    ? 'Enregistrer la correction'
                    : 'Enregistrer toutes les notes',
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Scrollbar(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 54,
                dataRowMinHeight: 62,
                dataRowMaxHeight: 72,
                columns: [
                  const DataColumn(label: Text('Matricule')),
                  const DataColumn(label: Text('Étudiant')),
                  ...widget.evaluations.map(
                    (evaluation) => DataColumn(
                      label: SizedBox(
                        width: 126,
                        child: Text(
                          '${evaluation['type_eval']} · ${evaluation['poids_evaluation']}%',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isCorrection)
                    const DataColumn(label: Text('Note finale /20')),
                ],
                rows: widget.students.map((student) {
                  return DataRow(
                    cells: [
                      DataCell(Text('${student['matricule'] ?? ''}')),
                      DataCell(
                        SizedBox(
                          width: 190,
                          child: Text('${student['nom'] ?? ''}', maxLines: 2),
                        ),
                      ),
                      ...widget.evaluations.map((evaluation) {
                        final key = _key(
                          '${student['matricule']}',
                          evaluation['evaluation_id'],
                        );
                        final draft = drafts[key]!;
                        final disabled = saving || _locked(evaluation, draft);
                        final stageNote = (student['notes'] as List? ?? [])
                            .whereType<Map>()
                            .where(
                              (note) =>
                                  '${note['evaluation_id']}' ==
                                  '${evaluation['evaluation_id']}',
                            )
                            .firstOrNull;
                        return DataCell(
                          SizedBox(
                            width: 140,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  key: ValueKey(
                                    'grid-$key-${draft['revision']}',
                                  ),
                                  initialValue:
                                      draft['valeur_note']?.toString() ?? '',
                                  enabled: !disabled,
                                  textAlign: TextAlign.center,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: 'Note /20',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    suffixIcon: PopupMenuButton<String>(
                                      tooltip: 'Situation de la note',
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                      ),
                                      onSelected: disabled
                                          ? null
                                          : (value) => setState(() {
                                              draft['situation'] = value;
                                              if (value != 'NUMERIQUE')
                                                draft['valeur_note'] = '';
                                              draft['revision'] =
                                                  (draft['revision'] as int) +
                                                  1;
                                            }),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'NUMERIQUE',
                                          child: Text('Note numérique'),
                                        ),
                                        PopupMenuItem(
                                          value: 'ABSENTE',
                                          child: Text('Absent'),
                                        ),
                                        PopupMenuItem(
                                          value: 'MANQUANTE',
                                          child: Text('Note manquante'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onChanged: (raw) => setState(() {
                                    final value = raw.trim();
                                    final parsed = value.isEmpty
                                        ? null
                                        : double.tryParse(
                                            value.replaceAll(',', '.'),
                                          );
                                    draft['valeur_note'] = raw;
                                    draft['situation'] = parsed == null
                                        ? (value.isEmpty
                                              ? 'MANQUANTE'
                                              : 'INVALIDE')
                                        : 'NUMERIQUE';
                                  }),
                                ),
                                if (evaluation['transmission']?['statut'] ==
                                        'A_VERIFIER' &&
                                    stageNote?['situation_numerisee'] != null)
                                  Text(
                                    'Cellule : ${stageNote?['situation_numerisee'] == 'NUMERIQUE' ? '${stageNote?['valeur_numerisee']}/20' : stageNote?['situation_numerisee']}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (!widget.isCorrection)
                        DataCell(
                          Text(
                            _total(student),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Future<void> _save() async {
    final invalid = drafts.values.any((draft) {
      if (draft['situation'] == 'INVALIDE') return true;
      if (draft['situation'] != 'NUMERIQUE') return false;
      final value = double.tryParse(
        '${draft['valeur_note']}'.replaceAll(',', '.'),
      );
      return value == null || value < 0 || value > 20;
    });
    if (invalid) {
      toast(context, 'Chaque note numérique doit être comprise entre 0 et 20.');
      return;
    }
    setState(() => saving = true);
    var savedGroups = 0;
    final failures = <String>[];
    try {
      for (final evaluation in widget.evaluations) {
        final evaluationId = (evaluation['evaluation_id'] as num).toInt();
        final changedRows = <Map<String, dynamic>>[];
        for (final student in widget.students) {
          final draft = drafts[_key('${student['matricule']}', evaluationId)]!;
          if (_locked(evaluation, draft)) continue;
          if (draft['valeur_note']?.toString() ==
                  draft['initial_value']?.toString() &&
              draft['situation'] == draft['initial_situation']) {
            continue;
          }
          changedRows.add({
            'matricule': student['matricule'],
            'situation': draft['situation'],
            'valeur_note': draft['situation'] == 'NUMERIQUE'
                ? double.parse('${draft['valeur_note']}'.replaceAll(',', '.'))
                : null,
            if (draft['version_note'] is num &&
                (draft['version_note'] as num) > 0)
              'version_note': draft['version_note'],
          });
        }
        if (changedRows.isEmpty) continue;
        try {
          await widget.api.teacherSaveGrades(
            widget.assignmentId,
            evaluationId,
            grades: changedRows,
          );
          savedGroups++;
        } catch (error) {
          failures.add('${evaluation['type_eval']} : $error');
        }
      }
      if (!mounted) return;
      setState(() => saving = false);
      if (savedGroups > 0) widget.onSaved();
      final message = savedGroups == 0 && failures.isEmpty
          ? 'Aucune modification à enregistrer.'
          : '$savedGroups composante(s) enregistrée(s). ${failures.join(' · ')}';
      toast(context, message);
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }
}
