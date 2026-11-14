import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';

import 'api_client.dart';
import 'academic_bulletin_pdf.dart';
import 'file_download.dart';
import 'gnu_pv_template.dart';
import 'pdf_theme.dart';
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
  bool refreshing = false;
  late Future<Object> pageData;
  final Set<int> decidedAssignmentProposalIds = {};
  final Map<int, Future<Map<String, dynamic>>> publicationHistoryFutures = {};
  int? selectedClass;
  int? selectedPublicationVersion;
  String period = 'S1';
  String accountSearch = '';
  String accountRequestSearch = '';
  String accountRequestRole = 'Tous';
  String accountRequestDepartment = 'Tous';
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
  void initState() {
    super.initState();
    pageData = _load();
  }

  @override
  void didUpdateWidget(covariant AgentPortalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page || oldWidget.api != widget.api) {
      pageData = _load();
    }
  }

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
      widget.api.agentAccountRequests(),
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
    'notifications' => widget.api.agentNotifications(),
    'profile' => Future.wait([
      widget.api.getProfile(),
      widget.api.academicYears(),
    ]),
    _ => widget.api.agentDashboard(),
  };

  Future<void> _reload() async {
    if (refreshing) return;
    publicationHistoryFutures.clear();
    final request = _load();
    setState(() {
      refreshing = true;
      revision++;
      pageData = request;
    });
    try {
      await request;
    } catch (_) {
      // The FutureBuilder presents the load error while retaining its retry action.
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Object>(
    future: pageData,
    builder: (context, snapshot) {
      final title = switch (widget.page) {
        'academic' => 'Structure & catalogue',
        'accounts' => 'Comptes & affectations',
        'enrollment' => 'Inscriptions à examiner',
        'requests' => 'Requêtes étudiantes',
        'grade-transmissions' => 'Traitement des PV',
        'notifications' => 'Notifications',
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
        'grade-transmissions' => 'Suivez les grilles transmises, le traitement des PV et les publications à effectuer.',
        'notifications' => 'Suivez les nouvelles transmissions de notes et les événements de votre périmètre.',
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
              onPressed: refreshing ? null : _reload,
              tooltip: refreshing ? 'Actualisation en cours' : 'Actualiser',
              icon: refreshing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
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
    'notifications' => _notifications(data as List),
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
        'Aucun PV en cours de traitement',
        'Les notes validées par les enseignants et les anciens PV à traiter apparaîtront ici.',
      );
    }
    final received = <Map<String, dynamic>>[];
    final digitizing = <Map<String, dynamic>>[];
    final scannedReady = <Map<String, dynamic>>[];
    final teacherReview = <Map<String, dynamic>>[];
    final corrections = <Map<String, dynamic>>[];
    final readyToPublish = <Map<String, dynamic>>[];
    final legacyEc = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['ancienne_grille_ec'] == true) {
        legacyEc.add(row);
        continue;
      }
      switch (row['statut']) {
        case 'TRANSMISE':
          final notes = _maps(row['notes']);
          final digitized = notes
              .where((note) => note['situation_numerisee'] != null)
              .length;
          if (digitized == 0) {
            received.add(row);
          } else if (digitized == notes.length) {
            scannedReady.add(row);
          } else {
            digitizing.add(row);
          }
          break;
        case 'A_VERIFIER':
          teacherReview.add(row);
          break;
        case 'A_CORRIGER':
          corrections.add(row);
          break;
        case 'VERIFIEE':
        case 'VALIDEE_ENSEIGNANT':
          readyToPublish.add(row);
          break;
      }
    }
    final sections = [
      (
        'Données reçues · à numériser',
        'Transmissions reçues par la cellule, sans ligne numérisée.',
        Icons.inbox_outlined,
        const Color(0xFFB87516),
        received,
      ),
      (
        'Numérisation en cours',
        'Une partie des notes est numérisée; terminez la saisie avant le retour.',
        Icons.document_scanner_outlined,
        const Color(0xFF3478A5),
        digitizing,
      ),
      (
        'Numérisation terminée · retour à faire',
        'Toutes les notes sont saisies. Joignez le PV traité et retournez-le à l’enseignant.',
        Icons.forward_to_inbox_outlined,
        const Color(0xFF3478A5),
        scannedReady,
      ),
      (
        'PV traité · visa enseignant attendu',
        'La cellule a traité et renvoyé ces PV. L’enseignant doit vérifier les notes.',
        Icons.pending_actions_outlined,
        const Color(0xFFB87516),
        teacherReview,
      ),
      (
        'Corrections à reprendre',
        'L’enseignant a demandé une correction avant de vérifier le PV.',
        Icons.edit_note_outlined,
        const Color(0xFFB64242),
        corrections,
      ),
      (
        'Validation enseignant · publication à effectuer',
        'Les notes validées par l’enseignant attendent la publication aux étudiants.',
        Icons.task_alt_outlined,
        emerald,
        readyToPublish,
      ),
      (
        'Anciennes transmissions par EC · historique',
        'Ces PV ont été transmis avant le carnet unique par UE. Ils restent consultables, mais ne peuvent plus être numérisés ou publiés comme notes de l’UE.',
        Icons.inventory_2_outlined,
        const Color(0xFF687982),
        legacyEc,
      ),
    ].where((section) => section.$5.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          padding: 16,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Dossiers classés par état :'),
              for (final section in sections)
                Chip(
                  avatar: Icon(section.$3, size: 16, color: section.$4),
                  label: Text('${section.$1} · ${section.$5.length}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < sections.length; index++)
          _gradeTransmissionSection(
            title: sections[index].$1,
            description: sections[index].$2,
            icon: sections[index].$3,
            color: sections[index].$4,
            rows: sections[index].$5,
            initiallyExpanded: index == 0,
          ),
      ],
    );
  }

  Widget _gradeTransmissionSection({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> rows,
    required bool initiallyExpanded,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      padding: 8,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: color),
        title: Text('$title · ${rows.length}'),
        subtitle: Text(description),
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _gradeTransmissionCard(row),
            ),
        ],
      ),
    ),
  );

  Widget _gradeTransmissionCard(Map<String, dynamic> row) => Panel(
    padding: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${row['code_classe']} · ${row['code_ue']} · ${row['code_m']}',
          ),
          subtitle: Text(
            '${row['intitule_matiere']}\n${row['enseignant_prenom']} ${row['enseignant_nom']} · ${_gradeEvaluationLabel(row)}${row['evaluation']?['mode_evaluation'] == 'RATTRAPAGE' ? '' : ' · ${row['poids_evaluation'] ?? '—'} %'} · version ${row['version']}',
          ),
          isThreeLine: true,
          trailing: StatusBadge(
            _gradeTransmissionStatus(row),
            color: switch (_gradeTransmissionStatus(row)) {
              'Reçu · à numériser' => const Color(0xFFB87516),
              'Numérisation en cours' => const Color(0xFF3478A5),
              'Numérisé · prêt à retourner' => const Color(0xFF3478A5),
              'Visa enseignant' => const Color(0xFFB87516),
              'Correction demandée' => const Color(0xFFB64242),
              'Prêt à publier' => emerald,
              'Validé par l’enseignant · prêt à publier' => emerald,
              _ => const Color(0xFFB87516),
            },
          ),
        ),
        if (row['statut'] == 'TRANSMISE') ...[
          Builder(
            builder: (context) {
              final notes = _maps(row['notes']);
              final digitized = notes
                  .where((note) => note['situation_numerisee'] != null)
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Numérisation : $digitized/${notes.length} ligne(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ],
        Text(
          '${switch (row['statut']) {
            'TRANSMISE' => 'Motif de transmission',
            'A_CORRIGER' => 'Correction demandée par l’enseignant',
            'A_VERIFIER' => 'Visa de l’enseignant',
            'VALIDEE_ENSEIGNANT' => 'Validation de l’enseignant',
            _ => 'Décision de l’enseignant',
          }} : ${row['motif'] ?? 'Aucun motif précisé.'}',
        ),
        if (row['ancienne_grille_ec'] == true)
          const Notice(
            'PV historique d’une ancienne grille par EC. Il est conservé pour la traçabilité et n’intervient plus dans la note de l’UE. Utilisez le carnet unique de l’UE pour transmettre la grille actuelle.',
            warning: true,
          ),
        const SizedBox(height: 8),
        ..._maps(row['notes']).map(
          (note) => ListTile(
            dense: true,
            title: Text(
              '${note['matricule']} · ${note['prenom']} ${note['nom']}',
            ),
            subtitle: note['hors_compte'] == true
                ? Text('${note['observation'] ?? 'Non inscrit; observation à vérifier.'}')
                : null,
            trailing: Text(
              row['ancienne_grille_ec'] == true
                  ? '${note['situation'] == 'NUMERIQUE' ? '${note['valeur_note']} /20' : note['situation']} · historique'
                  : row['statut'] == 'VALIDEE_ENSEIGNANT'
                  ? '${note['situation'] == 'NUMERIQUE' ? '${note['valeur_note']} /20' : note['situation']} · saisi par l’enseignant'
                  : '${note['situation'] == 'NUMERIQUE' ? '${note['valeur_note']} /20' : note['situation']}'
                      ' → ${note['situation_numerisee'] == 'NUMERIQUE' ? '${note['valeur_numerisee']} /20' : note['situation_numerisee'] ?? 'à numériser'}',
            ),
          ),
        ),
        if (row['ancienne_grille_ec'] == true &&
            row['proces_verbal_disponible'] == true)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _downloadGradeMinutes(row),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Consulter le PV historique'),
            ),
          )
        else if (row['ancienne_grille_ec'] == true)
          const Notice(
            'Le fichier du PV historique est absent ou indisponible.',
            warning: true,
          )
        else if (row['statut'] == 'TRANSMISE') ...[
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
              onPressed: _maps(row['notes']).every(
                (note) => note['situation_numerisee'] != null,
              )
                  ? () => _returnGradeTransmission(row)
                  : null,
              icon: const Icon(Icons.forward_to_inbox_outlined),
              label: const Text('Joindre le PV et retourner à l’enseignant'),
            ),
          ),
        ] else if (row['statut'] == 'A_VERIFIER' ||
            row['statut'] == 'A_CORRIGER') ...[
          Notice(
            row['statut'] == 'A_VERIFIER'
                ? 'PV traité par la cellule et renvoyé à l’enseignant. La transmission attend son visa avant publication.'
                : 'L’enseignant a demandé une correction. Le PV attend une nouvelle transmission de notes.',
            warning: row['statut'] == 'A_CORRIGER',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _downloadGradeMinutes(row),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Consulter le PV traité'),
            ),
          ),
        ] else if (row['statut'] == 'VERIFIEE' ||
            row['statut'] == 'VALIDEE_ENSEIGNANT') ...[
          const Notice(
            'L’enseignant a validé les notes. Publiez-les pour prévenir les étudiants.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                if (row['proces_verbal_disponible'] == true)
                  OutlinedButton.icon(
                    onPressed: () => _downloadGradeMinutes(row),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Télécharger le PV'),
                  ),
                FilledButton.icon(
                  onPressed: () => _publishGradeTransmission(row),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Publier les notes aux étudiants'),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _notifications(List data) {
    final rows = _maps(data);
    if (rows.isEmpty) {
      return const EmptyState(
        'Aucune notification',
        'Les transmissions de notes et décisions apparaîtront ici.',
      );
    }
    return Column(
      children: rows.map((row) {
        final content = row['contenu'] is Map
            ? Map<String, dynamic>.from(row['contenu'] as Map)
            : <String, dynamic>{};
        final id = (row['id'] as num?)?.toInt();
        return Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              row['lue'] == true
                  ? Icons.notifications_none
                  : Icons.notifications_active_outlined,
            ),
            title: Text(
              content['titre']?.toString() ?? 'Notification académique',
            ),
            subtitle: Text('${content['message'] ?? ''}\n${row['date'] ?? ''}'),
            isThreeLine: true,
            trailing: row['lue'] == true || id == null
                ? null
                : IconButton(
                    tooltip: 'Marquer comme lue',
                    icon: const Icon(Icons.done),
                    onPressed: () async {
                      await widget.api.agentMarkNotificationRead(id);
                      _reload();
                    },
                  ),
          ),
        );
      }).toList(),
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
          if (note['hors_compte'] == true) 'hors_compte': true,
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
        final situation =
            columns[1].isEmpty ||
                const [
                  'EL',
                  'ELIMINE',
                  'ELIMINEE',
                  'ABS',
                  'ABSENT',
                  'ABSENTE',
                ].contains(rawMark)
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
    await _mutate(() async {
      final bytes = await _buildGradeMinutesPdf(row);
      await widget.api.agentReturnGradeTransmission(
        row['id'] as int,
        filename: _gradeMinutesFilename(row),
        pdfFile: bytes,
        reason: reason,
      );
    });
  }

  Future<void> _publishGradeTransmission(Map<String, dynamic> row) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publier les notes vérifiées ?'),
        content: const Text(
          'Chaque étudiant recevra uniquement sa propre note provisoire. Le procès-verbal complet reste réservé aux personnes habilitées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => widget.api.agentPublishGradeTransmission(row['id'] as int),
    );
  }

  Future<void> _downloadGradeMinutes(Map<String, dynamic> row) async {
    try {
      final bytes = await widget.api.agentDownloadGradeTransmissionMinutes(
        row['id'] as int,
      );
      await downloadFile(_gradeMinutesFilename(row), bytes);
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  String _gradeMinutesFilename(Map<String, dynamic> row) {
    final period = row['numero_semestre'] == 2 ? 'S2' : 'S1';
    final year = '${row['annee_academique'] ?? 'GNU'}'.replaceAll('-', '_');
    final eval = row['evaluation']?['mode_evaluation'] == 'RATTRAPAGE'
        ? 'RATTRAPAGE_SN'
        : '${row['evaluation']?['type_eval'] ?? 'EVALUATION'}';
    return 'PV_${eval}_${row['code_ue']}_${row['code_classe']}_${period}_$year.pdf'
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }

  String _gradeTransmissionStatus(Map<String, dynamic> row) {
    if (row['statut'] == 'TRANSMISE') {
      final notes = _maps(row['notes']);
      final digitized = notes
          .where((note) => note['situation_numerisee'] != null)
          .length;
      if (digitized == 0) return 'Reçu · à numériser';
      if (digitized < notes.length) return 'Numérisation en cours';
      return 'Numérisé · prêt à retourner';
    }
    return switch (row['statut']) {
      'A_VERIFIER' => 'Visa enseignant',
      'A_CORRIGER' => 'Correction demandée',
      'VERIFIEE' => 'Prêt à publier',
      'VALIDEE_ENSEIGNANT' => 'Validé par l’enseignant · prêt à publier',
      _ => 'État inconnu',
    };
  }

  String _gradeEvaluationLabel(Map<String, dynamic> row) =>
      row['evaluation']?['mode_evaluation'] == 'RATTRAPAGE'
      ? 'Rattrapage de SN'
      : '${row['evaluation']?['type_eval'] ?? 'Évaluation'}';

  Future<Uint8List> _buildGradeMinutesPdf(Map<String, dynamic> row) async {
    final period = row['numero_semestre'] == 2
        ? 'SEMESTRE 2 / SEMESTER 2'
        : 'SEMESTRE 1 / SEMESTER 1';
    final year = '${row['annee_academique'] ?? '—'}';
    final currentAgent =
        '${widget.api.user?['prenom'] ?? ''} ${widget.api.user?['nom'] ?? ''}'
            .trim();
    final title = '${row['intitule_ue'] ?? row['intitule_matiere'] ?? ''}';
    final isRetake = row['evaluation']?['mode_evaluation'] == 'RATTRAPAGE';
    final reference =
        'PV-${row['code_ue']}-${isRetake ? 'RATTRAPAGE-SN' : row['evaluation']?['type_eval']}-${row['code_classe']}-${row['id']}';
    final logoData = row['logo_structure'] is Map
        ? Map<String, dynamic>.from(row['logo_structure'] as Map)
        : null;
    Uint8List? logoBytes = logoData?['base64'] is String
        ? base64Decode(logoData!['base64'] as String)
        : null;
    if (logoBytes == null) {
      try {
        logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer
            .asUint8List();
      } catch (_) {
        logoBytes = null;
      }
    }
    final crest = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final document = pw.Document(theme: await gnuPdfTheme());
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 36),
        header: (_) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RÉPUBLIQUE DU CAMEROUN',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Paix – Travail – Patrie',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'UNIVERSITÉ DE YAOUNDÉ I',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 48,
                  height: 48,
                  child: crest == null
                      ? null
                      : pw.Image(crest, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'REPUBLIC OF CAMEROON',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Peace – Work – Fatherland',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'THE UNIVERSITY OF YAOUNDÉ I',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'FACULTÉ DES SCIENCES · ${row['nom_depart'] ?? 'DÉPARTEMENT'}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),
            pw.Text(
              isRetake
                  ? 'PROCÈS-VERBAL DE RATTRAPAGE'
                  : 'PROCÈS-VERBAL DE L’UNITÉ D’ENSEIGNEMENT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              '${row['code_ue']} · $title',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'EC : ${row['code_m']} · ${row['intitule_matiere'] ?? ''}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '© UY1/CI · $reference · $year',
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.Text(
              '${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: ['Élément', 'Valeur'],
            data: [
              ['UE / unité d’enseignement', '${row['code_ue']} · $title'],
              [
                'EC / élément constitutif',
                '${row['code_m']} · ${row['intitule_matiere'] ?? '—'}',
              ],
              [
                'Évaluation',
                isRetake
                    ? 'RATTRAPAGE DE SN'
                    : '${row['evaluation']?['type_eval'] ?? '—'} · ${row['poids_evaluation'] ?? '—'} %',
              ],
              [
                'Date de l’épreuve',
                '${row['evaluation']?['date_evaluation'] ?? '—'}',
              ],
              [
                'Filière / spécialité',
                '${row['code_f'] ?? '—'} · ${row['libelle_specialite'] ?? '—'}',
              ],
              [
                'Niveau / classe',
                '${row['code_niv'] ?? '—'} · ${row['code_classe'] ?? '—'}',
              ],
              ['Semestre / année académique', '$period · $year'],
              ['Transmis par l’enseignant le', '${row['transmis_le'] ?? '—'}'],
              [
                'Enseignant',
                '${row['enseignant_prenom'] ?? ''} ${row['enseignant_nom'] ?? ''}',
              ],
              [
                'Contrôlé par l’agent',
                '${row['agent_traitant'] ?? currentAgent} · ${row['pv_traite_le'] ?? DateTime.now().toIso8601String().split('T').first}',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
            },
            border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .5),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'N°',
              'MATRICULE',
              'NOMS ET PRÉNOMS',
              'NOTE /20',
              'OBSERVATIONS',
            ],
            data: [
              for (var index = 0; index < _maps(row['notes']).length; index++)
                (() {
                  final note = _maps(row['notes'])[index];
                  final absent = note['situation_numerisee'] == 'ABSENTE';
                  return [
                    '${index + 1}',
                    '${note['matricule']}',
                    '${note['nom']} ${note['prenom']}',
                    absent ? 'EL' : '${note['valeur_numerisee'] ?? '—'}',
                    note['hors_compte'] == true
                        ? 'Sans compte'
                        : absent
                        ? 'ÉLIMINÉ(E)'
                        : '',
                  ];
                })(),
            ],
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {2: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .45),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FixedColumnWidth(72),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FixedColumnWidth(52),
              4: const pw.FlexColumnWidth(1.5),
            },
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Procès-verbal de salle établi à partir de la grille transmise par l’enseignant et de sa numérisation par la cellule informatique.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 24),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Fait à Yaoundé, le ${DateTime.now().toLocal().toIso8601String().split('T').first}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.TableHelper.fromTextArray(
            headers: [
              'Enseignant responsable',
              'Cellule informatique',
              'Chef du département',
            ],
            data: [
              [
                '${row['enseignant_prenom'] ?? ''} ${row['enseignant_nom'] ?? ''}\nSignature',
                '${row['agent_traitant'] ?? currentAgent}\nVisa et cachet',
                'Visa et cachet',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.bottomCenter,
            border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .5),
            cellPadding: const pw.EdgeInsets.fromLTRB(5, 8, 5, 35),
          ),
        ],
      ),
    );
    return document.save();
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

  String _formatProposalDate(Object? value) {
    final submittedAt = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (submittedAt == null) return 'date indisponible';
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(submittedAt.day)}/${twoDigits(submittedAt.month)}/${submittedAt.year} à ${twoDigits(submittedAt.hour)}:${twoDigits(submittedAt.minute)}';
  }

  Widget _accounts(List data) {
    final allAccounts = _maps(data[0]);
    final proposals = _maps(data[2])
        .where(
          (item) =>
              !decidedAssignmentProposalIds.contains((item['id'] as num).toInt()),
        )
        .toList();
    final accountRequests = _maps(data[3]);
    final requestRoles =
        <String>{
          'Tous',
          ...accountRequests
              .map((item) => '${item['role'] ?? ''}')
              .where((value) => value.isNotEmpty),
        }.toList()..sort(
          (a, b) => a == 'Tous'
              ? -1
              : b == 'Tous'
              ? 1
              : a.compareTo(b),
        );
    final requestDepartments =
        <String>{
          'Tous',
          ...accountRequests
              .map((item) => '${item['code_de'] ?? ''}')
              .where((value) => value.isNotEmpty),
        }.toList()..sort(
          (a, b) => a == 'Tous'
              ? -1
              : b == 'Tous'
              ? 1
              : a.compareTo(b),
        );
    final requestQuery = accountRequestSearch.trim().toLowerCase();
    final filteredAccountRequests = accountRequests.where((item) {
      final searchable = [
        item['nom'],
        item['prenom'],
        item['role'],
        item['login'],
        item['identifiant_profil'],
        item['courriel'],
        item['nom_depart'],
        item['code_de'],
        item['reference_identite'],
      ].join(' ').toLowerCase();
      return (requestQuery.isEmpty || searchable.contains(requestQuery)) &&
          (accountRequestRole == 'Tous' ||
              item['role'] == accountRequestRole) &&
          (accountRequestDepartment == 'Tous' ||
              item['code_de'] == accountRequestDepartment);
    }).toList();
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
              SectionTitle(
                'Demandes de comptes à valider',
                subtitle: accountRequests.isEmpty
                    ? 'Aucune demande en attente dans votre département.'
                    : '${filteredAccountRequests.length} affichée(s) sur ${accountRequests.length} demande(s) en attente. Examinez les informations avant toute décision.',
              ),
              if (accountRequests.isNotEmpty) ...[
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Rechercher une demande',
                    hintText: 'Nom, EID, courriel, département ou référence',
                  ),
                  onChanged: (value) =>
                      setState(() => accountRequestSearch = value),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _assignmentFilter(
                      'Rôle demandé',
                      accountRequestRole,
                      'Tous',
                      requestRoles,
                      (value) => setState(() => accountRequestRole = value),
                    ),
                    _assignmentFilter(
                      'Département',
                      accountRequestDepartment,
                      'Tous',
                      requestDepartments,
                      (value) =>
                          setState(() => accountRequestDepartment = value),
                    ),
                    if (requestQuery.isNotEmpty ||
                        accountRequestRole != 'Tous' ||
                        accountRequestDepartment != 'Tous')
                      TextButton.icon(
                        onPressed: () => setState(() {
                          accountRequestSearch = '';
                          accountRequestRole = 'Tous';
                          accountRequestDepartment = 'Tous';
                        }),
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Effacer les filtres'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filteredAccountRequests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Aucune demande ne correspond aux filtres.'),
                    ),
                  ),
                ...filteredAccountRequests.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showAccountRequestDetails(item),
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(
                      '${item['prenom']} ${item['nom']} · ${item['role']}',
                    ),
                    subtitle: Text(
                      '${item['login']} · ${item['identifiant_profil']} · ${item['courriel'] ?? 'Courriel absent'}\n${item['nom_depart']} (${item['code_de']})',
                    ),
                    isThreeLine: true,
                    trailing: OutlinedButton.icon(
                      onPressed: () => _showAccountRequestDetails(item),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Examiner'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (accountRequests.isNotEmpty) const SizedBox(height: 16),
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
                      .map((account) {
                        final deleted = account['supprime_le'] != null;
                        final manageable =
                            account['gestionnable'] != false &&
                            account['role'] != 'AGENT';

                        return ListTile(
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
                                deleted
                                    ? 'Supprimé'
                                    : account['actif'] == true
                                    ? 'Actif'
                                    : 'Suspendu',
                                color: deleted
                                    ? Theme.of(context).colorScheme.error
                                    : account['actif'] == true
                                    ? emerald
                                    : muted,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: !manageable || deleted
                                    ? null
                                    : () => _toggleAccount(account),
                                tooltip: !manageable
                                    ? 'Gestion réservée à son périmètre de rattachement'
                                    : deleted
                                    ? 'Compte supprimé'
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
                                onPressed: !manageable || deleted
                                    ? null
                                    : () => _editAccount(account),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: deleted
                                    ? 'Compte déjà supprimé'
                                    : 'Supprimer le compte en conservant son dossier académique',
                                onPressed: !manageable || deleted
                                    ? null
                                    : () => _deleteAccount(account),
                                color: Theme.of(context).colorScheme.error,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      })
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
                subtitle: '${proposals.length} choix en attente de validation.',
              ),
              if (proposals.isEmpty)
                const EmptyState(
                  'Aucun choix à valider',
                  'Les UE et EC acceptés par les enseignants apparaîtront ici.',
                ),
              ...proposals.map((proposal) {
                final teacherName =
                    '${proposal['prenom_enseignant'] ?? ''} ${proposal['nom_enseignant'] ?? ''}'
                        .trim();
                final teacherEmail =
                    '${proposal['courriel_enseignant'] ?? ''}'.trim();
                final teacherNote =
                    '${proposal['motif_enseignant'] ?? ''}'.trim();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3, right: 12),
                              child: Icon(Icons.pending_actions_outlined),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacherName.isEmpty
                                        ? 'Enseignant non identifié'
                                        : teacherName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    'Identifiant enseignant : ${proposal['eid'] ?? '—'}',
                                  ),
                                  if (teacherEmail.isNotEmpty)
                                    Text('Courriel : $teacherEmail'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Classe : ${proposal['code_classe'] ?? '—'} · ${proposal['code_niv'] ?? ''} ${proposal['libelle_niv'] ?? ''}'
                              .trim(),
                        ),
                        Text(
                          'Année académique : ${proposal['annee_academique'] ?? '—'} · Semestre ${proposal['numero_semestre'] ?? '—'}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Unité d’enseignement : ${proposal['code_ue'] ?? '—'} · ${proposal['intitule_ue'] ?? 'Intitulé indisponible'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Élément constitutif : ${proposal['code_m'] ?? '—'} · ${proposal['intitule_matiere'] ?? 'Intitulé indisponible'}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Soumis le : ${_formatProposalDate(proposal['soumise_le'])}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (teacherNote.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Notice('Message de l’enseignant : $teacherNote'),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _decideAssignmentProposal(
                                  proposal,
                                  'REJETER',
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Refuser'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _decideAssignmentProposal(
                                  proposal,
                                  'APPROUVER',
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text('Valider'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
              SectionTitle(
                'Affectations pédagogiques',
                subtitle:
                    '${visibleAssignments.length} sur ${assignments.length} affectation(s) · filtrables par année et département.',
              ),
              const SizedBox(height: 16),
              TextField(
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Rechercher classe, UE, EC ou enseignant',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                ),
                onChanged: (value) => setState(() => assignmentSearch = value),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
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
                    width: 250,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue:
                          years.contains(assignmentYear) ||
                              assignmentYear == 'Toutes'
                          ? assignmentYear
                          : 'Toutes',
                      decoration: const InputDecoration(
                        labelText: 'Année académique',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 17,
                        ),
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
              const SizedBox(height: 12),
              ...groupedAssignments.entries.map(
                (group) => ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  title: Text(group.key, style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Text('${group.value.length} affectation(s)'),
                  children: [
                    for (final item in group.value)
                      Card(
                        margin: const EdgeInsets.only(top: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minVerticalPadding: 12,
                            title: Text(
                              '${item['code_classe']} · ${item['code_ue']} · ${item['code_m']}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${item['prenom'] ?? ''} ${item['nom'] ?? ''} · ${item['eid'] ?? ''} · ${item['nom_fac'] ?? ''} / ${item['nom_depart'] ?? ''}\nResponsable notes UE : ${item['responsable_notes_prenom'] ?? ''} ${item['responsable_notes_nom'] ?? 'à désigner'}',
                              ),
                            ),
                            trailing: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: 'Choisir le responsable unique des notes pour cette UE',
                                  icon: const Icon(Icons.assignment_ind_outlined),
                                  onPressed: () => _chooseGradeManager(item, allAccounts),
                                ),
                                Switch(
                                  value: item['actif'] == true,
                                  onChanged: (active) => _setAssignment(item, active),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final reasonController = TextEditingController();
    final fullName =
        '${account['prenom'] ?? ''} ${account['nom'] ?? ''}'.trim();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Supprimer le compte'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirmez la suppression du compte de $fullName.'),
                  const SizedBox(height: 10),
                  const Text(
                    'L’accès sera bloqué et les sessions fermées. Les inscriptions, notes, affectations et traces académiques seront conservées. Cette action ne peut pas être annulée depuis l’application.',
                  ),
                  if (account['role'] == 'ENSEIGNANT') ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Vérifiez ses affectations pédagogiques avant de continuer; elles seront conservées dans le dossier.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Motif obligatoire',
                      helperText:
                          'Au moins 8 caractères (${reasonController.text.trim().length}/8).',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: reasonController.text.trim().length < 8
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      reasonController.text.trim(),
                    ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Confirmer la suppression'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    try {
      await widget.api.agentDeleteAccount(
        account['id'] as int,
        reason: reason,
      );
      if (!mounted) return;
      toast(context, 'Compte supprimé; son dossier académique est conservé.');
      _reload();
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _decideAccountRequest(
    Map<String, dynamic> item,
    String decision,
  ) async {
    final reason = await _reasonDialog(
      decision == 'APPROUVER'
          ? 'Vérification et approbation du compte'
          : 'Refus de la demande de compte',
    );
    if (reason == null) return;
    if (decision == 'REFUSER' && reason.trim().length < 8) {
      toast(
        context,
        'Un motif de refus d’au moins 8 caractères est obligatoire.',
      );
      return;
    }
    try {
      final response = await widget.api.agentDecideAccountRequest(
        item['id'] as int,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      if (decision == 'APPROUVER') {
        final data = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};
        final notification = '${data['notification_courriel'] ?? ''}';
        final isStudentRequest = item['role'] == 'ETUDIANT';
        final message = switch (notification) {
          'ENVOYEE' => isStudentRequest
              ? 'Compte activé, inscription à la classe validée et courriel envoyé.'
              : 'Compte activé et courriel d’approbation envoyé.',
          'ADRESSE_FICTIVE' =>
            'Compte activé. Adresse de test .invalid : aucun courriel envoyé.',
          'MAILER_LOCAL' => 'Compte activé. Courriel non livré : configurez un serveur SMTP (MAIL_MAILER=smtp).',
          'ADRESSE_ABSENTE' =>
            'Compte activé, mais aucun courriel n’est renseigné.',
          'ECHEC' => 'Compte activé, mais l’envoi du courriel a échoué. Vérifiez la configuration SMTP et les journaux.',
          _ => 'Compte activé.',
        };
        toast(context, message);
      } else {
        toast(context, 'Demande refusée.');
      }
      _reload();
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _showAccountRequestDetails(Map<String, dynamic> item) async {
    final studentClassMissing =
        item['role'] == 'ETUDIANT' && item['classe_id'] == null;
    final trackLabel = switch (item['role']) {
      'ETUDIANT' => 'Filière / mention demandée',
      'ENSEIGNANT' => 'Domaine d’enseignement indiqué',
      _ => 'Filière / domaine indiqué',
    };
    final specialtyLabel = item['role'] == 'ENSEIGNANT'
        ? 'Spécialité d’enseignement indiquée'
        : 'Option / spécialité demandée';
    final approvalGuidance = studentClassMissing
        ? 'Cette ancienne demande ne contient pas d’année ni de classe. Refusez-la avec un motif, puis invitez la personne à renvoyer sa demande avec ces informations.'
        : item['role'] == 'ETUDIANT'
        ? 'Vérifiez l’identité, l’année et la classe demandées. L’approbation crée le compte et valide l’inscription à cette classe.'
        : 'Vérifiez les justificatifs avant d’approuver. Une approbation active le compte.';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Détails de la demande de compte'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _accountRequestDetail('Nom', item['nom']),
                _accountRequestDetail('Prénom(s)', item['prenom']),
                _accountRequestDetail('Rôle demandé', item['role']),
                _accountRequestDetail(
                  'Identifiant de connexion',
                  item['login'],
                ),
                _accountRequestDetail(
                  'Identifiant de profil',
                  item['identifiant_profil'],
                ),
                _accountRequestDetail('Courriel', item['courriel']),
                _accountRequestDetail(
                  'Département',
                  '${item['nom_depart'] ?? '—'} (${item['code_de'] ?? '—'})',
                ),
                _accountRequestDetail(trackLabel, item['nom_f']),
                _accountRequestDetail(specialtyLabel, item['libelle_specialite']),
                if (item['role'] == 'ETUDIANT') ...[
                  _accountRequestDetail('Année demandée', item['annee_academique']),
                  _accountRequestDetail(
                    'Classe / salle demandée',
                    item['code_classe'] == null
                        ? null
                        : '${item['code_classe']} · ${item['libelle_niv'] ?? ''}',
                  ),
                ],
                _accountRequestDetail(
                  'Référence d’identité déclarée',
                  item['reference_identite'],
                ),
                _accountRequestDetail('Demande reçue le', item['soumise_le']),
                const SizedBox(height: 12),
                Text(
                  approvalGuidance,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                if (studentClassMissing) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Approbation désactivée : la classe doit être sélectionnée dans le nouveau formulaire.',
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _decideAccountRequest(item, 'REFUSER');
            },
            icon: const Icon(Icons.close),
            label: const Text('Refuser'),
          ),
          FilledButton.icon(
            onPressed: studentClassMissing
                ? null
                : () {
                    Navigator.pop(dialogContext);
                    _decideAccountRequest(item, 'APPROUVER');
                  },
            icon: const Icon(Icons.check),
            label: const Text('Approuver'),
          ),
        ],
      ),
    );
  }

  Widget _accountRequestDetail(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value == null || '$value'.trim().isEmpty
                ? 'Non renseigné'
                : '$value',
          ),
        ],
      ),
    ),
  );

  Widget _assignmentFilter(
    String label,
    String selected,
    String allLabel,
    List<String> values,
    ValueChanged<String> onChanged,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      isDense: true,
      isExpanded: true,
      initialValue: values.contains(selected) || selected == allLabel
          ? selected
          : allLabel,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: <String>{allLabel, ...values}
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

  Future<void> _chooseGradeManager(
    Map<String, dynamic> assignment,
    List<Map<String, dynamic>> allAccounts,
  ) async {
    final teachers = allAccounts.where((account) =>
      account['role'] == 'ENSEIGNANT' && account['actif'] == true && account['enseignant_id'] != null
    ).toList();
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Responsable des notes · ${assignment['code_ue']}'),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: teachers.map((teacher) => ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${teacher['prenom'] ?? ''} ${teacher['nom'] ?? ''}'),
              subtitle: Text('${teacher['eid'] ?? ''}'),
              trailing: teacher['enseignant_id'] == assignment['responsable_notes_enseignant_id']
                  ? const Icon(Icons.check_circle, color: Colors.teal)
                  : null,
              onTap: () => Navigator.pop(dialogContext, teacher['enseignant_id'] as int),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler'))],
      ),
    );
    if (selected == null || !mounted) return;
    await _mutate(() => widget.api.agentSetGradeManager(assignment['id'] as int, selected));
  }

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
    try {
      await widget.api.agentDecideAssignmentProposal(
        proposal['id'] as int,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        decidedAssignmentProposalIds.add((proposal['id'] as num).toInt());
      });
      toast(context, 'Décision enregistrée. Les données se mettent à jour.');
      _reload();
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
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
                      selectedClass['niveau_id'].toString(),
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
    final submitted = rows.where((row) => row['statut'] == 'SOUMISE').toList();
    final reviewed = rows.where((row) => row['statut'] != 'SOUMISE').toList();
    if (rows.isEmpty)
      return const EmptyState(
        'Aucune inscription à examiner',
        'Les nouvelles demandes apparaîtront ici.',
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _enrollmentSection(
          title: 'À examiner',
          description: 'Demandes soumises qui attendent une décision de l’administration.',
          rows: submitted,
          actionable: true,
          initiallyExpanded: true,
        ),
        const SizedBox(height: 16),
        _enrollmentSection(
          title: 'Historique des inscriptions',
          description: 'Comptes et classes conservés après validation ou retour de dossier.',
          rows: reviewed,
          actionable: false,
          initiallyExpanded: reviewed.isNotEmpty && submitted.isEmpty,
        ),
      ],
    );
  }

  Widget _enrollmentSection({
    required String title,
    required String description,
    required List<Map<String, dynamic>> rows,
    required bool actionable,
    required bool initiallyExpanded,
  }) => Panel(
    padding: 12,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      title: Text('$title · ${rows.length}'),
      subtitle: Text(description),
      children: rows.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(actionable ? 'Aucune demande en attente.' : 'Aucune inscription traitée pour le moment.'),
              ),
            ]
          : rows.map((row) => _enrollmentCard(row, actionable: actionable)).toList(),
    ),
  );

  Widget _enrollmentCard(
    Map<String, dynamic> row, {
    required bool actionable,
  }) {
    final status = '${row['statut'] ?? '—'}';
    final semesters = _maps(row['semestres']);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Panel(
        padding: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 12),
                  child: Icon(Icons.school_outlined),
                ),
                Expanded(
                  child: SectionTitle(
                    '${row['prenom'] ?? ''} ${row['nom'] ?? ''} · ${row['matricule']}',
                    subtitle: '${row['code_classe']} · ${row['libelle_niv']} · ${row['annee_academique'] ?? ''} · ${row['nom_depart'] ?? ''}',
                  ),
                ),
                StatusBadge(status),
              ],
            ),
            const SizedBox(height: 10),
            Text('Semestre soumis : S${row['numero_semestre']} · ${row['date_soumission'] ?? 'date non précisée'}'),
            if (semesters.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final semester in semesters)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Semestre ${semester['numero_semestre']} · ${semester['statut']}', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        ..._maps(semester['ues']).map((ue) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('• ${ue['code_ue']} · ${ue['intitule_ue']} — ${ue['statut']}'),
                        )),
                      ],
                    ),
                  ),
                ),
            ],
            if (row['fiche_academique_disponible'] == true) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _downloadAcademicSheet(row),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Consulter la fiche annuelle'),
              ),
            ],
            if (actionable) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
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
          ],
        ),
      ),
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
      if (levelId != null)
        unitsByLevel.putIfAbsent(levelId, () => []).add(unit);
    }
    for (final levelUnits in unitsByLevel.values) {
      levelUnits.sort((left, right) {
        final semesterOrder = (left['numero_semestre'] as num? ?? 0).compareTo(
          right['numero_semestre'] as num? ?? 0,
        );
        if (semesterOrder != 0) return semesterOrder;
        return '${left['code_ue']}'.compareTo('${right['code_ue']}');
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
                    label: const Text(
                      'Gérer départements, filières et parcours',
                    ),
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
                  title: Text(
                    '$year · ${classesByYear[year]!.length} classe(s)',
                  ),
                  children: classesByYear[year]!
                      .map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 16),
                          leading: const Icon(Icons.groups_outlined),
                          title: Text(
                            '${item['code_classe']} · ${item['libelle_niv']}',
                          ),
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
                subtitle: 'Syllabus courant par niveau, puis selon l’approbation du barème par la cellule informatique.',
              ),
              if (units.isEmpty)
                const EmptyState(
                  'Catalogue vide',
                  'Les unités créées en brouillon apparaîtront ici.',
                ),
              ...levels.map((level) {
                final levelId = (level['id'] as num).toInt();
                final levelUnits =
                    unitsByLevel[levelId] ?? const <Map<String, dynamic>>[];
                final approvedUnits = levelUnits
                    .where((unit) => unit['profil_evaluation'] != null)
                    .toList();
                final pendingUnits = levelUnits
                    .where((unit) => unit['profil_evaluation'] == null)
                    .toList();
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    '${level['code_f']} · ${level['code_niv']} · ${level['libelle_niv']}',
                  ),
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
                          child: Text(
                            'Aucune UE dans le catalogue pour ce niveau.',
                          ),
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
        title: Text('${unit['code_ue']} · ${unit['intitule_ue']}'),
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
                    onPressed: () =>
                        _generateAcademicLevels(dialogContext, structure),
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
          final canEdit =
              (kind != 'universite' && kind != 'faculte') ||
              item['modifiable'] != false;
          return ListTile(
            leading:
                item['logo'] is Map && (item['logo'] as Map)['base64'] is String
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
                if (canEdit &&
                    const {
                      'universite',
                      'faculte',
                      'departement',
                    }.contains(kind))
                  IconButton(
                    tooltip: item['logo'] == null
                        ? 'Ajouter le logo'
                        : 'Remplacer le logo',
                    icon: Icon(
                      item['logo'] == null
                          ? Icons.add_photo_alternate_outlined
                          : Icons.image_outlined,
                    ),
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
                      DropdownMenuItem(
                        value: 'LICENCE',
                        child: Text('Licence'),
                      ),
                      DropdownMenuItem(value: 'MASTER', child: Text('Master')),
                      DropdownMenuItem(
                        value: 'DOCTORAT',
                        child: Text('Doctorat'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialog(() => cycle = value ?? cycle),
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
                      onChanged: (value) =>
                          setDialog(() => specialtyId = value),
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
                      DropdownMenuItem(
                        value: 'LICENCE',
                        child: Text('Licence · 3 niveaux'),
                      ),
                      DropdownMenuItem(
                        value: 'MASTER',
                        child: Text('Master · 2 niveaux'),
                      ),
                      DropdownMenuItem(
                        value: 'DOCTORAT',
                        child: Text('Doctorat · 3 niveaux'),
                      ),
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
                            child: Text(
                              '${item['code_specialite']} · ${item['libelle_specialite']}',
                            ),
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
                onPressed:
                    trackId == null ||
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
                  selectedPublicationVersion = null;
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
                  selectedPublicationVersion = null;
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
                        OutlinedButton.icon(
                          onPressed: preview['pret'] == true
                              ? () => _exportCohortMinutesPdf(preview)
                              : null,
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Produire le PV récapitulatif'),
                        ),
                        OutlinedButton.icon(
                          onPressed: selectedClass == null
                              ? null
                              : () => _exportRequestMinutesPdf(selectedClass!),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Produire le PV des requêtes'),
                        ),
                      ],
                    ),
                  ),
                  if ((preview['version_courante'] as num?) != null) ...[
                    const SizedBox(height: 12),
                    _publicationArchiveControls(preview),
                  ],
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
        if (selectedClass != null && period != 'ANNUELLE') ...[
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: widget.api.agentUnitMinutes(selectedClass!, period),
            key: ValueKey('pv-ue-$selectedClass-$period-$revision'),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Notice(_error(snapshot.error!), warning: true);
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!;
              final units = _maps(data['ues']);
              return Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      'Procès-verbaux semestriels par UE',
                      subtitle: 'Document de fin de semestre établi à partir des notes calculées par GNU et des approbations enregistrées.',
                    ),
                    if (units.isEmpty)
                      const EmptyState(
                        'Aucune UE affectée',
                        'Aucune UE de ce semestre ne possède d’affectation active dans cette classe.',
                      ),
                    ...units.map((unit) {
                      final evaluations = _maps(unit['evaluations']);
                      final ready = unit['pret'] == true;
                      return Card(
                        margin: const EdgeInsets.only(top: 8),
                        child: ListTile(
                          title: Text(
                            '${unit['code_ue']} · ${unit['intitule_ue']}',
                          ),
                          subtitle: Text(
                            '${unit['effectif']} étudiant(s) · ${evaluations.length} évaluation(s) · ${ready ? 'Approbations enseignant et cellule enregistrées' : 'Approbations ou notes à compléter'}',
                          ),
                          trailing: FilledButton.tonalIcon(
                            onPressed: ready
                                ? () => _exportUnitMinutes(data, unit)
                                : null,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Produire le PV PDF'),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    const Notice(
                      'Le PDF est produit seulement lorsque chaque évaluation retenue possède le retour de la cellule publié et la vérification de l’enseignant. Les signatures manuscrites restent à apposer sur le document imprimé.',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _exportUnitMinutes(
    Map<String, dynamic> data,
    Map<String, dynamic> unit,
  ) async {
    final evaluations = _maps(unit['evaluations']);
    final students = _maps(unit['etudiants']);
    if (unit['pret'] != true || evaluations.isEmpty || students.isEmpty) {
      toast(
        context,
        'Le procès-verbal est bloqué tant que les notes et approbations ne sont pas complètes.',
      );
      return;
    }
    final structure = Map<String, dynamic>.from(
      data['structure'] as Map? ?? {},
    );
    final logoData = Map<String, dynamic>.from(structure['logo'] as Map? ?? {});
    Uint8List? logoBytes = logoData['base64'] is String
        ? base64Decode(logoData['base64'] as String)
        : null;
    if (logoBytes == null &&
        '${structure['universite'] ?? ''}'.toUpperCase().contains('YAOUND')) {
      try {
        logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer
            .asUint8List();
      } catch (_) {}
    }
    final crest = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final periodLabel = data['periode'] == 'S1' ? 'SEMESTRE 1' : 'SEMESTRE 2';
    final document = pw.Document(theme: await gnuPdfTheme());
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 28),
        header: (_) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RÉPUBLIQUE DU CAMEROUN',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Paix – Travail – Patrie',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '${structure['universite'] ?? 'UNIVERSITÉ'}'
                            .toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 52,
                  height: 52,
                  child: crest == null
                      ? null
                      : pw.Image(crest, fit: pw.BoxFit.contain),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'REPUBLIC OF CAMEROON',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Peace – Work – Fatherland',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'THE UNIVERSITY OF YAOUNDÉ I',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${structure['faculte'] ?? ''} · ${structure['departement'] ?? ''}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 1),
            pw.Text(
              'PROCÈS-VERBAL DES NOTES DE L’UNITÉ D’ENSEIGNEMENT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${unit['code_ue']} · ${unit['intitule_ue']} · $periodLabel · ${data['annee']}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Filière ${data['filiere']} · Niveau ${data['niveau']} · Classe ${data['classe']} · ${unit['credit_ue']} crédits',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 7),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'GNU · PV UE ${unit['code_ue']} · ${data['annee']}',
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.Text(
              '${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: [
              'N°',
              'MATRICULE',
              'NOMS ET PRÉNOMS',
              ...evaluations.map(
                (e) =>
                    '${e['code_ec']} ${e['type_eval'] == 'SN' ? 'SN / RATTRAPAGE' : e['type_eval']}\n${e['poids']} %',
              ),
              'TOTAL /100',
              'DÉC.',
              'MENTION',
            ],
            data: [
              for (var i = 0; i < students.length; i++)
                (() {
                  final student = students[i];
                  final marks = _maps(student['notes_evaluations']);
                  final note100 = student['note_100'];
                  final eliminated = student['eliminatoire'] == true;
                  final numeric = note100 is num ? note100.toDouble() : null;
                  final decision = eliminated
                      ? 'EL'
                      : numeric != null && numeric >= 35
                      ? (numeric >= 50 ? 'CA' : 'CANT')
                      : 'NC';
                  return [
                    '${i + 1}',
                    '${student['matricule']}',
                    '${student['nom']} ${student['prenom']}',
                    for (var j = 0; j < evaluations.length; j++)
                      (() {
                        final mark = j < marks.length
                            ? marks[j]
                            : <String, dynamic>{};
                        if (mark['situation'] == 'ABSENTE' ||
                            mark['situation'] == 'MANQUANTE')
                          return 'EL';
                        final points = mark['points_pondere'];
                        if (points is num) {
                          final replacement = mark['rattrapage'] == true;
                          return '${replacement ? 'R ' : ''}${points.toStringAsFixed(2)}';
                        }
                        return mark['valeur'] == null
                            ? '—'
                            : '${mark['valeur']}';
                      })(),
                    numeric?.toStringAsFixed(2) ?? '—',
                    decision,
                    '${student['mention'] ?? 'EL'}',
                  ];
                })(),
            ],
            headerStyle: pw.TextStyle(
              fontSize: 6.6,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.4),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {2: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .45),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 4,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Les colonnes présentent les points pondérés retenus dans le calcul officiel de l’UE. « R » indique qu’une note de rattrapage a remplacé la note de SN pour l’étudiant concerné. Le total est sur 100.',
            style: const pw.TextStyle(fontSize: 7),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'STATISTIQUES DE VALIDATION · Effectif : ${unit['effectif']} · CA : ${unit['ca']} (${unit['ca_pct']} %) · CANT : ${unit['cant']} (${unit['cant_pct']} %) · NC : ${unit['nc']} (${unit['nc_pct']} %) · EL : ${unit['el']} (${unit['el_pct']} %)',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Approbations GNU enregistrées pour chaque évaluation :',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          ...evaluations.map(
            (e) => pw.Text(
              '${e['code_ec']} · ${e['type_eval']} : enseignant ${e['enseignant'] ?? '—'} (${e['enseignant_le'] ?? '—'}) ; cellule ${e['cellule'] ?? '—'} (${e['cellule_le'] ?? '—'})',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Les approbations numériques ci-dessus attestent du contrôle et de la vérification des notes. Les signatures manuscrites et le cachet sont apposés sur l’exemplaire officiel.',
            style: const pw.TextStyle(fontSize: 7),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: _unitMinutesSignature(
                  'Enseignant(s) responsable(s) · vérification enregistrée',
                ),
              ),
              pw.SizedBox(width: 28),
              pw.Expanded(
                child: _unitMinutesSignature(
                  'Cellule informatique · contrôle enregistré',
                ),
              ),
              pw.SizedBox(width: 28),
              pw.Expanded(
                child: _unitMinutesSignature(
                  'Chef de département · signature et cachet',
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final filename =
        'PV-UE-${unit['code_ue']}-${data['classe']}-${data['periode']}-${data['annee']}.pdf';
    await downloadFile(filename, await document.save());
  }

  pw.Widget _unitMinutesSignature(String title) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 34),
      pw.Container(height: .6, color: pdf.PdfColors.black),
    ],
  );

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
                const Expanded(child: SectionTitle('Règles de publication')),
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
            Text(
              '${data['source'] ?? 'Règles académiques officielles de l’Université'}.',
            ),
          ],
        ),
      );
    },
  );

  Widget _publicationArchiveControls(Map<String, dynamic> preview) {
    final classId = (preview['classe_id'] as num?)?.toInt() ?? selectedClass;
    if (classId == null) return const SizedBox.shrink();
    final historyFuture = publicationHistoryFutures.putIfAbsent(
      classId,
      () => widget.api.agentPublicationHistory(classId),
    );

    return FutureBuilder<Map<String, dynamic>>(
      future: historyFuture,
      key: ValueKey('publication-history-$classId-$revision'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Notice(_error(snapshot.error!), warning: true);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final publications = _maps(snapshot.data?['publications'])
            .where((item) => item['periode'] == period)
            .toList();
        if (publications.isEmpty) return const SizedBox.shrink();

        final current = publications.where((item) => item['courante'] == true);
        final latest = current.isNotEmpty
            ? current.first
            : publications.reduce(
                (left, right) => (left['version'] as num).compareTo(
                          right['version'] as num,
                        ) >=
                        0
                    ? left
                    : right,
              );
        final selected = publications.where(
          (item) => (item['version'] as num?)?.toInt() == selectedPublicationVersion,
        );
        final versionRow = selected.isNotEmpty ? selected.first : latest;
        final version = (versionRow['version'] as num).toInt();

        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Historique des bulletins publiés',
                subtitle: 'Classe ${preview['code_classe'] ?? ''} · $period · ${publications.length} version(s)',
              ),
              DropdownButtonFormField<int>(
                initialValue: version,
                decoration: const InputDecoration(labelText: 'Version officielle'),
                items: publications.map((item) {
                  final itemVersion = (item['version'] as num).toInt();
                  final date = '${item['date_publication'] ?? ''}'.split('T').first;
                  final currentLabel = item['courante'] == true ? ' · courante' : '';
                  return DropdownMenuItem(
                    value: itemVersion,
                    child: Text(
                      'V$itemVersion · $date · ${item['nombre_bulletins'] ?? 0} bulletin(s)$currentLabel',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedPublicationVersion = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _printPublishedBulletinsPdf(preview, version),
                    icon: const Icon(Icons.print_outlined),
                    label: Text('Imprimer les bulletins · V$version'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportPublishedBulletinsPdf(preview, version),
                    icon: const Icon(Icons.download_outlined),
                    label: Text('Télécharger le PDF · V$version'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportBulletinsExcel(
                      preview,
                      published: true,
                      version: version,
                    ),
                    icon: const Icon(Icons.grid_on_outlined),
                    label: Text('Exporter Excel · V$version'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportBulletinsExcel(
    Map<String, dynamic> preview, {
    bool published = false,
    int? version,
  }) async {
    final classId = (preview['classe_id'] as num?)?.toInt() ?? selectedClass;
    if (classId == null) return;
    try {
      final bytes = await widget.api.agentExportBulletins(
        classId,
        period,
        published: published,
        version: version,
      );
      final code = '${preview['code_classe'] ?? 'classe'}';
      await downloadFile(
        'bulletins-$code-$period-${published ? 'officiel-v${version ?? 'courante'}' : 'apercu'}.xlsx',
        bytes,
      );
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _exportCohortMinutesPdf(Map<String, dynamic> preview) async {
    final students = _maps(preview['etudiants']);
    if (students.isEmpty || students.any((row) => row['pret'] != true)) {
      toast(
        context,
        'Les bulletins de toute la classe doivent être calculables avant de produire le PV récapitulatif.',
      );
      return;
    }
    final structure = Map<String, dynamic>.from(
      preview['structure'] as Map? ?? {},
    );
    final logoData = Map<String, dynamic>.from(structure['logo'] as Map? ?? {});
    Uint8List? logoBytes = logoData['base64'] is String
        ? base64Decode(logoData['base64'] as String)
        : null;
    if (logoBytes == null) {
      try {
        logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer
            .asUint8List();
      } catch (_) {}
    }
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final unitsByCode = <String, Map<String, dynamic>>{};
    for (final student in students) {
      final content = Map<String, dynamic>.from(
        student['contenu'] as Map? ?? {},
      );
      for (final unit in _maps(content['ues'])) {
        final code = '${unit['code_ue'] ?? ''}';
        if (code.isNotEmpty) unitsByCode.putIfAbsent(code, () => unit);
      }
    }
    final units = unitsByCode.values.toList()
      ..sort((left, right) {
        final leftSemester = '${left['semestre'] ?? ''}';
        final rightSemester = '${right['semestre'] ?? ''}';
        final semesterOrder = leftSemester.compareTo(rightSemester);
        return semesterOrder != 0
            ? semesterOrder
            : '${left['code_ue']}'.compareTo('${right['code_ue']}');
      });
    final periodLabel = switch (preview['periode']) {
      'S1' => 'SEMESTRE 1',
      'S2' => 'SEMESTRE 2',
      _ => 'ANNÉE ACADÉMIQUE',
    };
    final document = pw.Document(theme: await gnuPdfTheme());
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 26),
        header: (_) => gnuPvHeader(
          crest: logo,
          university: '${structure['universite'] ?? 'UNIVERSITÉ DE YAOUNDÉ I'}',
          faculty: '${structure['faculte'] ?? 'FACULTÉ'}',
          department: '${structure['departement'] ?? 'DÉPARTEMENT'}',
          title: 'PROCÈS-VERBAL DE SYNTHÈSE DES RÉSULTATS',
          subtitle:
              '${structure['filiere'] ?? ''} · ${structure['specialite'] ?? ''}',
          details:
              '${structure['niveau'] ?? preview['niveau'] ?? ''} · ${preview['code_classe'] ?? ''} · $periodLabel · ${preview['annee_academique'] ?? ''}',
          status: (preview['version_courante'] as num?) == null
              ? 'APERÇU · NON OFFICIEL'
              : 'VERSION PUBLIÉE ${preview['version_courante']}',
        ),
        footer: (context) => gnuPvFooter(
          'GNU · ${preview['code_classe'] ?? ''} · ${preview['annee_academique'] ?? ''}',
          context,
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: [
              'N°',
              'NOMS ET PRÉNOMS',
              'MATRICULE',
              'NIVEAU',
              ...units.map(
                (unit) => '${unit['code_ue']}\n${unit['credit'] ?? 0} cr.',
              ),
              'CRÉDITS ACQUIS',
              'MGP',
              'DÉCISION',
            ],
            data: [
              for (var index = 0; index < students.length; index++)
                (() {
                  final student = students[index];
                  final content = Map<String, dynamic>.from(
                    student['contenu'] as Map? ?? {},
                  );
                  final studentUnits = {
                    for (final unit in _maps(content['ues']))
                      '${unit['code_ue']}': unit,
                  };
                  final mgpKey = preview['periode'] == 'ANNUELLE'
                      ? 'mgp_total'
                      : 'mgp_${preview['periode']}'.toLowerCase();
                  final acquired = _maps(content['ues']).fold<double>(
                    0,
                    (sum, unit) =>
                        sum +
                        (((unit['arrondi'] as num?) ?? 0) >= 35
                            ? ((unit['credit'] as num?)?.toDouble() ?? 0)
                            : 0),
                  );
                  final registered =
                      (content['total_credits'] as num?)?.toDouble() ?? 0;
                  return [
                    '${index + 1}',
                    '${student['nom'] ?? ''} ${student['prenom'] ?? ''}',
                    '${student['matricule'] ?? ''}',
                    '${structure['niveau'] ?? preview['niveau'] ?? ''}',
                    ...units.map((unit) {
                      final result = studentUnits['${unit['code_ue']}'];
                      return result == null
                          ? '—'
                          : result['arrondi'] == null
                          ? 'EL'
                          : '${result['arrondi']}\n${result['grade'] ?? ''}';
                    }),
                    '${acquired.toStringAsFixed(0)}/${registered.toStringAsFixed(0)}',
                    '${content[mgpKey] ?? '—'}',
                    '${content['decision_admission'] ?? '—'}',
                  ];
                })(),
            ],
            headerStyle: pw.TextStyle(
              fontSize: 6.2,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.1),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {1: pw.Alignment.centerLeft},
            headerDecoration: const pw.BoxDecoration(
              color: pdf.PdfColor(.86, .91, .89),
            ),
            border: pw.TableBorder.all(
              color: pdf.PdfColors.blueGrey800,
              width: .45,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 3,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Effectif : ${students.length} · Crédit acquis : total de cohorte ${students.fold<double>(0, (sum, row) {
              final content = Map<String, dynamic>.from(row['contenu'] as Map? ?? {});
              return sum + _maps(content['ues']).fold<double>(0, (credits, unit) => credits + (((unit['arrondi'] as num?) ?? 0) >= 35 ? ((unit['credit'] as num?)?.toDouble() ?? 0) : 0));
            }).toStringAsFixed(0)}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                child: _transcriptSignature(
                  'Le Président du Jury / President of the Jury',
                ),
              ),
              pw.SizedBox(width: 30),
              pw.Expanded(
                child: _transcriptSignature(
                  'Le Chef de Département / Head of Department',
                ),
              ),
            ],
          ),
          pw.Center(
            child: pw.Text(
              'Les signatures et le cachet seront apposés après validation officielle.',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
        ],
      ),
    );
    try {
      final name =
          'PV-recapitulatif-${preview['code_classe'] ?? 'classe'}-${preview['periode']}-${preview['annee_academique'] ?? ''}.pdf';
      await downloadFile(name, await document.save());
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _exportRequestMinutesPdf(int classId) async {
    try {
      final data = await widget.api.agentRequestMinutes(classId, period);
      final requests = _maps(data['requetes']);
      if (requests.isEmpty) {
        toast(
          context,
          'Aucune requête ne correspond à cette classe et cette période.',
        );
        return;
      }
      final structure = Map<String, dynamic>.from(
        data['structure'] as Map? ?? {},
      );
      final logoData = Map<String, dynamic>.from(
        structure['logo'] as Map? ?? {},
      );
      Uint8List? logoBytes = logoData['base64'] is String
          ? base64Decode(logoData['base64'] as String)
          : null;
      if (logoBytes == null) {
        try {
          logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer
              .asUint8List();
        } catch (_) {}
      }
      final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
      final ready = data['pret'] == true;
      final periodLabel = switch (period) {
        'S1' => 'SEMESTRE 1',
        'S2' => 'SEMESTRE 2',
        _ => 'ANNÉE ACADÉMIQUE',
      };
      final document = pw.Document(theme: await gnuPdfTheme());
      document.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 26),
          header: (_) => pw.Column(
            children: [
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _transcriptHeaderSide(
                      'RÉPUBLIQUE DU CAMEROUN',
                      'Paix - Travail - Patrie',
                      '${structure['universite'] ?? 'UNIVERSITÉ'}',
                    ),
                  ),
                  pw.SizedBox(
                    width: 48,
                    height: 48,
                    child: logo == null
                        ? null
                        : pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                  pw.Expanded(
                    child: _transcriptHeaderSide(
                      'REPUBLIC OF CAMEROON',
                      'Peace - Work - Fatherland',
                      'THE ${structure['universite'] ?? 'UNIVERSITY'}',
                    ),
                  ),
                ],
              ),
              pw.Text(
                '${structure['faculte'] ?? 'FACULTÉ'} · ${structure['departement'] ?? 'DÉPARTEMENT'}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.Text(
                'PROCÈS-VERBAL DES REQUÊTES ÉTUDIANTES',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${structure['filiere'] ?? data['filiere'] ?? ''} · ${structure['specialite'] ?? ''} · ${data['niveau'] ?? ''} · ${data['classe'] ?? ''} · $periodLabel · ${data['annee'] ?? ''}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                ready
                    ? 'REQUÊTES DÉCIDÉES'
                    : 'PROJET · ${data['en_attente'] ?? 0} REQUÊTE(S) EN ATTENTE',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GNU · Document réservé aux personnes habilitées · ${data['annee'] ?? ''}',
                style: const pw.TextStyle(fontSize: 6),
              ),
              pw.Text(
                '${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 6),
              ),
            ],
          ),
          build: (_) => [
            pw.TableHelper.fromTextArray(
              headers: const [
                'N°',
                'SOUMISE LE',
                'MATRICULE',
                'ÉTUDIANT',
                'UE / EC',
                'TYPE',
                'MOTIF',
                'NOTE',
                'DÉCISION / STATUT',
                'EXAMINATEUR',
              ],
              data: [
                for (var i = 0; i < requests.length; i++)
                  [
                    '${i + 1}',
                    '${requests[i]['soumise_le'] ?? ''}',
                    '${requests[i]['matricule'] ?? ''}',
                    '${requests[i]['nom'] ?? ''} ${requests[i]['prenom'] ?? ''}',
                    '${requests[i]['code_ue'] ?? ''} ${requests[i]['code_ec'] ?? ''}',
                    '${requests[i]['type'] ?? ''} · ${requests[i]['evaluation'] ?? ''}',
                    '${requests[i]['objet'] ?? ''}\n${requests[i]['description'] ?? ''}',
                    requests[i]['situation_note'] == 'ABSENTE' ||
                            requests[i]['situation_note'] == 'MANQUANTE'
                        ? 'EL'
                        : '${requests[i]['note_courante'] ?? '—'}',
                    '${requests[i]['decision'] ?? 'EN ATTENTE'}\n${requests[i]['motif_decision'] ?? requests[i]['statut'] ?? ''}',
                    '${requests[i]['examinateur'] ?? '—'}',
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 5.8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 5.6),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {
                3: pw.Alignment.centerLeft,
                6: pw.Alignment.centerLeft,
                8: pw.Alignment.centerLeft,
              },
              border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .4),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 3,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Effectif des requêtes : ${requests.length} · En attente : ${data['en_attente'] ?? 0} · Ce document restitue les requêtes et décisions enregistrées dans GNU ; il ne remplace pas une délibération de jury non saisie dans le système.',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _transcriptSignature(
                    'Rapporteur / Secrétariat du jury',
                  ),
                ),
                pw.SizedBox(width: 25),
                pw.Expanded(child: _transcriptSignature('Président du Jury')),
                pw.SizedBox(width: 25),
                pw.Expanded(child: _transcriptSignature('Chef de Département')),
              ],
            ),
          ],
        ),
      );
      final name =
          'PV-requetes-${data['classe'] ?? 'classe'}-$period-${data['annee'] ?? ''}.pdf';
      await downloadFile(name, await document.save());
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _exportBulletinPreviewsPdf(Map<String, dynamic> preview) async {
    final students = _maps(preview['etudiants']);
    if (students.isEmpty || students.any((row) => row['pret'] != true)) {
      toast(
        context,
        'Tous les dossiers doivent être calculables pour générer les aperçus PDF.',
      );
      return;
    }
    final structure = Map<String, dynamic>.from(
      preview['structure'] as Map? ?? {},
    );
    final logoData = Map<String, dynamic>.from(
      structure['logo'] as Map? ?? {},
    );
    Uint8List? logoBytes;
    if (logoData['base64'] is String) {
      logoBytes = base64Decode(logoData['base64'] as String);
    } else if ('${structure['universite'] ?? ''}'.toUpperCase().contains('YAOUNDÉ I') ||
        '${structure['universite'] ?? ''}'.toUpperCase().contains('YAOUNDE I')) {
      logoBytes = (await rootBundle.load('assets/uy1_crest.png'))
          .buffer
          .asUint8List();
    }
    try {
      final bytes = await buildAcademicBulletinsPdf(
        bulletins: students,
        structure: structure,
        period: period,
        academicYear: '${preview['annee_academique'] ?? '—'}',
        official: false,
        crest: logoBytes == null ? null : pw.MemoryImage(logoBytes),
      );
      final filename =
          'apercus-bulletins-${preview['code_classe'] ?? 'classe'}-$period.pdf';
      await downloadFile(filename, bytes);
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _exportPublishedBulletinsPdf(
    Map<String, dynamic> preview,
    int version,
  ) async {
    final classId = (preview['classe_id'] as num?)?.toInt() ?? selectedClass;
    if (classId == null) return;
    try {
      final published = await widget.api.agentPublishedBulletins(
        classId,
        period,
        version: version,
      );
      final students = _maps(published['etudiants']);
      if (students.isEmpty) {
        toast(context, 'Aucun bulletin officiel n’est disponible pour cette période.');
        return;
      }
      final structure = Map<String, dynamic>.from(
        published['structure'] as Map? ?? {},
      );
      final logoData = Map<String, dynamic>.from(structure['logo'] as Map? ?? {});
      Uint8List? logoBytes;
      if (logoData['base64'] is String) {
        logoBytes = base64Decode(logoData['base64'] as String);
      } else {
        try {
          logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer.asUint8List();
        } catch (_) {}
      }
      final bytes = await buildAcademicBulletinsPdf(
        bulletins: students,
        structure: structure,
        period: period,
        academicYear: '${published['annee_academique'] ?? '—'}',
        official: true,
        crest: logoBytes == null ? null : pw.MemoryImage(logoBytes),
      );
      await downloadFile(_publishedBulletinsFilename(published), bytes);
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  Future<void> _printPublishedBulletinsPdf(
    Map<String, dynamic> preview,
    int version,
  ) async {
    final classId = (preview['classe_id'] as num?)?.toInt() ?? selectedClass;
    if (classId == null) return;
    try {
      final published = await widget.api.agentPublishedBulletins(
        classId,
        period,
        version: version,
      );
      final students = _maps(published['etudiants']);
      if (students.isEmpty) {
        toast(context, 'Aucun bulletin officiel n’est disponible pour cette version.');
        return;
      }
      final structure = Map<String, dynamic>.from(published['structure'] as Map? ?? {});
      final logoData = Map<String, dynamic>.from(structure['logo'] as Map? ?? {});
      Uint8List? logoBytes;
      if (logoData['base64'] is String) {
        logoBytes = base64Decode(logoData['base64'] as String);
      } else {
        try {
          logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer.asUint8List();
        } catch (_) {}
      }
      final bytes = await buildAcademicBulletinsPdf(
        bulletins: students,
        structure: structure,
        period: period,
        academicYear: '${published['annee_academique'] ?? '—'}',
        official: true,
        crest: logoBytes == null ? null : pw.MemoryImage(logoBytes),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _publishedBulletinsFilename(published),
      );
    } catch (error) {
      if (mounted) toast(context, _error(error));
    }
  }

  String _publishedBulletinsFilename(Map<String, dynamic> published) =>
      'bulletins-officiels-${published['code_classe'] ?? 'classe'}-$period-V${published['version']}.pdf';

  pw.Widget _transcriptHeaderSide(
    String title,
    String motto,
    String institution,
  ) => pw.Column(
    children: [
      pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        motto,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 7),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        institution,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  pw.Widget _transcriptInfo(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(2, 3, 5, 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label : ',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    ),
  );

  pw.Widget _transcriptSignature(String title) => pw.Column(
    children: [
      pw.SizedBox(height: 25),
      pw.Container(height: 1, color: pdf.PdfColors.black),
      pw.SizedBox(height: 3),
      pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 7),
      ),
      pw.SizedBox(height: 42),
    ],
  );

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
                Text(
                  '${item['code_classe']} · ${item['code_m']} · Session normale',
                ),
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
                  label: Text(
                    'Date : ${date.toIso8601String().substring(0, 10)}',
                  ),
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
                          if (selected != null)
                            setDialog(() => start = selected);
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                  setDialog(
                    () => validationMessage =
                        'L’heure de fin doit suivre l’heure de début.',
                  );
                  return;
                }
                if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{0,31}$')
                    .hasMatch(normalizedRoom)) {
                  setDialog(
                    () => validationMessage = 'Saisissez un code de salle simple, par exemple A101 ou LAB-02.',
                  );
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
                if (account['supprime_le'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Compte supprimé le : ${account['supprime_le']}'),
                  Text('Motif : ${account['motif_suppression'] ?? '—'}'),
                ],
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
          if (account['gestionnable'] != false &&
              account['role'] != 'AGENT' &&
              account['supprime_le'] == null)
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
    final dateNaissance = TextEditingController(
      text: '${account['date_naissance'] ?? ''}',
    );
    final lieuNaissance = TextEditingController(
      text: '${account['lieu_naissance'] ?? ''}',
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
                if (account['role'] == 'ETUDIANT') ...[
                  TextField(
                    controller: dateNaissance,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Date de naissance',
                      hintText: 'AAAA-MM-JJ',
                    ),
                  ),
                  TextField(
                    controller: lieuNaissance,
                    decoration: const InputDecoration(
                      labelText: 'Lieu de naissance',
                    ),
                  ),
                ],
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
                  if (account['role'] == 'ETUDIANT') ...{
                    'date_naissance': dateNaissance.text.trim(),
                    'lieu_naissance': lieuNaissance.text.trim(),
                  },
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
    dateNaissance.dispose();
    lieuNaissance.dispose();
    motif.dispose();
    if (result == null) return;
    await _mutate(
      () => widget.api.agentUpdateAccount(account['id'] as int, {
        ...result,
        'courriel': result['courriel']!.isEmpty ? null : result['courriel'],
        if (result['date_naissance'] != null)
          'date_naissance': result['date_naissance']!.isEmpty
              ? null
              : result['date_naissance'],
        if (result['lieu_naissance'] != null)
          'lieu_naissance': result['lieu_naissance']!.isEmpty
              ? null
              : result['lieu_naissance'],
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
