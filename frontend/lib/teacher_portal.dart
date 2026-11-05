import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'api_client.dart';
import 'file_download.dart';
import 'ui.dart';

final _gradeScorePattern = RegExp(r'^-?\d{0,2}(?:[.,]\d{0,2})?$');

TextInputFormatter _gradeScoreFormatter() => TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      _gradeScorePattern.hasMatch(newValue.text) ? newValue : oldValue,
);

class TeacherRoomsSection extends StatefulWidget {
  const TeacherRoomsSection({
    super.key,
    required this.api,
    this.onOpenGradebook,
  });

  final StudentApiClient api;
  final void Function(Map<String, dynamic>)? onOpenGradebook;

  @override
  State<TeacherRoomsSection> createState() => _TeacherRoomsSectionState();
}

class _TeacherRoomsSectionState extends State<TeacherRoomsSection> {
  late Future<Map<String, dynamic>> rooms;
  String? yearId;

  @override
  void initState() {
    super.initState();
    rooms = widget.api.teacherRooms();
  }

  void _load([String? id]) {
    setState(() {
      yearId = id;
      rooms = widget.api.teacherRooms(yearId: id);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        'Niveaux et étudiants',
        subtitle: 'Parcourez les niveaux de tous les départements, sélectionnez ceux de l’année en cours et retrouvez vos choix antérieurs.',
      ),
      FutureBuilder<Map<String, dynamic>>(
        future: rooms,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chargement des niveaux impossible : ${snapshot.error}',
                    ),
                  ),
                  IconButton(
                    onPressed: () => _load(yearId),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Panel(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final result = snapshot.data!;
          final years = (result['annees'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          final effectiveYear = yearId ?? '${result['annee_id'] ?? ''}';
          final currentYearId = '${result['annee_courante_id'] ?? ''}';
          final items = (result['data'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          return Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        years.any((row) => '${row['id']}' == effectiveYear)
                        ? effectiveYear
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Année académique',
                    ),
                    items: years
                        .map(
                          (row) => DropdownMenuItem<String>(
                            value: '${row['id']}',
                            child: Text('${row['libelle']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != effectiveYear) _load(value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const EmptyState(
                    'Aucun niveau pour cette année',
                    'Choisissez une autre année académique ou un autre département.',
                  )
                else
                  ...items.map((room) => _roomTile(room, currentYearId)),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _roomTile(Map<String, dynamic> room, String currentYearId) {
    final classId = (room['classe_id'] as num?)?.toInt();
    final joined = room['choisie'] == true;
    final isCurrentYear = '${room['annee_id']}' == currentYearId;
    final specialty = room['libelle_specialite'];
    final details = [
      room['libelle_niv'],
      room['code_f'],
      ?specialty,
      room['nom_depart'],
      '${room['effectif_selectionnee'] ?? (joined ? room['effectif'] : 0)} étudiant(s) inscrit(s)',
    ].where((part) => part != null && '$part'.isNotEmpty).join(' · ');

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            joined ? Icons.meeting_room : Icons.door_front_door_outlined,
          ),
          title: Text('${room['code_classe']} · ${room['annee_academique']}'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(details),
          ),
          trailing: joined
              ? FilledButton.tonalIcon(
                  onPressed: classId == null
                      ? null
                      : () => _showStudents(classId, room),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Ouvrir le niveau'),
                )
              : isCurrentYear
              ? FilledButton.icon(
                  onPressed: classId == null ? null : () => _join(classId),
                  icon: const Icon(Icons.add),
                  label: const Text('Choisir ce niveau'),
                )
              : const Chip(label: Text('Année antérieure')),
        ),
      ),
    );
  }

  Future<void> _join(int classId) async {
    try {
      await widget.api.teacherJoinRoom(classId);
      if (!mounted) return;
      toast(context, 'Vous avez rejoint cette salle.');
      _load(yearId);
    } catch (error) {
      if (mounted) toast(context, '$error');
    }
  }

  Future<void> _showStudents(int classId, Map<String, dynamic> room) async {
    late final Map<String, dynamic> studentsResponse;
    try {
      studentsResponse = await widget.api.teacherRoomStudents(classId);
    } catch (error) {
      if (mounted) {
        toast(context, 'Chargement du niveau impossible : $error');
      }
      return;
    }
    if (!mounted) return;
    final selection = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => DefaultTabController(
            length: 2,
            child: AlertDialog(
              title: Text('Niveau ${room['code_classe']}'),
              content: SizedBox(
                width: 620,
                height: (MediaQuery.sizeOf(context).height * 0.62)
                    .clamp(280.0, 500.0),
                child: _RoomDetails(
                  api: widget.api,
                  classId: classId,
                  room: room,
                  studentsResponse: studentsResponse,
                  onChooseAssignment: (assignment) =>
                      Navigator.pop(context, assignment),
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
        );
    if (selection != null && mounted) {
      widget.onOpenGradebook?.call(selection);
    }
  }
}

class _RoomDetails extends StatefulWidget {
  const _RoomDetails({
    required this.api,
    required this.classId,
    required this.room,
    required this.studentsResponse,
    required this.onChooseAssignment,
  });

  final StudentApiClient api;
  final int classId;
  final Map<String, dynamic> room;
  final Map<String, dynamic> studentsResponse;
  final void Function(Map<String, dynamic>) onChooseAssignment;

  @override
  State<_RoomDetails> createState() => _RoomDetailsState();
}

class _RoomDetailsState extends State<_RoomDetails> {
  String query = '';
  int semester = 1;
  late Future<List<Map<String, dynamic>>> courseOptions;
  final Set<int> selectedCourseIds = {};
  bool submittingSelection = false;

  @override
  void initState() {
    super.initState();
    courseOptions = _loadCourseOptions();
  }

  Future<List<Map<String, dynamic>>> _loadCourseOptions() =>
      widget.api.teacherCourseOptions(widget.classId, semester: semester);

  @override
  Widget build(BuildContext context) {
    final allStudents = (widget.studentsResponse['data'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final students = allStudents
        .where((student) {
          final search = query.trim().toLowerCase();
          return search.isEmpty ||
              '${student['nom']} ${student['prenom']} ${student['matricule']}'
                  .toLowerCase()
                  .contains(search);
        })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.room['annee_academique']} · Niveau ${widget.room['libelle_niv'] ?? '—'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RoomMetric(
                icon: Icons.groups_outlined,
                label: 'Effectif du niveau',
                value: '${widget.room['effectif'] ?? students.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoomMetric(
                icon: Icons.people_alt_outlined,
                label: 'Étudiants inscrits',
                value: '${allStudents.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const TabBar(
          tabs: [
            Tab(text: 'Matières', icon: Icon(Icons.menu_book_outlined)),
            Tab(text: 'Étudiants', icon: Icon(Icons.groups_outlined)),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [_coursePicker(), _studentPicker(students, allStudents)],
          ),
        ),
      ],
    );
  }

  Widget _coursePicker() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: DropdownButtonFormField<int>(
          initialValue: semester,
          decoration: const InputDecoration(labelText: 'Semestre'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Semestre 1')),
            DropdownMenuItem(value: 2, child: Text('Semestre 2')),
          ],
          onChanged: (value) {
            if (value == null || value == semester) return;
            setState(() {
              semester = value;
              selectedCourseIds.clear();
              courseOptions = _loadCourseOptions();
            });
          },
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: courseOptions,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 30),
                      const SizedBox(height: 8),
                      const Text('Chargement du catalogue impossible.'),
                      const SizedBox(height: 4),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          courseOptions = _loadCourseOptions();
                        }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recharger les matières'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const EmptyState(
                'Aucune matière active',
                'La cellule doit activer le catalogue de ce niveau et de ce semestre.',
              );
            }
            final allUnits = snapshot.data!;
            return Column(
              children: [
                if (allUnits.any(
                  (unit) => unit['propositions_disponibles'] == false,
                ))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Le catalogue est visible, mais la transmission des choix d’UE/EC est désactivée : appliquez les migrations GNU côté serveur.',
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    itemCount: allUnits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _unitTile(allUnits[index]),
                  ),
                ),
                if (selectedCourseIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: submittingSelection
                            ? null
                            : () => _submitSelectedCourses(allUnits),
                        icon: submittingSelection
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          submittingSelection
                              ? 'Transmission en cours…'
                              : 'Transmettre ${selectedCourseIds.length} choix à l’agent',
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _unitTile(Map<String, dynamic> unit) {
    final proposalsAvailable = unit['propositions_disponibles'] != false;
    final elements = (unit['elements'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final availableCount = elements.where((element) {
      final status = element['statut_affectation']?.toString();
      return proposalsAvailable && (status == null || status == 'REJETEE');
    }).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          '${unit['code_ue']} · ${unit['intitule_ue']}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('Semestre $semester · ${elements.length} EC'),
        ),
        children: [
          if (availableCount > 0 && proposalsAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    final selectable = elements.where(_isSelectable);
                    final ids = selectable
                        .map((element) => (element['id'] as num).toInt())
                        .toSet();
                    if (ids.every(selectedCourseIds.contains)) {
                      selectedCourseIds.removeAll(ids);
                    } else {
                      selectedCourseIds.addAll(ids);
                    }
                  }),
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  label: Text('Valider tous mes choix ($availableCount EC)'),
                ),
              ),
            ),
          for (final element in elements) _courseTile(unit, element, proposalsAvailable),
        ],
      ),
    );
  }

  bool _isSelectable(Map<String, dynamic> element) {
    final status = element['statut_affectation']?.toString();
    return element['peut_demander_separement'] != false &&
        (status == null || status == 'REJETEE');
  }

  Future<void> _submitSelectedCourses(
    List<Map<String, dynamic>> units,
  ) async {
    if (selectedCourseIds.isEmpty || submittingSelection) return;
    final choices =
        <({Map<String, dynamic> unit, Map<String, dynamic> element})>[];
    for (final unit in units) {
      final elements = (unit['elements'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row));
      for (final element in elements) {
        final id = (element['id'] as num?)?.toInt();
        if (id != null &&
            selectedCourseIds.contains(id) &&
            _isSelectable(element)) {
          choices.add((unit: unit, element: element));
        }
      }
    }
    if (choices.isEmpty) {
      setState(() => selectedCourseIds.clear());
      toast(
        context,
        'Les choix sélectionnés ne sont plus disponibles. Actualisez le catalogue.',
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Valider ${choices.length} choix d’enseignement'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirmez les UE ou EC que vous acceptez d’enseigner. La sélection sera transmise à l’agent de la cellule pour validation.',
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 170),
                child: ListView(
                  shrinkWrap: true,
                  children: choices
                      .map(
                        (choice) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            '• ${choice.unit['code_ue']} · ${choice.element['code_m']} — ${choice.element['intitule_matiere']}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Transmettre à la cellule'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => submittingSelection = true);
    var submitted = 0;
    final errors = <String>[];
    try {
      for (final choice in choices) {
        try {
          await widget.api.teacherProposeAssignment(
            widget.classId,
            courseId: (choice.element['id'] as num).toInt(),
          );
          submitted++;
        } catch (error) {
          errors.add('${choice.element['code_m']}: $error');
        }
      }
      if (!mounted) return;
      setState(() {
        selectedCourseIds.clear();
        courseOptions = _loadCourseOptions();
      });
      final message = submitted == choices.length
          ? '$submitted choix transmis à l’agent de la cellule pour validation.'
          : submitted == 0
          ? 'Aucun choix transmis. ${errors.take(2).join(' ')}'
          : '$submitted/${choices.length} choix transmis. ${errors.take(2).join(' ')}';
      toast(context, message);
    } catch (error) {
      if (mounted) toast(context, '$submitted/${choices.length} choix transmis. $error');
    } finally {
      if (mounted) setState(() => submittingSelection = false);
    }
  }

  Future<void> _proposeUnit(
    Map<String, dynamic> unit,
    int availableCount,
  ) async {
    final ids = (unit['elements'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where(_isSelectable)
        .map((element) => (element['id'] as num).toInt())
        .toSet();
    if (ids.isEmpty) return;
    setState(() {
      if (ids.every(selectedCourseIds.contains)) {
        selectedCourseIds.removeAll(ids);
      } else {
        selectedCourseIds.addAll(ids);
      }
    });
  }

  Widget _courseTile(
    Map<String, dynamic> unit,
    Map<String, dynamic> element,
    bool proposalsAvailable,
  ) {
    final status = element['statut_affectation']?.toString();
    final assignmentId = (element['affectation_id'] as num?)?.toInt();
    final assignment = {
      'affectation_id': assignmentId,
      'code_ue': unit['code_ue'],
      'intitule_ue': unit['intitule_ue'],
      'numero_semestre': semester,
      'code_m': element['code_m'],
      'intitule_matiere': element['intitule_matiere'],
      'code_classe': widget.room['code_classe'],
      'affectation_active': status == 'APPROUVEE',
    };
    final canSelect = _isSelectable(element);
    final selectedId = (element['id'] as num?)?.toInt();
    final selected = selectedId != null && selectedCourseIds.contains(selectedId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected
          ? Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.5)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canSelect && selectedId != null)
                  Checkbox(
                    value: selected,
                    onChanged: submittingSelection
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selectedCourseIds.add(selectedId);
                            } else {
                              selectedCourseIds.remove(selectedId);
                            }
                          }),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${element['code_m']} · ${element['intitule_matiere']}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          switch (status) {
                            'APPROUVEE' => 'Affectation approuvée',
                            'EN_ATTENTE' =>
                              'Choix en attente de validation · carnet provisoire accessible',
                            'REJETEE' =>
                              (element['motif_decision']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ??
                                      false)
                                  ? 'Refusée : ${element['motif_decision']}'
                                  : 'Choix refusé · vous pouvez le soumettre à nouveau',
                            'INDISPONIBLE' =>
                              'Déjà attribuée ou en attente dans cette classe',
                            _ => 'Aucun choix transmis',
                          },
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (status == 'APPROUVEE' || status == 'EN_ATTENTE')
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: assignmentId == null
                      ? null
                      : () => widget.onChooseAssignment(assignment),
                  icon: const Icon(Icons.edit_note),
                  label: Text(
                    status == 'EN_ATTENTE'
                        ? 'Ouvrir le brouillon'
                        : 'Ouvrir le carnet',
                  ),
                ),
              )
            else if (canSelect && selected)
              const Align(
                alignment: Alignment.centerRight,
                child: Chip(label: Text('Choix sélectionné')),
              )
            else if (!proposalsAvailable)
              const Align(
                alignment: Alignment.centerRight,
                child: StatusBadge('Migrations requises', color: muted),
              )
            else if (status == 'INDISPONIBLE')
              const Align(
                alignment: Alignment.centerRight,
                child: StatusBadge('Indisponible', color: muted),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: submittingSelection ? null : () => _propose(element),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Valider mon choix'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _propose(Map<String, dynamic> element) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Valider le choix de ${element['code_m']}'),
        content: Text(
          'Confirmez que vous acceptez d’enseigner cet EC. Votre choix sera transmis à l’agent de la cellule pour validation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer mon choix'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.teacherProposeAssignment(
        widget.classId,
        courseId: (element['id'] as num).toInt(),
      );
      if (!mounted) return;
      toast(
        context,
        'Choix transmis à l’agent de la cellule pour validation.',
      );
      setState(() => courseOptions = _loadCourseOptions());
    } catch (error) {
      if (mounted) toast(context, '$error');
    }
  }

  Widget _studentPicker(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> allStudents,
  ) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: allStudents.isEmpty ? null : _downloadRoomRoster,
            icon: const Icon(Icons.download_outlined),
            label: Text('Télécharger l’effectif Excel (${allStudents.length})'),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.zero,
        child: TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            labelText: 'Rechercher un étudiant',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      Expanded(
        child: students.isEmpty
            ? EmptyState(
                allStudents.isEmpty
                    ? 'Aucun étudiant inscrit'
                    : 'Aucun étudiant trouvé',
                allStudents.isEmpty
                    ? 'La liste sera disponible après validation des inscriptions.'
                    : 'Vérifiez le nom ou le matricule recherché.',
              )
            : ListView.separated(
                itemCount: students.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final student = students[index];
                  final name = '${student['nom'] ?? ''}'.trim();
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    title: Text(
                      '${student['nom'] ?? ''} ${student['prenom'] ?? ''}'
                          .trim(),
                    ),
                    subtitle: Text(
                      '${student['matricule'] ?? ''}${student['statut_redoublant'] == true ? ' · Redoublant' : ''}',
                    ),
                  );
                },
              ),
      ),
    ],
  );

  Future<void> _downloadRoomRoster() async {
    try {
      final bytes = await widget.api.teacherExportRoomRoster(widget.classId);
      final code = '${widget.room['code_classe'] ?? 'salle'}';
      final year = '${widget.room['annee_academique'] ?? ''}'
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
      await downloadFile('effectif-$code-$year.xlsx', bytes);
      if (mounted) toast(context, 'Effectif téléchargé.');
    } catch (error) {
      if (mounted) toast(context, 'Téléchargement impossible : $error');
    }
  }

}

class _RoomMetric extends StatelessWidget {
  const _RoomMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Panel(
    padding: 12,
    child: Row(
      children: [
        Icon(icon, color: palette(context, emerald)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

class TeacherAssignmentsPage extends StatefulWidget {
  const TeacherAssignmentsPage({
    super.key,
    required this.api,
    this.page = 'gradebook',
  });

  final StudentApiClient api;
  final String page;

  @override
  State<TeacherAssignmentsPage> createState() => _TeacherAssignmentsPageState();
}

class _TeacherAssignmentsPageState extends State<TeacherAssignmentsPage> {
  late Future<List<Map<String, dynamic>>> assignments;
  late Future<List<Map<String, dynamic>>> requests;
  late Future<List<Map<String, dynamic>>> assignmentProposals;

  @override
  void initState() {
    super.initState();
    assignments = widget.api.teacherAssignments();
    requests = widget.api.teacherRequests();
    assignmentProposals = widget.api.teacherAssignmentProposals();
  }

  void _reload() => setState(() {
    assignments = widget.api.teacherAssignments();
    requests = widget.api.teacherRequests();
    assignmentProposals = widget.api.teacherAssignmentProposals();
  });

  @override
  Widget build(BuildContext context) {
    final classesPage = widget.page == 'classes';
    final requestsPage = widget.page == 'requests';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          classesPage ? 'Mes niveaux' : 'Notes & validations',
          classesPage
              ? 'Consultez les effectifs et les matières qui vous sont affectées dans les différents départements où vous enseignez.'
              : 'Saisissez les notes, suivez leur transmission et traitez les retours de la cellule informatique.',
          action: IconButton(
            onPressed: _reload,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (classesPage) ...[
          const Notice(
            'Cochez les UE ou EC que vous acceptez d’enseigner, puis transmettez vos choix à l’agent de la cellule pour validation. Vous pourrez préparer les brouillons avant son approbation et télécharger la liste des étudiants inscrits.',
          ),
          TeacherRoomsSection(
            api: widget.api,
            onOpenGradebook: _showGradebook,
          ),
        ] else if (requestsPage) ...[
          const Notice(
            'Suivez vos choix d’UE/EC transmis à la cellule et les requêtes étudiantes affectées à votre compte.',
          ),
          const SizedBox(height: 20),
          const SectionTitle(
            'Mes choix d’enseignement',
            subtitle: 'Validation de vos UE et EC par l’agent de la cellule.',
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: assignmentProposals,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Panel(child: Text(_message(snapshot.error!)));
              }
              if (!snapshot.hasData) {
                return const Panel(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const Panel(
                  child: EmptyState(
                    'Aucun choix transmis',
                    'Les UE et EC que vous acceptez d’enseigner apparaîtront ici après transmission à la cellule.',
                  ),
                );
              }
              return Column(
                children: snapshot.data!.map(_assignmentProposalCard).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            'Requêtes étudiantes',
            subtitle: 'Répondez aux demandes qui vous ont été affectées.',
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: requests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Panel(child: Text(_message(snapshot.error!)));
              }
              if (!snapshot.hasData) {
                return const Panel(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const Panel(
                  child: EmptyState(
                    'Aucune requête étudiante en attente',
                    'Les requêtes transmises par la cellule apparaîtront ici.',
                  ),
                );
              }
              return Column(children: snapshot.data!.map(_requestCard).toList());
            },
          ),
        ] else ...[
          const Notice(
            'Enregistrez les notes en brouillon, transmettez chaque évaluation à la cellule pour contrôle, puis vérifiez les notes numérisées à son retour. Les résultats deviennent officiels après validation.',
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
        ],
      ],
    );
  }

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
                  label: const Text('Saisir & suivre les notes'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _assignmentProposalCard(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(
          '${item['code_ue'] ?? ''} · ${item['code_m'] ?? ''} · ${item['intitule_matiere'] ?? ''}',
        ),
        subtitle: Text(
          '${item['code_classe'] ?? ''} · ${item['annee_academique'] ?? ''}'
          '${(item['motif_decision']?.toString().trim().isNotEmpty ?? false) ? '\nRéponse : ${item['motif_decision']}' : ''}',
        ),
        isThreeLine: true,
        trailing: StatusBadge(
          switch (item['statut']) {
            'APPROUVEE' => 'Approuvée',
            'REJETEE' => 'Refusée',
            _ => 'En attente',
          },
          color: item['statut'] == 'APPROUVEE' ? emerald : muted,
        ),
      ),
    ),
  );

  Future<void> _scheduleRetake(Map<String, dynamic> assignment) async {
    final room = TextEditingController();
    var date = DateTime.now();
    var start = const TimeOfDay(hour: 8, minute: 0);
    var end = const TimeOfDay(hour: 10, minute: 0);
    var validationMessage = '';
    final schedule = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Programmer le rattrapage'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      helpText: 'Date du rattrapage',
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
                final endMinutes = end.hour * 60 + end.minute;
                final startMinutes = start.hour * 60 + start.minute;
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
                  'start': _teacherTimeForApi(start),
                  'end': _teacherTimeForApi(end),
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
    if (!mounted || schedule == null) return;
    final id = assignment['affectation_id'];
    if (id is! num) return;
    final code = '${assignment['code_m'] ?? assignment['code_ue'] ?? 'Cours'}';
    try {
      await widget.api.teacherCreateRetakeSession(
        id.toInt(),
        label: 'Rattrapage $code',
        date: schedule['date']!,
        start: schedule['start']!,
        end: schedule['end']!,
        room: schedule['room']!,
      );
      if (mounted) toast(context, 'Rattrapage programmé et étudiants notifiés.');
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  String _teacherTimeForApi(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

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
          final score = double.tryParse(
            _controller(evaluationId, student).text.replaceAll(',', '.'),
          );
          return absent || score != null;
        });
    final hasInvalidGrade = students.any((student) {
      if (_absent(evaluationId, student)) return false;
      final raw = _controller(evaluationId, student).text.trim();
      if (raw.isEmpty) return false;
      final score = double.tryParse(raw.replaceAll(',', '.'));
      return score == null;
    });
    final hasUnsavedGrades = students.any((student) {
      final currentValue = _controller(evaluationId, student).text.trim();
      final savedValue = '${student['valeur_note'] ?? ''}'.trim();
      final currentAbsent = _absent(evaluationId, student);
      final savedAbsent = student['situation'] == 'ABSENTE';
      return currentValue != savedValue || currentAbsent != savedAbsent;
    });
    return ExpansionTile(
      title: Text('Épreuve de rattrapage · ${students.length} candidat(s)'),
      subtitle: Text(
        'Évaluation $evaluationId · ${transmission?['statut'] ?? 'Brouillon'}',
      ),
      children: [
        ...students.map((student) {
          return ListTile(
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
                      inputFormatters: [_gradeScoreFormatter()],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Note /20',
                        helperText: 'Hors barème : 0/20 ou 20/20. Vide : EL.',
                      ),
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
                            if (value == true) {
                              _controller(evaluationId, student).clear();
                            }
                          }),
                  ),
                  const Text('Absent'),
                ],
              ),
            ),
          );
        }),
        if (!locked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: hasInvalidGrade
                      ? null
                      : () => _saveGrades(evaluationId, students),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer les notes'),
                ),
                FilledButton.icon(
                  onPressed: ready && !hasUnsavedGrades
                      ? () => _transmit(evaluationId)
                      : null,
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
      var absent = _absent(evaluationId, student);
      final raw = _controller(evaluationId, student).text.trim();
      if (raw.isEmpty) absent = true;
      final value = double.tryParse(
        raw.replaceAll(',', '.'),
      );
      if (!absent && value == null) {
        toast(context, 'Saisissez une note numérique ou marquez l’étudiant EL.');
        return;
      }
      final normalizedValue = value?.clamp(0.0, 20.0).toDouble();
      grades.add({
        'matricule': student['matricule'],
        'situation': absent ? 'ABSENTE' : 'NUMERIQUE',
        'valeur_note': absent ? null : normalizedValue,
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
  @override
  void initState() {
    super.initState();
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
                  Chip(
                    avatar: const Icon(Icons.groups_outlined, size: 18),
                    label: Text('${students.length} étudiant(s) inscrit(s)'),
                  ),
                  if (widget.request == null && allEvaluations.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: book['profil_evaluation'] == null
                          ? null
                          : () => _scheduleContinuousAssessments(allEvaluations),
                      icon: const Icon(Icons.event_note_outlined),
                      label: const Text('Programmer CC / TP'),
                    ),
                  OutlinedButton.icon(
                    onPressed: students.isEmpty
                        ? null
                        : () => _exportCsv(students, evaluations),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Exporter CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: students.isEmpty ? null : _exportExcel,
                    icon: const Icon(Icons.grid_on_outlined),
                    label: const Text('Télécharger le modèle Excel'),
                  ),
                  if (widget.request == null)
                    OutlinedButton.icon(
                      onPressed: students.isEmpty
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
                    label: const Text('Exporter le relevé des notes'),
                  ),
                  ...evaluations.map(
                    (evaluation) => _transmissionAction(
                      evaluation,
                      canTransmitOfficial: book['affectation_active'] == true,
                    ),
                  ),
                ],
              ),
            ),
            if (book['profil_evaluation'] == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: MaterialBanner(
                  content: Text(
                    'Aucun barème officiel n’est défini pour cette UE. Vous pouvez préparer un brouillon provisoire; la transmission à la cellule restera bloquée jusqu’à validation du barème.',
                  ),
                  actions: [SizedBox.shrink()],
                ),
              ),
            if (book['affectation_active'] != true)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Notice(
                  'Affectation en attente d’approbation par la cellule. Vous pouvez enregistrer des brouillons ; leur transmission officielle sera activée après approbation.',
                  warning: true,
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
                  ? widget.request != null
                        ? const Center(
                            child: Text('L’évaluation liée à cette requête n’est plus présente dans le plan actif. Vérifiez le plan de notes avant de poursuivre.'),
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('Aucune composante CC, TP, TPE ou SN n’est définie pour cette matière. La cellule doit valider un barème avant la saisie des notes.'),
                            ),
                          )
                  : _GradebookGrid(
                      key: ValueKey('gradebook-grid-$gradebookRevision'),
                      api: widget.api,
                      assignmentId: widget.assignmentId,
                      students: students,
                      evaluations: evaluations,
                      isCorrection: widget.request != null,
                    ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _scheduleContinuousAssessments(
    List<Map<String, dynamic>> evaluations,
  ) async {
    final scheduleable = evaluations
        .where((evaluation) => evaluation['type_eval'] != 'SN')
        .toList();
    if (scheduleable.isEmpty) {
      toast(context, 'Aucun CC ou TP à programmer dans ce plan.');
      return;
    }
    final dates = <int, DateTime>{};
    for (final evaluation in scheduleable) {
      final id = (evaluation['evaluation_id'] as num?)?.toInt();
      if (id == null) continue;
      dates[id] = DateTime.tryParse('${evaluation['date_evaluation']}') ?? DateTime.now();
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Programmer les évaluations continues'),
          content: SizedBox(
            width: 480,
            height: (MediaQuery.sizeOf(context).height * 0.48).clamp(220.0, 400.0),
            child: ListView(
              children: [
                const Notice(
                  'Choisissez les dates du CC et du TP. La date, l’heure et la salle de la session normale seront fixées par l’Agent.',
                ),
                for (final evaluation in scheduleable)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${evaluation['type_eval']} · ${evaluation['poids_evaluation']} %'),
                    subtitle: Text('${evaluation['date_evaluation']}'),
                    trailing: IconButton(
                      tooltip: 'Choisir la date',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () async {
                        final id = (evaluation['evaluation_id'] as num?)?.toInt();
                        if (id == null) return;
                        final current = dates[id] ?? DateTime.now();
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: current.isBefore(DateTime.now()) ? DateTime.now() : current,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (selected != null) setDialog(() => dates[id] = selected);
                      },
                    ),
                    leading: Text(
                      '${dates[(evaluation['evaluation_id'] as num?)?.toInt()]?.toIso8601String().substring(0, 10) ?? evaluation['date_evaluation']}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer le calendrier'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final rows = evaluations.map((evaluation) {
      final id = (evaluation['evaluation_id'] as num?)?.toInt();
      final date = evaluation['type_eval'] == 'SN'
          ? '${evaluation['date_evaluation']}'.substring(0, 10)
          : dates[id]?.toIso8601String().substring(0, 10) ?? '${evaluation['date_evaluation']}'.substring(0, 10);
      return {
        'evaluation_id': id,
        'type_eval': evaluation['type_eval'],
        'date_evaluation': date,
        'poids': evaluation['poids_evaluation'],
      };
    }).toList();
    try {
      await widget.api.teacherSaveEvaluationPlan(
        widget.assignmentId,
        evaluations: rows,
        reason: 'Programmation des CC/TP par l’enseignant',
      );
      if (!mounted) return;
      toast(context, 'Calendrier CC/TP enregistré. La session normale sera planifiée par l’Agent.');
      reload();
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

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

  List<Map<String, dynamic>> _draftEvaluations(
    List<Map<String, dynamic>> students,
  ) {
    final proposed = widget.assignment['profil_propose']?.toString() ??
        widget.assignment['profil_evaluation']?.toString();
    final weights = switch (proposed) {
      'CC_SN' => {'CC': 30.0, 'SN': 70.0},
      'CC_TP_SN' => {'CC': 20.0, 'TP': 30.0, 'SN': 50.0},
      'CC_TPE_SN' => {'CC': 20.0, 'TPE': 20.0, 'SN': 60.0},
      _ => const <String, double>{},
    };
    if (weights.isEmpty) return const [];
    final noteRows = students
        .expand((student) => (student['notes'] as List? ?? const []).whereType<Map>())
        .toList();
    return weights.entries.map((entry) {
      final existing = noteRows
          .where((note) => note['type_eval'] == entry.key && note['evaluation_id'] != null)
          .map((note) => note['evaluation_id'])
          .firstOrNull;
      return {
        'evaluation_id': existing ?? 'PROPOSED_${entry.key}',
        'type_eval': entry.key,
        'poids_evaluation': entry.value,
        'date_evaluation': '',
      };
    }).toList();
  }

  Widget _transmissionAction(
    Map<String, dynamic> evaluation, {
    required bool canTransmitOfficial,
  }) {
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
        onPressed: canTransmitOfficial && evaluation['correction_prete'] == true
            ? () => _transmitEvaluation(id, evaluation['type_eval'].toString())
            : null,
        icon: const Icon(Icons.send_outlined),
        label: Text(
          !canTransmitOfficial
              ? 'Approbation de l’affectation requise'
              : evaluation['correction_prete'] == true
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
      onPressed: canTransmitOfficial && canTransmit(status)
          ? () => _transmitEvaluation(id, evaluation['type_eval'].toString())
          : null,
      icon: const Icon(Icons.send_outlined),
      label: Text(
        canTransmitOfficial
            ? 'Transmettre ${evaluation['type_eval']}'
            : 'Après approbation · ${evaluation['type_eval']}',
      ),
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
      final clampedScores = (data['notes_bornees'] as num? ?? 0).toInt();
      final elMarkers = (data['mentions_el'] as num? ?? 0).toInt();
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
      if (currentProfileTypes.isEmpty && weights != null) {
        final profile = _profileCodeFromWeights(weights);
        if (profile == null) {
          toast(context, 'La grille détectée n’est pas une grille officielle connue.');
          return;
        }
        await widget.api.teacherProposeEvaluationProfile(widget.assignmentId, profile);
        if (!mounted) return;
        toast(context, 'Barème proposé à la cellule; import du classeur en cours.');
      }
      if (!currentProfileTypes.isEmpty &&
          (currentProfileTypes.length != importedProfileTypes.length ||
              !currentProfileTypes.containsAll(importedProfileTypes))) {
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
                '${data['importables']} étudiant(s) importable(s) sur ${data['total']}.\nColonnes reconnues : ${importedTypes.join(' · ')}.\nGrille détectée : ${weights.entries.map((e) => '${e.key} ${e.value}%').join(' · ')}.\nLes notes supérieures à 20 sont ramenées à 20/20 et les notes négatives à 00/20. Les cellules vides sont enregistrées comme EL.\n${clampedScores} note(s) ramenée(s) dans l’intervalle et ${elMarkers} mention(s) EL détectée(s). Les notes seront enregistrées en brouillon.${errors.isEmpty ? '' : '\n\n$errors'}',
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
      if (activeEvaluations.isEmpty) {
        final proposal = _profileCodeFromWeights(weights);
        final draft = _draftEvaluations([
          ...((refreshed['etudiants'] as List? ?? [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))),
        ]);
        if (draft.isEmpty || proposal == null) {
          toast(context, 'Le carnet provisoire ne peut pas être initialisé avec cette grille.');
          return;
        }
        final draftsByType = {for (final row in draft) row['type_eval']: row};
        final notesByStudent = <String, List<Map<String, dynamic>>>{};
        for (final column in columns) {
          final type = '${column['type_eval']}';
          final evaluation = draftsByType[type];
          if (evaluation == null) continue;
          for (final studentRow in imported) {
            final matricule = '${studentRow['matricule']}'.trim().toUpperCase();
            final mark = (studentRow['notes'] as List? ?? [])
                .whereType<Map>()
                .where((row) => row['index'] == column['index'])
                .firstOrNull;
            if (mark != null) {
              notesByStudent.putIfAbsent(matricule, () => []).add({
                'evaluation_id': evaluation['evaluation_id'],
                'situation': mark['situation'],
                'valeur_note': mark['valeur_note'],
              });
            }
          }
        }
        for (final entry in notesByStudent.entries) {
          await widget.api.teacherSaveStudentGrades(
            widget.assignmentId,
            matricule: entry.key,
            grades: entry.value,
          );
        }
        if (mounted) {
          toast(context, '${imported.length} étudiant(s) importé(s) en brouillon provisoire.');
          reload();
        }
        return;
      }
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

  Future<void> _exportExcel() async {
    try {
      final bytes = await widget.api.teacherExportGradebook(
        widget.assignmentId,
      );
      final classCode =
          '${widget.assignment['code_classe'] ?? widget.assignment['classe'] ?? 'classe'}';
      final filename =
          'notes-$classCode-${widget.assignment['code_ue']}-${widget.assignment['code_m']}.xlsx';
      await downloadFile(filename, bytes);
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

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
      if (mounted) {
        if (error is ApiFailure && error.statusCode == 409) reload();
        toast(
          context,
          error is ApiFailure ? error.message : error.toString(),
        );
      }
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
    ];
    final rows = <List<String>>[headers];
    for (final student in students) {
      rows.add([
        '${student['matricule'] ?? ''}',
        '${student['nom'] ?? ''}',
        ...evaluations.map((e) => markFor(student, e)),
      ]);
    }

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text(
            'Relevé des notes saisies',
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
          pw.Text('Document de travail enseignant.', style: const pw.TextStyle(fontSize: 8)),
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

}

class TeacherAccountPage extends StatefulWidget {
  const TeacherAccountPage({
    super.key,
    required this.api,
    required this.page,
  });

  final StudentApiClient api;
  final String page;

  @override
  State<TeacherAccountPage> createState() => _TeacherAccountPageState();
}

class _TeacherAccountPageState extends State<TeacherAccountPage> {
  late Future<Map<String, dynamic>> profile;
  late Future<List<Map<String, dynamic>>> notifications;
  late final TextEditingController firstName = TextEditingController(
    text: '${widget.api.user?['prenom'] ?? ''}',
  );
  late final TextEditingController lastName = TextEditingController(
    text: '${widget.api.user?['nom'] ?? ''}',
  );
  late final TextEditingController email = TextEditingController(
    text: '${widget.api.user?['courriel'] ?? ''}',
  );
  final Set<int> markingRead = {};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    profile = widget.api.getProfile();
    notifications = widget.api.teacherNotifications();
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    profile = widget.api.getProfile();
    notifications = widget.api.teacherNotifications();
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeading(
        widget.page == 'profile' ? 'Mon compte' : 'Mes notifications',
        widget.page == 'profile'
            ? 'Modifiez vos coordonnées et sécurisez votre accès.'
            : 'Dates d’examen, décisions et informations concernant vos UE.',
        action: IconButton(
          onPressed: _reload,
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
        ),
      ),
      if (widget.page == 'profile') _profileCard() else _notificationsCard(),
    ],
  );

  Widget _profileCard() => FutureBuilder<Map<String, dynamic>>(
    future: profile,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Panel(child: Text('${snapshot.error}'));
      if (!snapshot.hasData) {
        return const Panel(child: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data!;
      if (firstName.text != '${user['prenom'] ?? ''}') {
        firstName.text = '${user['prenom'] ?? ''}';
      }
      if (lastName.text != '${user['nom'] ?? ''}') {
        lastName.text = '${user['nom'] ?? ''}';
      }
      if (email.text != '${user['courriel'] ?? ''}') {
        email.text = '${user['courriel'] ?? ''}';
      }
      final teacherProfile = user['profil'] is Map
          ? Map<String, dynamic>.from(user['profil'])
          : <String, dynamic>{};

      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Informations personnelles'),
            TextField(
              controller: firstName,
              decoration: const InputDecoration(labelText: 'Prénom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastName,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Courriel'),
            ),
            const SizedBox(height: 12),
            Text(
              'Identifiant : ${user['login'] ?? '—'} · Enseignant : ${teacherProfile['eid'] ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: saving ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
                OutlinedButton.icon(
                  onPressed: saving ? null : _changePassword,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Changer le mot de passe'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _notificationsCard() => FutureBuilder<List<Map<String, dynamic>>>(
    future: notifications,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Panel(child: Text('${snapshot.error}'));
      if (!snapshot.hasData) {
        return const Panel(child: Center(child: CircularProgressIndicator()));
      }
      final items = snapshot.data!;
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Notifications',
              subtitle: '${items.where((item) => item['lue'] != true).length} non lue(s)',
            ),
            if (items.isEmpty)
              const EmptyState(
                'Aucune notification',
                'Les décisions sur vos demandes et les sessions programmées apparaîtront ici.',
              ),
            ...items.map(_notificationTile),
          ],
        ),
      );
    },
  );

  Widget _notificationTile(Map<String, dynamic> item) {
    final content = item['contenu'] is Map
        ? Map<String, dynamic>.from(item['contenu'])
        : <String, dynamic>{};
    final id = (item['id'] as num?)?.toInt();
    final read = item['lue'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        read ? Icons.notifications_none : Icons.notifications_active_outlined,
      ),
      title: Text(content['titre']?.toString() ?? 'Information académique'),
      subtitle: Text(
        '${content['message'] ?? ''}\n${item['date'] ?? ''}',
      ),
      isThreeLine: true,
      trailing: read || id == null
          ? null
          : IconButton(
              tooltip: 'Marquer comme lue',
              onPressed: markingRead.contains(id) ? null : () => _markRead(id),
              icon: const Icon(Icons.done),
            ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => saving = true);
    try {
      final updated = await widget.api.updateProfile({
        'prenom': firstName.text.trim(),
        'nom': lastName.text.trim(),
        'courriel': email.text.trim().isEmpty ? null : email.text.trim(),
      });
      widget.api.user = updated;
      if (mounted) toast(context, 'Informations du compte enregistrées.');
      if (mounted) setState(() => profile = Future.value(updated));
    } catch (error) {
      if (mounted) toast(context, '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                  validator: (value) => (value ?? '').isEmpty ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.length < 12 || !RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
                      return '12 caractères minimum, avec lettres et chiffres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                  validator: (value) => value != password.text ? 'Les mots de passe diffèrent' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, formKey.currentState!.validate()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      current.dispose();
      password.dispose();
      confirmation.dispose();
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.changePassword(
        currentPassword: current.text,
        password: password.text,
        passwordConfirmation: confirmation.text,
      );
      if (mounted) toast(context, 'Mot de passe modifié.');
    } catch (error) {
      if (mounted) toast(context, '$error');
    } finally {
      current.dispose();
      password.dispose();
      confirmation.dispose();
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _markRead(int id) async {
    setState(() => markingRead.add(id));
    try {
      await widget.api.teacherMarkNotificationRead(id);
      final items = await notifications;
      if (!mounted) return;
      setState(() {
        notifications = Future.value(items.map((item) => item['id'] == id
            ? {...item, 'lue': true}
            : item).toList());
      });
    } catch (error) {
      if (mounted) toast(context, '$error');
    } finally {
      if (mounted) setState(() => markingRead.remove(id));
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
    this.allowDrafts = true,
  });

  final StudentApiClient api;
  final int assignmentId;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> evaluations;
  final bool isCorrection;
  final bool allowDrafts;

  @override
  State<_GradebookGrid> createState() => _GradebookGridState();
}

class _GradebookGridState extends State<_GradebookGrid> {
  late final Map<String, Map<String, dynamic>> drafts;
  bool saving = false;
  int selectedStudentIndex = 0;

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
    return !widget.allowDrafts ||
        ['TRANSMISE', 'A_VERIFIER', 'VERIFIEE'].contains(status);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          widget.isCorrection
              ? 'Correction individuelle · enregistrez chaque composante séparément'
              : 'Saisie individuelle · enregistrez chaque note CC, TP, TPE ou SN séparément',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      if (widget.students.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: selectedStudentIndex > 0
                    ? () => setState(() => selectedStudentIndex--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Précédent'),
              ),
              Expanded(
                child: Center(
                  child: DropdownButton<int>(
                    value: selectedStudentIndex,
                    items: [
                      for (var i = 0; i < widget.students.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i + 1}/${widget.students.length} · ${widget.students[i]['matricule']} · ${widget.students[i]['nom']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => selectedStudentIndex = value ?? 0),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: selectedStudentIndex + 1 < widget.students.length
                    ? () => setState(() => selectedStudentIndex++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Suivant'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _studentEvaluationForm(widget.students[selectedStudentIndex]),
        ),
      ],
    ],
  );

  Widget _studentEvaluationForm(Map<String, dynamic> student) {
    final matricule = '${student['matricule']}';
    final name = '${student['prenom'] ?? ''} ${student['nom'] ?? ''}'.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(name.isEmpty ? matricule : name),
            subtitle: Text('Matricule $matricule · ${student['niveau'] ?? ''}'),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.evaluations.map((evaluation) {
          final key = _key(matricule, evaluation['evaluation_id']);
          final draft = drafts[key]!;
          final disabled = saving || _locked(evaluation, draft);
          final stageNote = (student['notes'] as List? ?? [])
              .whereType<Map>()
              .where((note) => '${note['evaluation_id']}' == '${evaluation['evaluation_id']}')
              .firstOrNull;
          final parsedScore = double.tryParse(
            '${draft['valeur_note']}'.replaceAll(',', '.'),
          );
          final hasUnsaved = draft['valeur_note']?.toString() !=
                  draft['initial_value']?.toString() ||
              draft['situation'] != draft['initial_situation'];
          final invalid = draft['situation'] == 'INVALIDE' ||
              (draft['situation'] == 'NUMERIQUE' && parsedScore == null);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${evaluation['type_eval']} · ${evaluation['poids_evaluation']} %', style: Theme.of(context).textTheme.titleMedium),
                  if ('${evaluation['date_evaluation'] ?? ''}'.isNotEmpty)
                    Text('Date : ${evaluation['date_evaluation']}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('grade-$key-${draft['revision']}'),
                          initialValue: draft['valeur_note']?.toString() ?? '',
                          enabled: !disabled,
                          inputFormatters: [_gradeScoreFormatter()],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Note sur 20',
                            hintText: 'Ex. 14,5',
                            helperText: 'Hors barème : 0/20 ou 20/20. Vide : EL.',
                          ),
                          onChanged: (raw) => setState(() {
                            final value = raw.trim();
                            final parsed = value.isEmpty ? null : double.tryParse(value.replaceAll(',', '.'));
                            draft['valeur_note'] = raw;
                            draft['situation'] = parsed == null
                                ? (value.isEmpty ? 'MANQUANTE' : 'INVALIDE')
                                : 'NUMERIQUE';
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: ['NUMERIQUE', 'ABSENTE', 'MANQUANTE'].contains(draft['situation']) ? draft['situation'] as String : 'MANQUANTE',
                        onChanged: disabled ? null : (value) => setState(() {
                          draft['situation'] = value ?? 'MANQUANTE';
                          if (value != 'NUMERIQUE') draft['valeur_note'] = '';
                          draft['revision'] = (draft['revision'] as int) + 1;
                        }),
                        items: const [
                          DropdownMenuItem(value: 'NUMERIQUE', child: Text('Noté')),
                          DropdownMenuItem(
                            value: 'ABSENTE',
                            child: Text('EL · absence ou note vide'),
                          ),
                          DropdownMenuItem(value: 'MANQUANTE', child: Text('À saisir')),
                        ],
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: saving || disabled || !hasUnsaved || invalid
                          ? null
                          : () => _saveOne(student, evaluation, draft),
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        saving
                            ? 'Enregistrement…'
                            : 'Enregistrer ${evaluation['type_eval']} pour cet étudiant',
                      ),
                    ),
                  ),
                  if (evaluation['transmission']?['statut'] == 'A_VERIFIER' && stageNote?['situation_numerisee'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Cellule : ${stageNote?['situation_numerisee'] == 'NUMERIQUE' ? '${stageNote?['valeur_numerisee']}/20' : stageNote?['situation_numerisee']}'),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _saveOne(
    Map student,
    Map<String, dynamic> evaluation,
    Map<String, dynamic> draft,
  ) async {
    final raw = '${draft['valeur_note']}'.trim();
    final parsed = raw.isEmpty
        ? null
        : double.tryParse(raw.replaceAll(',', '.'));
    if (draft['situation'] == 'NUMERIQUE' && parsed == null) {
      toast(context, 'Saisissez une note numérique ou choisissez EL.');
      return;
    }
    final bounded = parsed?.clamp(0.0, 20.0).toDouble();
    final situation = raw.isEmpty || draft['situation'] == 'ABSENTE'
        ? 'ABSENTE'
        : 'NUMERIQUE';
    final evaluationId = (evaluation['evaluation_id'] as num).toInt();
    setState(() => saving = true);
    try {
      await widget.api.teacherSaveGrades(
        widget.assignmentId,
        evaluationId,
        grades: [
          {
            'matricule': student['matricule'],
            'situation': situation,
            'valeur_note': situation == 'NUMERIQUE' ? bounded : null,
            if (draft['version_note'] is num &&
                (draft['version_note'] as num) > 0)
              'version_note': draft['version_note'],
          },
        ],
      );
      if (!mounted) return;
      setState(() {
        draft['valeur_note'] = bounded?.toString() ?? '';
        draft['situation'] = situation;
        draft['initial_value'] = draft['valeur_note'];
        draft['initial_situation'] = situation;
        draft['version_note'] = draft['version_note'] ?? 1;
        draft['revision'] = (draft['revision'] as int) + 1;
        saving = false;
      });
      toast(context, 'Note ${evaluation['type_eval']} enregistrée en brouillon.');
    } catch (error) {
      if (mounted) toast(context, error.toString());
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }
}
