import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'api_client.dart';
import 'file_download.dart';
import 'gnu_pv_template.dart';
import 'session_normale_pdf.dart';
import 'pdf_theme.dart';
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
            width: (MediaQuery.sizeOf(context).width * 0.78).clamp(
              340.0,
              1040.0,
            ),
            height: (MediaQuery.sizeOf(context).height * 0.78).clamp(
              400.0,
              720.0,
            ),
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
    final students = allStudents.where((student) {
      final search = query.trim().toLowerCase();
      return search.isEmpty ||
          '${student['nom']} ${student['prenom']} ${student['matricule']}'
              .toLowerCase()
              .contains(search);
    }).toList();

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
                        color: Theme.of(context).colorScheme.errorContainer
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
          for (final element in elements)
            _courseTile(unit, element, proposalsAvailable),
        ],
      ),
    );
  }

  bool _isSelectable(Map<String, dynamic> element) {
    final status = element['statut_affectation']?.toString();
    return element['peut_demander_separement'] != false &&
        (status == null || status == 'REJETEE');
  }

  Future<void> _submitSelectedCourses(List<Map<String, dynamic>> units) async {
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
          width: (MediaQuery.sizeOf(context).width * 0.72).clamp(
            340.0,
            840.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirmez les UE ou EC que vous acceptez d’enseigner. La sélection sera transmise à l’agent de la cellule pour validation.',
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * 0.48)
                      .clamp(240.0, 460.0),
                ),
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
      if (mounted)
        toast(context, '$submitted/${choices.length} choix transmis. $error');
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
    final selected =
        selectedId != null && selectedCourseIds.contains(selectedId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
                .withValues(alpha: 0.5)
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
                        Text(switch (status) {
                          'APPROUVEE' => 'Affectation approuvée',
                          'EN_ATTENTE' => 'Choix en attente de validation · carnet provisoire accessible',
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
                        }, style: Theme.of(context).textTheme.bodySmall),
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
                  onPressed: submittingSelection
                      ? null
                      : () => _propose(element),
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
      toast(context, 'Choix transmis à l’agent de la cellule pour validation.');
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
                compact: true,
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
      final year = '${widget.room['annee_academique'] ?? ''}'.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '-',
      );
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
  int refreshRevision = 0;
  bool refreshing = false;
  late Future<List<Map<String, dynamic>>> assignments;
  late Future<List<Map<String, dynamic>>> requests;
  late Future<List<Map<String, dynamic>>> assignmentProposals;
  final GlobalKey<_TeacherRoomsSectionState> roomsKey =
      GlobalKey<_TeacherRoomsSectionState>();

  @override
  void initState() {
    super.initState();
    assignments = widget.api.teacherAssignments();
    requests = widget.api.teacherRequests();
    assignmentProposals = widget.api.teacherAssignmentProposals();
  }

  Future<void> _reload() async {
    if (refreshing) return;
    final rooms = roomsKey.currentState;
    setState(() {
      refreshing = true;
      refreshRevision++;
      assignments = widget.api.teacherAssignments();
      requests = widget.api.teacherRequests();
      assignmentProposals = widget.api.teacherAssignmentProposals();
    });
    if (rooms != null) rooms._load(rooms.yearId);
    try {
      await Future.wait([assignments, requests, assignmentProposals]);
    } catch (_) {
      // Each FutureBuilder displays its own error and retry action.
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

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
        if (classesPage) ...[
          const Notice(
            'Cochez les UE ou EC que vous acceptez d’enseigner, puis transmettez vos choix à l’agent de la cellule pour validation. Vous pourrez préparer les brouillons avant son approbation et télécharger la liste des étudiants inscrits.',
          ),
          TeacherRoomsSection(
            key: roomsKey,
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
            key: ValueKey('proposals-$refreshRevision'),
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
            key: ValueKey('requests-$refreshRevision'),
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
              return Column(
                children: snapshot.data!.map(_requestCard).toList(),
              );
            },
          ),
        ] else ...[
          const Notice(
        'Le carnet est organisé par UE et par niveau. Enregistrez le brouillon, puis transmettez la grille à l’agent pour numérisation et traitement du PV. Après vérification et publication, les étudiants reçoivent leurs notes provisoires.',
          ),
          const SectionTitle(
            'Mes UE et niveaux actifs',
            subtitle: 'Un carnet commun rassemble les évaluations de tous les EC de chaque UE.',
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('assignments-$refreshRevision'),
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
                    'Aucune UE active pour cette année',
                    'Les choix transmis restent en attente ici tant que la cellule ne les a pas approuvés. Les carnets et leurs grilles apparaîtront après activation de l’affectation.',
                  ),
                );
              }
              return _assignmentGroups(items);
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('pending-proposals-$refreshRevision'),
            future: assignmentProposals,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.hasError) {
                return const SizedBox.shrink();
              }
              final pending = snapshot.data!
                  .where((item) => item['statut'] == 'EN_ATTENTE')
                  .toList();
              if (pending.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    'Choix transmis à la cellule · ${pending.length}',
                    subtitle: 'Ces affectations deviendront ouvrables dans les carnets après approbation.',
                  ),
                  ...pending.map(_assignmentProposalCard),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
  }

  Widget _assignmentGroups(List<Map<String, dynamic>> items) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final key = '${item['classe_id']}:${item['ue_id']}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return Column(
      children: groups.values.map((group) {
        final unit = group.first;
        final managerAssignments = group
            .where((item) => item['peut_gerer_notes'] == true)
            .toList();
        final canonicalAssignment = managerAssignments
                .where(
                  (item) =>
                      item['affectation_enseignant_id'] ==
                      item['responsable_notes_enseignant_id'],
                )
                .firstOrNull ??
            managerAssignments.firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  '${unit['code_ue'] ?? ''} · ${unit['intitule_ue'] ?? ''}',
                  subtitle:
                      '${unit['code_classe'] ?? ''} · ${unit['code_niv'] ?? unit['libelle_niv'] ?? ''} · ${unit['annee_academique'] ?? ''} · S${unit['numero_semestre'] ?? ''}',
                ),
                for (final item in group) ...[
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(
                      '${item['code_m'] ?? ''} · ${item['intitule_matiere'] ?? ''}',
                    ),
                    subtitle: Text(item['peut_gerer_notes'] == true
                        ? 'Évaluations de cet EC intégrées au carnet commun de l’UE'
                        : 'Co-enseignant · responsable : ${item['responsable_notes_prenom'] ?? ''} ${item['responsable_notes_nom'] ?? 'à désigner'}'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 52, bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: item['peut_gerer_notes'] == true
                              ? () => _scheduleRetake(item)
                              : null,
                          icon: const Icon(Icons.event_repeat),
                          label: const Text('Programmer un rattrapage'),
                        ),
                        OutlinedButton.icon(
                          onPressed: item['peut_gerer_notes'] == true
                              ? () => _manageRetakes(item)
                              : null,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Candidats et notes'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (canonicalAssignment != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 52, top: 8),
                    child: FilledButton.icon(
                      onPressed: () => _showGradebook(
                        canonicalAssignment,
                        assignments: [canonicalAssignment],
                      ),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Ouvrir le carnet commun de l’UE'),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

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
        trailing: StatusBadge(switch (item['statut']) {
          'APPROUVEE' => 'Approuvée',
          'REJETEE' => 'Refusée',
          _ => 'En attente',
        }, color: item['statut'] == 'APPROUVEE' ? emerald : muted),
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
                final endMinutes = end.hour * 60 + end.minute;
                final startMinutes = start.hour * 60 + start.minute;
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
      if (mounted)
        toast(context, 'Rattrapage programmé et étudiants notifiés.');
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
    List<Map<String, dynamic>>? assignments,
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
          assignments: assignments ?? [assignment],
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
            ...evaluations.map(
              (evaluation) => _evaluationCard(evaluation, session),
            ),
          ],
        ),
      ),
    );
  }

  Widget _evaluationCard(Map evaluation, Map<String, dynamic> session) {
    final evaluationId = (evaluation['evaluation_id'] as num?)?.toInt();
    final students = (evaluation['etudiants'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final transmission = evaluation['transmission'] as Map?;
    final transmissionStatus = transmission?['statut']?.toString();
    final locked = [
      'TRANSMISE',
      'VERIFIEE',
      'VALIDEE_ENSEIGNANT',
      'PUBLIEE',
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
        if (transmission?['publie_le'] != null && students.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 8),
              child: OutlinedButton.icon(
                onPressed: () =>
                    _exportRetakeMinutes(evaluation, session, students),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimer le PV de rattrapage'),
              ),
            ),
          ),
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
                  label: const Text('Valider et transmettre à l’agent'),
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
                  onPressed: !hasUnsavedGrades && transmission?['id'] is num
                      ? () => _verifyRetakeTransmission(
                          (transmission!['id'] as num).toInt(),
                          'VERIFIER',
                        )
                      : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Confirmer la numérisation'),
                ),
                OutlinedButton.icon(
                  onPressed: !hasUnsavedGrades && transmission?['id'] is num
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
              'Circuit de contrôle : ${transmission?['statut']}. Vous pouvez corriger les notes après le retour de la cellule, puis demander une correction pour renvoyer la grille.',
            ),
          ),
      ],
    );
  }

  Future<void> _exportRetakeMinutes(
    Map evaluation,
    Map<String, dynamic> session,
    List<Map> students,
  ) async {
    final assignment = widget.assignment;
    Uint8List? logoBytes;
    try {
      logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer
          .asUint8List();
    } catch (_) {}
    final crest = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final document = pw.Document(theme: await gnuPdfTheme());
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 28),
        header: (_) => pw.Column(
          children: [
            pw.Row(
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
                        'Paix - Travail - Patrie',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '${assignment['universite'] ?? 'UNIVERSITÉ DE YAOUNDÉ I'}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (crest != null)
                  pw.SizedBox(
                    width: 48,
                    height: 48,
                    child: pw.Image(crest, fit: pw.BoxFit.contain),
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
                        'Peace - Work - Fatherland',
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
            pw.Text(
              '${assignment['faculte'] ?? 'FACULTÉ'} · ${assignment['departement'] ?? 'DÉPARTEMENT'}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text(
              'PROCÈS-VERBAL DE RATTRAPAGE · ${assignment['code_ue'] ?? ''} · ${assignment['code_m'] ?? ''}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${assignment['intitule_ue'] ?? ''} · ${assignment['intitule_matiere'] ?? ''}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              '${assignment['code_classe'] ?? ''} · ${assignment['annee_academique'] ?? ''} · ${session['libelle'] ?? 'Session de rattrapage'} · ${session['date_session'] ?? ''}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 7),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'GNU · PV réservé aux personnes habilitées',
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
            headers: const [
              'N°',
              'MATRICULE',
              'NOMS ET PRÉNOMS',
              'RATTRAPAGE /20',
              'OBSERVATION',
            ],
            data: [
              for (var index = 0; index < students.length; index++)
                [
                  '${index + 1}',
                  '${students[index]['matricule'] ?? ''}',
                  '${students[index]['nom'] ?? ''}',
                  students[index]['situation'] == 'NUMERIQUE' &&
                          students[index]['valeur_note'] != null
                      ? '${students[index]['valeur_note']}'
                      : 'EL',
                  '${students[index]['statut_candidature'] ?? ''}',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {2: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .45),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'La note de rattrapage remplace la note de SN dans le résultat de l’UE. Les notes de CC et de TP/TPE sont conservées.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Enseignant responsable',
              'Cellule informatique',
              'Chef du département',
            ],
            data: [
              [
                '${widget.api.user?['prenom'] ?? ''} ${widget.api.user?['nom'] ?? ''}\nSignature',
                'Visa et cachet',
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
    try {
      final filename =
          'PV-RATTRAPAGE-${assignment['code_ue']}-${assignment['code_classe']}-${session['date_session']}.pdf';
      await Printing.layoutPdf(
        onLayout: (_) async => document.save(),
        name: filename,
      );
    } catch (error) {
      if (mounted)
        toast(context, 'Impression du PV de rattrapage impossible : $error');
    }
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
      final value = double.tryParse(raw.replaceAll(',', '.'));
      if (!absent && value == null) {
        toast(
          context,
          'Saisissez une note numérique ou marquez l’étudiant EL.',
        );
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
        toast(context, 'Notes validées et transmises à l’agent pour publication.');
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
    required this.assignments,
    this.request,
  });
  final StudentApiClient api;
  final Map<String, dynamic> assignment;
  final int assignmentId;
  final List<Map<String, dynamic>> assignments;
  final Map<String, dynamic>? request;
  @override
  State<_GradebookDialog> createState() => _GradebookDialogState();
}

class _GradebookDialogState extends State<_GradebookDialog> {
  late Future<Map<String, dynamic>> data;
  int gradebookRevision = 0;
  final Set<int> evaluationsWithUnsavedDrafts = {};
  @override
  void initState() {
    super.initState();
    data = _loadGradebook();
  }

  Future<Map<String, dynamic>> _loadGradebook() async {
    final sources = await Future.wait(
      widget.assignments.map((assignment) async {
        final id = (assignment['affectation_id'] as num?)?.toInt();
        if (id == null) return null;
        final data = await widget.api.teacherGradebook(id);
        final plan = Map<String, dynamic>.from(data['plan'] as Map? ?? {});
        final components = (plan['composantes'] as List? ?? [])
            .whereType<Map>()
            .map(
              (component) => <String, dynamic>{
                ...Map<String, dynamic>.from(component),
                'affectation_id': id,
                'credit_ec': data['credit_ec'],
                'code_m': null,
                'intitule_matiere': null,
              },
            )
            .toList();
        return <String, dynamic>{
          'assignment': assignment,
          'data': data,
          'plan': plan,
          'components': components,
        };
      }),
    );
    final validSources = sources.whereType<Map<String, dynamic>>().toList();
    if (validSources.isEmpty) return {};
    final first = Map<String, dynamic>.from(validSources.first['data'] as Map);
    final componentsById = <String, Map<String, dynamic>>{};
    for (final component in validSources
        .expand((source) => source['components'] as List<Map<String, dynamic>>)) {
      final evaluationId = component['evaluation_id'];
      final key = evaluationId == null
          ? '${component['type_eval']}:${component['date_evaluation']}'
          : '$evaluationId';
      componentsById.putIfAbsent(key, () => component);
    }
    final components = componentsById.values.toList()
      ..sort((a, b) {
        final semester = '${a['date_evaluation']}'.compareTo(
          '${b['date_evaluation']}',
        );
        if (semester != 0) return semester;
        final ec = '${a['code_m']}'.compareTo('${b['code_m']}');
        if (ec != 0) return ec;
        return '${a['type_eval']}'.compareTo('${b['type_eval']}');
      });
    final studentRows = <String, Map<String, dynamic>>{};
    for (final source in validSources) {
      final data = source['data'] as Map;
      for (final rawStudent in (data['etudiants'] as List? ?? []).whereType<Map>()) {
        final student = Map<String, dynamic>.from(rawStudent);
        final key = '${student['matricule']}'.trim().toUpperCase();
        final existing = studentRows.putIfAbsent(key, () => student);
        if (!identical(existing, student)) {
          final notesByEvaluation = <String, Map<String, dynamic>>{};
          for (final rawNote in [
            ...(existing['notes'] as List? ?? []),
            ...(student['notes'] as List? ?? []),
          ].whereType<Map>()) {
            final note = Map<String, dynamic>.from(rawNote);
            final evaluationKey = '${note['evaluation_id']}';
            final previous = notesByEvaluation[evaluationKey];
            final version = (note['version_note'] as num?)?.toInt() ?? 0;
            final previousVersion =
                (previous?['version_note'] as num?)?.toInt() ?? -1;
            if (previous == null || version >= previousVersion) {
              notesByEvaluation[evaluationKey] = note;
            }
          }
          existing['notes'] = notesByEvaluation.values.toList();
          for (final field in [
            'resultat_ue_provisoire',
            'resultat_ec_provisoire',
            'hors_compte',
            'observation',
          ]) {
            if (student[field] != null) existing[field] = student[field];
          }
        }
      }
    }
    for (final student in studentRows.values) {
      final uniqueNotes = <String, Map<String, dynamic>>{};
      for (final rawNote in (student['notes'] as List? ?? []).whereType<Map>()) {
        final note = Map<String, dynamic>.from(rawNote);
        final evaluationId = note['evaluation_id'];
        final key = evaluationId == null
            ? '${note['type_eval'] ?? ''}:${note['code_m'] ?? ''}'
            : '$evaluationId';
        final previous = uniqueNotes[key];
        final version = (note['version_note'] as num?)?.toInt() ?? 0;
        final previousVersion =
            (previous?['version_note'] as num?)?.toInt() ?? -1;
        if (previous == null || version >= previousVersion) {
          uniqueNotes[key] = note;
        }
      }
      student['notes'] = uniqueNotes.values.toList();
    }
    final firstPlan = Map<String, dynamic>.from(validSources.first['plan'] as Map);
    first['plan'] = {...firstPlan, 'composantes': components};
    first['etudiants'] = studentRows.values.toList();
    first['code_m'] = null;
    first['code_matiere'] = null;
    first['intitule_matiere'] = 'Évaluations communes de l’UE';
    first['affectation_active'] = validSources.every(
      (source) => (source['data'] as Map)['affectation_active'] == true,
    );
    first['affectation_ids'] = validSources
        .map((source) => (source['assignment'] as Map)['affectation_id'])
        .toList();
    return first;
  }

  void reload() => setState(() {
    gradebookRevision++;
    data = _loadGradebook();
    evaluationsWithUnsavedDrafts.clear();
  });

  void _updateUnsavedEvaluations(Set<int> ids) {
    if (evaluationsWithUnsavedDrafts.length == ids.length &&
        evaluationsWithUnsavedDrafts.containsAll(ids)) {
      return;
    }
    setState(() {
      evaluationsWithUnsavedDrafts
        ..clear()
        ..addAll(ids);
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.request == null
            ? 'Carnet UE · ${widget.assignment['code_ue']}'
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
          final byEc = '${a['code_m'] ?? ''}'.compareTo(
            '${b['code_m'] ?? ''}',
          );
          if (byEc != 0) return byEc;
          final byType = (evaluationOrder[a['type_eval']] ?? 4).compareTo(
            evaluationOrder[b['type_eval']] ?? 4,
          );
          return byType != 0
              ? byType
              : '${a['date_evaluation']}'.compareTo('${b['date_evaluation']}');
        });
        final hasEvaluationGrid =
            allEvaluations.isNotEmpty ||
            book['profil_evaluation'] != null ||
            book['profil_propose'] != null;
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
                  if (widget.request == null)
                    ...evaluations.map<Widget>(
                      (evaluation) => OutlinedButton.icon(
                        onPressed: () => _openEvaluationEntry(
                          book,
                          students,
                          evaluation,
                        ),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: Text('Saisir ${evaluation['type_eval']}'),
                      ),
                    ),
                  if (widget.request == null && allEvaluations.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: book['profil_evaluation'] == null
                          ? null
                          : () =>
                                _scheduleContinuousAssessments(allEvaluations),
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
                  if (widget.assignments.length == 1)
                    OutlinedButton.icon(
                      onPressed: students.isEmpty || !hasEvaluationGrid
                          ? null
                          : () => _exportExcel(widget.assignments.single),
                      icon: const Icon(Icons.grid_on_outlined),
                      label: const Text('Modèle Excel de la grille'),
                    )
                  else
                    PopupMenuButton<int>(
                      enabled: students.isNotEmpty && hasEvaluationGrid,
                      tooltip: 'Télécharger un modèle Excel par EC',
                      onSelected: (id) => _exportExcel(_assignmentForId(id)),
                      itemBuilder: (context) => widget.assignments.map((item) {
                        final id = (item['affectation_id'] as num).toInt();
                        return PopupMenuItem<int>(
                          value: id,
                          child: Text('${item['code_m']} · ${item['intitule_matiere']}'),
                        );
                      }).toList(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grid_on_outlined),
                            SizedBox(width: 8),
                            Text('Modèle Excel par EC'),
                          ],
                        ),
                      ),
                    ),
                  if (widget.request == null && widget.assignments.length == 1)
                    OutlinedButton.icon(
                      onPressed: students.isEmpty || !hasEvaluationGrid
                          ? null
                          : () => _importWholeGradebook(
                              evaluations,
                              widget.assignments.single,
                            ),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Importer le modèle rempli'),
                    )
                  else if (widget.request == null)
                    PopupMenuButton<int>(
                      enabled: students.isNotEmpty && hasEvaluationGrid,
                      tooltip: 'Importer un modèle Excel par EC',
                      onSelected: (id) {
                        final assignment = _assignmentForId(id);
                        _importWholeGradebook(
                          evaluations
                              .where((evaluation) => evaluation['affectation_id'] == id)
                              .toList(),
                          assignment,
                        );
                      },
                      itemBuilder: (context) => widget.assignments.map((item) {
                        final id = (item['affectation_id'] as num).toInt();
                        return PopupMenuItem<int>(
                          value: id,
                          child: Text('${item['code_m']} · ${item['intitule_matiere']}'),
                        );
                      }).toList(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.upload_file_outlined),
                            SizedBox(width: 8),
                            Text('Importer par EC'),
                          ],
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: students.isEmpty
                        ? null
                        : () => _exportPdf(students, evaluations),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Exporter PDF'),
                  ),
                  for (final type in ['CC', 'TP', 'TPE', 'SN'])
                    OutlinedButton.icon(
                      onPressed:
                          students.isEmpty ||
                              !evaluations.any((e) => e['type_eval'] == type)
                          ? null
                          : () => _exportMinutes(
                              types: {type},
                              metadata: book,
                            ),
                      icon: const Icon(Icons.print_outlined),
                      label: Text('Imprimer PV $type'),
                    ),
                  OutlinedButton.icon(
                    onPressed:
                        students.isEmpty ||
                            !evaluations.any(
                              (e) => {
                                'CC',
                                'TP',
                                'TPE',
                                'SN',
                              }.contains(e['type_eval']),
                            )
                        ? null
                        : () => _exportMinutes(
                            types: {'CC', 'TP', 'TPE', 'SN'},
                            metadata: book,
                          ),
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimer le PV récapitulatif'),
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
            if (widget.request == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Notice(
                  'Enregistrer une note la garde en brouillon. L’impression du PV crée une copie locale. Pour envoyer les notes à l’agent, utilisez « Valider et transmettre » après avoir enregistré la grille. L’agent reçoit la notification et peut les publier aux étudiants.',
                ),
              ),
            if (book['profil_evaluation'] == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: MaterialBanner(
                  content: Text(
                    'Aucun barème officiel n’est défini pour cette UE. Vous pouvez préparer un brouillon provisoire. Après approbation du barème, l’enseignant pourra valider les notes et l’agent sera notifié pour leur publication.',
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
                            child: Text(
                              'L’évaluation liée à cette requête n’est plus présente dans le plan actif. Vérifiez le plan de notes avant de poursuivre.',
                            ),
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Aucune composante CC, TP, TPE ou SN n’est définie pour cette matière. La cellule doit valider un barème avant la saisie des notes.',
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
                      onUnsavedEvaluationsChanged: _updateUnsavedEvaluations,
                      onSaved: reload,
                    ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _openEvaluationEntry(
    Map<String, dynamic> book,
    List<Map<String, dynamic>> students,
    Map<String, dynamic> evaluation,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _EvaluationGradeEntryScreen(
          api: widget.api,
          assignmentId: (evaluation['affectation_id'] as num?)?.toInt() ??
              widget.assignmentId,
          book: book,
          evaluation: evaluation,
          students: students,
          onSaved: reload,
        ),
      ),
    );
  }

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
      dates[id] =
          DateTime.tryParse('${evaluation['date_evaluation']}') ??
          DateTime.now();
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Programmer les évaluations continues'),
          content: SizedBox(
            width: 480,
            height: (MediaQuery.sizeOf(context).height * 0.48).clamp(
              220.0,
              400.0,
            ),
            child: ListView(
              children: [
                const Notice(
                  'Choisissez les dates du CC et du TP. La date, l’heure et la salle de la session normale seront fixées par l’Agent.',
                ),
                for (final evaluation in scheduleable)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${evaluation['type_eval']} · ${evaluation['poids_evaluation']} %',
                    ),
                    subtitle: Text('${evaluation['date_evaluation']}'),
                    trailing: IconButton(
                      tooltip: 'Choisir la date',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () async {
                        final id = (evaluation['evaluation_id'] as num?)
                            ?.toInt();
                        if (id == null) return;
                        final current = dates[id] ?? DateTime.now();
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: current.isBefore(DateTime.now())
                              ? DateTime.now()
                              : current,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (selected != null)
                          setDialog(() => dates[id] = selected);
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
    try {
      final byAssignment = <int, List<Map<String, dynamic>>>{};
      for (final evaluation in evaluations) {
        final assignmentId =
            (evaluation['affectation_id'] as num?)?.toInt() ??
            widget.assignmentId;
        final id = (evaluation['evaluation_id'] as num?)?.toInt();
        if (id == null) continue;
        final date = evaluation['type_eval'] == 'SN'
            ? '${evaluation['date_evaluation']}'.substring(0, 10)
            : dates[id]?.toIso8601String().substring(0, 10) ??
                  '${evaluation['date_evaluation']}'.substring(0, 10);
        byAssignment.putIfAbsent(assignmentId, () => []).add({
          'evaluation_id': id,
          'type_eval': evaluation['type_eval'],
          'date_evaluation': date,
          'poids': evaluation['poids_evaluation'],
        });
      }
      for (final entry in byAssignment.entries) {
        await widget.api.teacherSaveEvaluationPlan(
          entry.key,
          evaluations: entry.value,
          reason: 'Programmation des CC/TP par l’enseignant',
        );
      }
      if (!mounted) return;
      toast(
        context,
        'Calendrier CC/TP enregistré. La session normale sera planifiée par l’Agent.',
      );
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

  Widget _transmissionAction(
    Map<String, dynamic> evaluation, {
    required bool canTransmitOfficial,
  }) {
    final transmission = evaluation['transmission'] as Map?;
    final status = transmission?['statut']?.toString();
    final id = (evaluation['evaluation_id'] as num?)?.toInt();
    if (id == null) return const SizedBox.shrink();
    final hasUnsavedDrafts = evaluationsWithUnsavedDrafts.contains(id);
    if (status == 'A_VERIFIER' && transmission?['id'] is num) {
      final transmissionId = (transmission!['id'] as num).toInt();
      return Wrap(
        spacing: 8,
        children: [
          if (transmission['proces_verbal_disponible'] == true)
            OutlinedButton.icon(
              onPressed: () =>
                  _downloadGradeMinutes(transmissionId, evaluation),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Télécharger le PV'),
            ),
          OutlinedButton.icon(
            onPressed: hasUnsavedDrafts
                ? null
                : () => _verifyTransmission(transmissionId),
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              hasUnsavedDrafts
                  ? 'Enregistrer avant vérification'
                  : 'Vérifier ${evaluation['type_eval']}',
            ),
          ),
          OutlinedButton.icon(
            onPressed: hasUnsavedDrafts
                ? null
                : () => _requestTransmissionCorrection(transmissionId),
            icon: const Icon(Icons.reply_outlined),
            label: const Text('Demander une correction'),
          ),
        ],
      );
    }
    if (['VERIFIEE', 'PUBLIEE'].contains(status) &&
        evaluation['correction_autorisee'] == true) {
      return Wrap(
        spacing: 8,
        children: [
          if (transmission?['proces_verbal_disponible'] == true)
            OutlinedButton.icon(
              onPressed: () => _downloadGradeMinutes(
                (transmission!['id'] as num).toInt(),
                evaluation,
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Télécharger le PV'),
            ),
          OutlinedButton.icon(
            onPressed:
                canTransmitOfficial &&
                    !hasUnsavedDrafts &&
                    evaluation['correction_prete'] == true
                ? () => _transmitEvaluation(
                    (evaluation['affectation_id'] as num?)?.toInt() ??
                        widget.assignmentId,
                    id,
                    evaluation['type_eval'].toString(),
                  )
                : null,
            icon: const Icon(Icons.send_outlined),
            label: Text(
              !canTransmitOfficial
                  ? 'Approbation de l’affectation requise'
                  : hasUnsavedDrafts
                  ? 'Enregistrez avant transmission'
                  : evaluation['correction_prete'] == true
                  ? 'Valider et transmettre la correction · ${evaluation['type_eval']}'
                  : 'Correction en cours · ${evaluation['type_eval']}',
            ),
          ),
        ],
      );
    }
    if (status == 'TRANSMISE' ||
        status == 'VERIFIEE' ||
        status == 'VALIDEE_ENSEIGNANT' ||
        status == 'PUBLIEE') {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (transmission?['proces_verbal_disponible'] == true)
            OutlinedButton.icon(
              onPressed: () => _downloadGradeMinutes(
                (transmission!['id'] as num).toInt(),
                evaluation,
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Télécharger le PV'),
            ),
          Chip(
            label: Text(
              '${evaluation['type_eval']} · ${_transmissionLabel(status)}',
            ),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: canTransmitOfficial &&
              !hasUnsavedDrafts &&
              canTransmit(status)
          ? () => _transmitEvaluation(
              (evaluation['affectation_id'] as num?)?.toInt() ??
                  widget.assignmentId,
              id,
              evaluation['type_eval'].toString(),
            )
          : null,
      icon: const Icon(Icons.send_outlined),
      label: Text(
        !canTransmitOfficial
            ? 'Après approbation · ${evaluation['type_eval']}'
            : hasUnsavedDrafts
            ? 'Enregistrez avant transmission'
            : 'Valider et transmettre ${evaluation['type_eval']} à l’agent',
      ),
    );
  }

  Future<void> _importWholeGradebook(
    List<Map<String, dynamic>> evaluations,
    Map<String, dynamic> assignment,
  ) async {
    final assignmentId = (assignment['affectation_id'] as num).toInt();
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
        assignmentId,
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
      final unregisteredCount = imported
          .where((row) => row['inscrit_ue'] != true)
          .length;
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
      if (currentProfileTypes.isEmpty) {
        final profile = _profileCodeFromWeights(weights);
        if (profile == null) {
          toast(
            context,
            'La grille détectée n’est pas une grille officielle connue.',
          );
          return;
        }
        await widget.api.teacherProposeEvaluationProfile(
          assignmentId,
          profile,
        );
        if (!mounted) return;
        toast(
          context,
          'Barème proposé pour validation; import du classeur en cours.',
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vérifier le fichier de la classe'),
          content: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['importables']} étudiant(s) avec notes sur ${data['total']}. $unregisteredCount sans inscription validée à cette UE.\nColonnes : ${importedTypes.join(' · ')}. Grille : ${weights.entries.map((e) => '${e.key} ${e.value}%').join(' · ')}.\n${clampedScores} note(s) bornée(s), ${elMarkers} absence(s). Les notes seront enregistrées en brouillon.',
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('Matricule')),
                        const DataColumn(label: Text('Étudiant')),
                        ...columns.map((column) => DataColumn(
                              label: Text('${column['entete']} /20'),
                            )),
                        const DataColumn(label: Text('Inscription / observation')),
                      ],
                      rows: imported.map((studentRow) {
                        final marks = (studentRow['notes'] as List? ?? [])
                            .whereType<Map>()
                            .toList();
                        final enrolled = studentRow['inscrit_ue'] == true;
                      final observation =
                          '${studentRow['observation'] ?? ''}'.trim();
                      return DataRow(
                        cells: [
                          DataCell(Text('${studentRow['matricule']}')),
                          DataCell(
                            Text(
                              '${studentRow['nom'] ?? ''} ${studentRow['prenom'] ?? ''}'
                                  .trim(),
                            ),
                          ),
                          ...columns.map((column) {
                            final mark = marks
                                .where(
                                  (item) =>
                                      item['index'] == column['index'],
                                )
                                .firstOrNull;
                            final value = mark?['valeur_note'];
                            final display = mark?['situation'] == 'ABSENTE'
                                ? 'ABS/EL'
                                : value == null
                                    ? '—'
                                    : '$value';
                            return DataCell(Text(display));
                          }),
                          DataCell(
                            Text(
                              observation.isNotEmpty
                                  ? observation
                                  : enrolled
                                      ? 'Inscrit à l’UE'
                                      : 'Non inscrit; à vérifier par l’agent.',
                            ),
                          ),
                        ],
                      );
                      }).toList(),
                    ),
                  ),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(errors),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '$unregisteredCount étudiant(s) sans inscription validée à cette UE seront enregistrés séparément et signalés à l’agent dans les observations.',
                  ),
                ],
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

      final refreshed = await widget.api.teacherGradebook(assignmentId);
      final activeEvaluations =
          ((refreshed['plan'] as Map?)?['composantes'] as List? ?? [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
      if (activeEvaluations.isEmpty) {
        toast(
          context,
          'Le plan provisoire de cette grille n’a pas été créé. Rechargez le carnet puis réessayez.',
        );
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
        final evaluationId = column['evaluation_id'];
        final evaluation = evaluationId == null
            ? activeEvaluations
                  .where((row) => row['type_eval'] == type)
                  .skip(occurrence - 1)
                  .firstOrNull
            : activeEvaluations
                  .where(
                    (row) =>
                        '${row['evaluation_id']}' == '$evaluationId',
                  )
                  .firstOrNull;
        if (evaluation == null) {
          throw StateError('Composante $type introuvable après import.');
        }
        final columnIndex = (column['index'] as num?)?.toInt();
        final columnHeader = '${column['entete'] ?? ''}'.toLowerCase();
        final notes = <Map<String, dynamic>>[];
        for (final studentRow in imported) {
          final matricule = '${studentRow['matricule']}'.trim().toUpperCase();
          final student = studentsByMatricule[matricule];
          final mark = (studentRow['notes'] as List? ?? [])
              .whereType<Map>()
              .where((row) =>
                  (columnIndex != null && row['index'] == columnIndex) ||
                  (columnIndex == null &&
                      '${row['entete'] ?? ''}'.toLowerCase() == columnHeader))
              .firstOrNull;
          if (mark == null) continue;
          final completeName = '${studentRow['nom_complet'] ?? ''}'.trim();
          final existing = student == null
              ? null
              : (student['notes'] as List? ?? [])
                  .whereType<Map>()
                  .where(
                    (row) =>
                        row['evaluation_id'] == evaluation['evaluation_id'],
                  )
                  .firstOrNull;
          final existingVersion = existing?['version_note'];
          notes.add({
            'matricule': matricule,
            'nom': completeName.isNotEmpty
                ? completeName
                : '${studentRow['prenom'] ?? ''} ${studentRow['nom'] ?? ''}'.trim(),
            'situation': mark['situation'],
            'valeur_note': mark['valeur_note'],
            if (existingVersion is num && existingVersion > 0)
              'version_note': existingVersion,
          });
        }
        if (notes.isNotEmpty) {
          await widget.api.teacherSaveGrades(
            assignmentId,
            (evaluation['evaluation_id'] as num).toInt(),
            grades: notes,
          );
        }
      }
      if (mounted) {
        toast(
          context,
          '${imported.length} étudiant(s) importé(s) en brouillon, y compris les non-inscrits signalés à l’agent.',
        );
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

  bool canTransmit(String? status) => status == null || status == 'A_CORRIGER';

  Map<String, dynamic> _assignmentForId(int id) => widget.assignments
      .firstWhere((assignment) => assignment['affectation_id'] == id);

  Future<void> _exportExcel(Map<String, dynamic> assignment) async {
    final assignmentId = (assignment['affectation_id'] as num).toInt();
    try {
      final bytes = await widget.api.teacherExportGradebook(
        assignmentId,
      );
      final classCode =
          '${assignment['code_classe'] ?? assignment['classe'] ?? 'classe'}';
      final filename = 'notes-$classCode-${assignment['code_ue']}.xlsx';
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
    'TRANSMISE' => 'Envoyée à l’agent',
    'A_VERIFIER' => 'À vérifier',
    'VERIFIEE' => 'Vérifiée',
    'VALIDEE_ENSEIGNANT' => 'Validée · publication agent attendue',
    'PUBLIEE' => 'Publiée aux étudiants',
    'A_CORRIGER' => 'À corriger',
    _ => 'Brouillon',
  };

  Future<void> _transmitEvaluation(
    int assignmentId,
    int evaluationId,
    String type,
  ) async {
    final why = await _reasonDialog('Transmettre les notes · $type');
    if (!mounted || why == null) return;
    try {
      await widget.api.teacherTransmitGrades(
        assignmentId,
        evaluationId,
        reason: why,
      );
      if (mounted) {
        toast(
          context,
          'Grille transmise à l’espace Agent, sous « Traitement des PV », pour numérisation et traitement du PV.',
        );
        reload();
      }
    } catch (error) {
      if (mounted) {
        if (error is ApiFailure && error.statusCode == 409) reload();
        toast(context, error is ApiFailure ? error.message : error.toString());
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
          'Notes vérifiées. Elles seront visibles aux étudiants après publication par la cellule informatique.',
        );
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

  Future<void> _requestTransmissionCorrection(int transmissionId) async {
    final why = await _reasonDialog('Demander une correction du PV');
    if (!mounted || why == null) return;
    try {
      await widget.api.teacherDecideGradeTransmission(
        transmissionId,
        decision: 'CORRIGER',
        reason: why,
      );
      if (mounted) {
        toast(
          context,
          'Correction demandée. Enregistrez vos changements, puis retransmettez la grille à la cellule.',
        );
        reload();
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    }
  }

  Future<void> _downloadGradeMinutes(int transmissionId, Map evaluation) async {
    try {
      final bytes = await widget.api.teacherDownloadGradeTransmissionMinutes(
        transmissionId,
      );
      await downloadFile(
        'PV-${evaluation['type_eval']}-${widget.assignment['code_ue']}.pdf',
        bytes,
      );
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
      'Matricule;Nom;UE;Évaluation;Poids (%);Note (/20);Situation;Statut',
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
            widget.assignment['code_ue'],
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
      ['Matricule', 'Étudiant', 'UE', 'Évaluation', 'Poids', 'Note /20', 'Situation'],
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
          '${widget.assignment['code_ue'] ?? ''}',
          '${evaluation['type_eval'] ?? ''}',
          '${evaluation['poids_evaluation'] ?? ''}%',
          '${note?['valeur_note'] ?? '—'}',
          '${note?['situation'] ?? 'MANQUANTE'}',
        ]);
      }
    }
    final document = pw.Document(theme: await gnuPdfTheme());
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
    await downloadFile(
      'notes-${widget.assignment['code_ue']}.pdf',
      await document.save(),
    );
  }

  Future<void> _exportMinutes({
    required Set<String> types,
    required Map<String, dynamic> metadata,
  }) async {
    late List<Map<String, dynamic>> currentStudents;
    late List<Map<String, dynamic>> currentEvaluations;
    Map<String, dynamic> source;
    try {
      // The toolbar and the editable grid can hold different in-memory copies.
      // Reload every EC so the PV always reflects the latest saved server values.
      final fresh = await _loadGradebook();
      currentStudents = (fresh['etudiants'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final freshPlan = fresh['plan'] as Map? ?? {};
      currentEvaluations = (freshPlan['composantes'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      source = <String, dynamic>{...widget.assignment, ...fresh};
    } catch (error) {
      if (mounted) toast(context, 'Impossible d’actualiser le carnet avant le PV : $error');
      return;
    }
    if (currentStudents.isEmpty) {
      toast(context, 'Aucun étudiant dans le carnet actualisé.');
      return;
    }
    final snMinutes = types.length == 1 && types.contains('SN');
    int? evaluationKey(Object? value) => int.tryParse('$value');
    final selected =
        currentEvaluations
            .where(
              (row) => snMinutes
                  ? {'CC', 'TP', 'TPE', 'SN'}.contains('${row['type_eval']}')
                  : types.contains('${row['type_eval']}'),
            )
            .toList()
          ..sort((a, b) {
            const order = {'CC': 0, 'TP': 1, 'TPE': 2, 'SN': 3};
            final byType = (order['${a['type_eval']}'] ?? 9).compareTo(
              order['${b['type_eval']}'] ?? 9,
            );
            return byType != 0
                ? byType
                : '${a['date_evaluation']}'.compareTo(
                    '${b['date_evaluation']}',
                  );
          });
    if (selected.isEmpty) {
      toast(
        context,
        'Aucune note ${types.join(', ')} à imprimer dans ce carnet.',
      );
      return;
    }
    if (snMinutes) {
      try {
        final document = pw.Document(theme: await gnuPdfTheme());
        final asset = await rootBundle.load('assets/pv_sn_header.jpg');
        addSessionNormale(document, pw.MemoryImage(asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes)),
            source, selected, currentStudents);
        final bytes = await document.save();
        await Printing.layoutPdf(onLayout: (_) async => bytes,
            name: "PV-SN-${source['code_ue']}-${source['code_classe']}.pdf");
      } catch (error) {
        if (mounted) toast(context, 'Impression du PV de SN impossible : $error');
      }
      return;
    }
    if (types.length == 1 && const {'CC', 'TP', 'TPE'}.contains(types.single)) {
      try {
        final document = pw.Document(theme: await gnuPdfTheme());
        final header = await rootBundle.load('assets/pv_uy1_header.png');
        final image = pw.MemoryImage(header.buffer.asUint8List(header.offsetInBytes, header.lengthInBytes));
        for (final evaluation in selected) {
          addEvaluationMinutes(document, image, source, evaluation, currentStudents,
              distinguishEvaluation: selected.length > 1);
        }
        final bytes = await document.save();
        final name = "PV-${types.single}-${source['code_ue']}-${source['code_classe']}.pdf";
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      } catch (error) {
        if (mounted) toast(context, 'Impression du PV impossible : $error');
      }
      return;
    }
    final combined = selected.length > 1;
    final includeFinalResult = combined;

    final cells = <String>[
      'N°',
      'MATRICULE',
      'NOMS ET PRÉNOMS',
      ...selected.map(
        (evaluation) =>
            '${evaluation['type_eval']} (${evaluation['poids_evaluation'] ?? '—'}%) · ${evaluation['date_evaluation'] ?? 'date à fixer'}',
      ),
      if (includeFinalResult) 'NOTE FINALE /100',
      if (includeFinalResult) 'GRADE UE',
      'OBSERVATIONS',
    ];
    final rows = <List<String>>[];
    for (var index = 0; index < currentStudents.length; index++) {
      final student = currentStudents[index];
      final studentNotes = (student['notes'] as List? ?? []).whereType<Map>();
      final values = <String>[];
      var hasMissing = false;
      for (final evaluation in selected) {
        final evaluationId = evaluationKey(evaluation['evaluation_id']);
        final note = studentNotes
            .where((row) => evaluationKey(row['evaluation_id']) == evaluationId)
            .firstOrNull;
        final situation = '${note?['situation'] ?? 'MANQUANTE'}';
        final value = note?['valeur_note'];
        final numericValue = value is num
            ? value
            : num.tryParse('${value ?? ''}'.trim().replaceAll(',', '.'));
        if (situation == 'ABSENTE') {
          values.add('EL');
          hasMissing = true;
        } else if (situation != 'NUMERIQUE' || numericValue == null) {
          values.add('—');
          hasMissing = true;
        } else {
          values.add(numericValue.toStringAsFixed(2));
        }
      }
      final ueResult = student['resultat_ue_provisoire'] as Map?;
      final rawTotal = ueResult?['arrondi'];
      final totalOn100 = rawTotal is num
          ? rawTotal
          : num.tryParse('${rawTotal ?? ''}'.trim().replaceAll(',', '.'));
      final finalMark = student['hors_compte'] == true
          ? 'HORS CALCUL'
          : ueResult == null
          ? '—'
          : ueResult['en_attente'] == true
          ? 'EN ATTENTE'
          : ueResult['el'] == true
          ? 'EL'
          : totalOn100 is num
          ? totalOn100.toStringAsFixed(2)
          : '—';
      final officialGrade = student['hors_compte'] == true
          ? 'NON INSCRIT'
          : '${ueResult?['grade'] ?? '—'}';
      rows.add([
        '${index + 1}',
        '${student['matricule'] ?? ''}',
        [student['prenom'], student['nom']]
            .where((part) => part != null && '$part'.trim().isNotEmpty)
            .join(' '),
        ...values,
        if (includeFinalResult) finalMark,
        if (includeFinalResult) officialGrade,
        student['hors_compte'] == true
            ? (student['observation'] ?? 'Étudiant non inscrit dans la classe ou l’UE').toString()
            : hasMissing
            ? 'Note manquante ou absence à contrôler'
            : '',
      ]);
    }

    Uint8List? logoBytes;
    final logoData = source['logo_structure'];
    if (logoData is Map && logoData['base64'] is String) {
      logoBytes = base64Decode(logoData['base64'] as String);
    }
    if (logoBytes == null) {
      try {
        logoBytes = (await rootBundle.load('assets/uy1_crest.png')).buffer
            .asUint8List();
      } catch (_) {
        logoBytes = null;
      }
    }
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final document = pw.Document(theme: await gnuPdfTheme());
    final room = '${source['code_classe'] ?? source['classe'] ?? '—'}';
    final year = '${source['annee_academique'] ?? '—'}';
    final unitCode = '${source['code_ue'] ?? '—'}';
    final selectedTypes = selected.map((e) => '${e['type_eval']}').toSet();
    String fileSegment(Object? value) =>
        '${value ?? ''}'.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final title = combined
        ? 'PROCÈS-VERBAL RÉCAPITULATIF DES NOTES · UE $unitCode'
        : 'PROCÈS-VERBAL DE ${selected.first['type_eval']}';
    final typeSlug = selectedTypes.toList()..sort();
    final assignmentSegment = fileSegment(
      (source['affectation_ids'] as List?)?.join('-') ??
          source['affectation_id'],
    );
    final identity = [
      unitCode,
      room,
      year,
      if (assignmentSegment.isNotEmpty) 'A$assignmentSegment',
    ].map(fileSegment).where((segment) => segment.isNotEmpty).join('-');
    final filename = combined
        ? 'PV-${typeSlug.join('-')}-$identity.pdf'
        : 'PV-${selected.first['type_eval']}-$identity.pdf';
    document.addPage(
      pw.MultiPage(
        pageFormat: combined
            ? pdf.PdfPageFormat.a4.landscape
            : pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 28),
        header: (_) => gnuPvHeader(
          crest: logo,
          university: '${source['universite'] ?? 'UNIVERSITÉ DE YAOUNDÉ I'}',
          faculty: '${source['faculte'] ?? 'FACULTÉ'}',
          department: '${source['departement'] ?? 'DÉPARTEMENT'}',
          title: title,
          subtitle:
              '$unitCode · ${source['intitule_ue'] ?? ''} · Évaluations communes de l’UE',
          details:
              '${source['niveau'] ?? '—'} · $room · Semestre ${source['numero_semestre'] ?? '—'} · Année académique $year',
        ),
        footer: (context) => gnuPvFooter(
          'GNU · Copie enseignant · Notes à contrôler par la cellule informatique · $year',
          context,
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: cells,
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: combined ? 7 : 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: combined ? 7 : 8),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {2: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(color: pdf.PdfColors.black, width: .45),
            headerDecoration: const pw.BoxDecoration(
              color: pdf.PdfColor(.86, .91, .89),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Statut de transmission : ${selected.map((e) => '${e['type_eval']} · ${(e['transmission'] as Map?)?['statut'] ?? 'BROUILLON'}').join('     ')}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          if (includeFinalResult)
            pw.Text(
              'La note finale /100 et le grade UE proviennent du calcul officiel GNU, selon les pondérations de CC, TP/TPE, SN et les crédits des EC. Ils restent provisoires jusqu’à la validation par l’enseignant et la publication par l’agent. Les étudiants non inscrits sont signalés et exclus du calcul officiel.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Établi le ${DateTime.now().toLocal().toIso8601String().split('T').first}. Les notes restent provisoires jusqu’à leur validation par l’enseignant et leur publication par l’agent.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 25),
          pw.TableHelper.fromTextArray(
            headers: [
              'Enseignant responsable',
              'Cellule informatique',
              'Chef du département',
            ],
            data: [
              [
                '${widget.api.user?['prenom'] ?? ''} ${widget.api.user?['nom'] ?? ''}\nSignature',
                'Visa et cachet',
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
    try {
      final bytes = await document.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);
    } catch (error) {
      if (mounted) toast(context, 'Impression du PV impossible : $error');
    }
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
  const TeacherAccountPage({super.key, required this.api, required this.page});

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
              subtitle:
                  '${items.where((item) => item['lue'] != true).length} non lue(s)',
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
      subtitle: Text('${content['message'] ?? ''}\n${item['date'] ?? ''}'),
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
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                  ),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                  ),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.length < 12 ||
                        !RegExp(r'[A-Za-z]').hasMatch(text) ||
                        !RegExp(r'\d').hasMatch(text)) {
                      return '12 caractères minimum, avec lettres et chiffres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                  ),
                  validator: (value) => value != password.text
                      ? 'Les mots de passe diffèrent'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, formKey.currentState!.validate()),
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
        notifications = Future.value(
          items
              .map((item) => item['id'] == id ? {...item, 'lue': true} : item)
              .toList(),
        );
      });
    } catch (error) {
      if (mounted) toast(context, '$error');
    } finally {
      if (mounted) setState(() => markingRead.remove(id));
    }
  }
}

class _EvaluationGradeEntryScreen extends StatefulWidget {
  const _EvaluationGradeEntryScreen({
    required this.api,
    required this.assignmentId,
    required this.book,
    required this.evaluation,
    required this.students,
    required this.onSaved,
  });

  final StudentApiClient api;
  final int assignmentId;
  final Map<String, dynamic> book;
  final Map<String, dynamic> evaluation;
  final List<Map<String, dynamic>> students;
  final VoidCallback onSaved;

  @override
  State<_EvaluationGradeEntryScreen> createState() =>
      _EvaluationGradeEntryScreenState();
}

class _EvaluationGradeEntryScreenState
    extends State<_EvaluationGradeEntryScreen> {
  late List<Map<String, dynamic>> students;
  List<Map<String, dynamic>> importedGrades = const [];
  int importRevision = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    students = widget.students
        .map((student) => Map<String, dynamic>.from(student))
        .toList();
  }

  String _key(Object? matricule) => '${matricule ?? ''}'.trim().toUpperCase();

  Future<void> _downloadTemplate() async {
    setState(() => busy = true);
    try {
      final bytes = await widget.api.teacherExportEvaluationTemplate(
        widget.assignmentId,
        (widget.evaluation['evaluation_id'] as num).toInt(),
      );
      await downloadFile(
        'modele-${widget.book['code_classe']}-${widget.book['code_ue']}-${widget.evaluation['type_eval']}.xlsx',
        bytes,
      );
    } catch (error) {
      if (mounted) toast(context, error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _importTemplate() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv', 'txt'],
      withData: true,
    );
    if (selection == null || selection.files.isEmpty) return;
    final file = selection.files.first;
    if (file.bytes == null) return;
    setState(() => busy = true);
    try {
      final response = await widget.api.teacherPreviewEvaluationImport(
        widget.assignmentId,
        (widget.evaluation['evaluation_id'] as num).toInt(),
        filename: file.name,
        file: file.bytes!,
      );
      final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
      final imported = (data['notes'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final updatedStudents = students
          .map((student) => Map<String, dynamic>.from(student))
          .toList();
      for (final row in imported) {
        final matricule = _key(row['matricule']);
        final index = updatedStudents.indexWhere(
          (student) => _key(student['matricule']) == matricule,
        );
        final note = <String, dynamic>{
          'evaluation_id': widget.evaluation['evaluation_id'],
          'valeur_note': row['valeur_note'],
          'situation': row['situation'],
          'version_note': row['version_note'],
          'hors_compte': row['hors_compte'] == true,
          'observation': row['observation'],
        };
        if (index < 0) {
          updatedStudents.add({
            'matricule': row['matricule'],
            'nom': row['nom'],
            'prenom': '',
            'inscription_ue_id': null,
            'inscription_classe_id': null,
            'hors_compte': true,
            'observation': row['observation'] ?? 'Étudiant non inscrit dans la classe ou l’UE; à vérifier par l’agent.',
            'notes': [note],
          });
        } else {
          final existing = updatedStudents[index];
          final notes = (existing['notes'] as List? ?? [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) => '${item['evaluation_id']}' != '${widget.evaluation['evaluation_id']}')
              .toList()
            ..add(note);
          existing['notes'] = notes;
          if (row['hors_compte'] == true) {
            existing['hors_compte'] = true;
            existing['nom'] = row['nom'];
            existing['observation'] = row['observation'];
          }
        }
      }
      updatedStudents.sort(
        (a, b) => _key(a['matricule']).compareTo(_key(b['matricule'])),
      );
      if (mounted) {
        setState(() {
          students = updatedStudents;
          importedGrades = imported
              .map(
                (row) => {
                  ...row,
                  'evaluation_id': widget.evaluation['evaluation_id'],
                },
              )
              .toList();
          importRevision++;
        });
        final errors = (data['erreurs'] as List? ?? []).length;
        toast(
          context,
          '${imported.length} ligne(s) chargée(s), $errors erreur(s). Enregistrez les notes pour les conserver.',
        );
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addExternalStudent() async {
    final name = TextEditingController();
    final matricule = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ajouter un étudiant non inscrit'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom et prénoms')),
                TextField(controller: matricule, decoration: const InputDecoration(labelText: 'Matricule')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ajouter')),
          ],
        ),
      );
      if (accepted != true) return;
      final code = _key(matricule.text);
      if (name.text.trim().isEmpty || code.isEmpty) {
        toast(context, 'Le nom et le matricule sont obligatoires.');
        return;
      }
      if (students.any((student) => _key(student['matricule']) == code)) {
        toast(context, 'Ce matricule est déjà présent dans cette grille.');
        return;
      }
      setState(() {
        students.add({
          'matricule': code,
          'nom': name.text.trim(),
          'prenom': '',
          'inscription_ue_id': null,
          'inscription_classe_id': null,
          'hors_compte': true,
          'observation': 'Étudiant non inscrit; à vérifier par l’agent.',
          'notes': [
            {
              'evaluation_id': widget.evaluation['evaluation_id'],
              'valeur_note': null,
              'situation': 'MANQUANTE',
              'version_note': null,
              'hors_compte': true,
            },
          ],
        });
        students.sort((a, b) => _key(a['matricule']).compareTo(_key(b['matricule'])));
      });
    } finally {
      name.dispose();
      matricule.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = widget.evaluation;
    final className = widget.book['code_classe'] ?? widget.book['classe'] ?? 'Classe';
    final specialty = widget.book['specialite'] ?? widget.book['intitule_specialite'] ?? widget.book['niveau'] ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text('Saisie ${evaluation['type_eval']} · ${widget.book['code_ue']}'),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$className · $specialty · ${widget.book['code_ue']} · ${widget.book['code_m'] ?? widget.book['code_matiere'] ?? ''}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('${evaluation['type_eval']} · ${evaluation['poids_evaluation']} % · ${evaluation['date_evaluation'] ?? ''} · ${students.length} étudiant(s)'),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  OutlinedButton.icon(onPressed: busy ? null : _downloadTemplate, icon: const Icon(Icons.download_outlined), label: const Text('Télécharger modèle Excel')),
                  OutlinedButton.icon(onPressed: busy ? null : _importTemplate, icon: const Icon(Icons.upload_file_outlined), label: const Text('Importer le modèle rempli')),
                  OutlinedButton.icon(onPressed: busy ? null : _addExternalStudent, icon: const Icon(Icons.person_add_alt_1), label: const Text('Ajouter un non-inscrit')),
                  if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 10),
                const Notice(
                  'Format requis : Nom | Matricule | Note/20. Toute note importée peut être enregistrée puis transmise à la cellule. Les matricules sans inscription validée à la classe ou à l’UE sont signalés « hors compte » et transmis comme observation; ils ne comptent pas dans les résultats officiels.',
                ),
              ],
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('Aucun étudiant. Importez un modèle ou ajoutez un étudiant.'))
                : _GradebookGrid(
                    key: ValueKey('single-evaluation-${evaluation['evaluation_id']}'),
                    api: widget.api,
                    assignmentId: widget.assignmentId,
                    students: students,
                    evaluations: [evaluation],
                    isCorrection: false,
                    onUnsavedEvaluationsChanged: (_) {},
                    onSaved: widget.onSaved,
                    importRevision: importRevision,
                    importedGrades: importedGrades,
                  ),
          ),
        ],
      ),
    );
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
    required this.onUnsavedEvaluationsChanged,
    this.onSaved,
    this.importRevision = 0,
    this.importedGrades = const [],
    this.allowDrafts = true,
  });

  final StudentApiClient api;
  final int assignmentId;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> evaluations;
  final bool isCorrection;
  final ValueChanged<Set<int>> onUnsavedEvaluationsChanged;
  final VoidCallback? onSaved;
  final int importRevision;
  final List<Map<String, dynamic>> importedGrades;
  final bool allowDrafts;

  @override
  State<_GradebookGrid> createState() => _GradebookGridState();
}

class _GradebookGridState extends State<_GradebookGrid> {
  late final Map<String, Map<String, dynamic>> drafts;
  final ScrollController horizontalScrollController = ScrollController();
  bool saving = false;

  String _key(String matricule, Object? evaluationId) =>
      '${matricule.trim().toUpperCase()}:$evaluationId';

  @override
  void initState() {
    super.initState();
    drafts = {};
    final importedCells = {
      for (final grade in widget.importedGrades)
        _key('${grade['matricule']}', grade['evaluation_id']),
    };
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
        final importedExternalCell = importedCells.contains(key) &&
            student['hors_compte'] == true;
        drafts[key] = {
          'valeur_note': value?.toString() ?? '',
          'situation': note?['situation'] ?? 'MANQUANTE',
          'version_note': note?['version_note'],
          'correction_autorisee': note?['correction_autorisee'] == true,
          'initial_value': importedExternalCell
              ? ''
              : (value?.toString() ?? ''),
          'initial_situation': importedExternalCell
              ? 'MANQUANTE'
              : (note?['situation'] ?? 'MANQUANTE'),
          'revision': 0,
        };
      }
    }
  }

  @override
  void didUpdateWidget(covariant _GradebookGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final importChanged = oldWidget.importRevision != widget.importRevision;
    final importedCells = {
      for (final grade in widget.importedGrades)
        _key('${grade['matricule']}', grade['evaluation_id']),
    };

    for (final student in widget.students) {
      for (final evaluation in widget.evaluations) {
        final evaluationId = evaluation['evaluation_id'];
        final key = _key('${student['matricule']}', evaluationId);
        if (drafts.containsKey(key)) {
          continue;
        }
        final note = (student['notes'] as List? ?? [])
            .whereType<Map>()
            .where((row) => '${row['evaluation_id']}' == '$evaluationId')
            .firstOrNull;
        final value = note?['valeur_note'];
        final situation = note?['situation'] ?? 'MANQUANTE';
        final importedExternalCell = importChanged &&
            importedCells.contains(key) &&
            student['hors_compte'] == true;
        drafts[key] = {
          'valeur_note': value?.toString() ?? '',
          'situation': situation,
          'version_note': note?['version_note'],
          'correction_autorisee': note?['correction_autorisee'] == true,
          'initial_value': importedExternalCell
              ? ''
              : (value?.toString() ?? ''),
          'initial_situation': importedExternalCell
              ? 'MANQUANTE'
              : situation,
          'revision': 0,
        };
      }
    }

    if (!importChanged) {
      return;
    }

    for (final grade in widget.importedGrades) {
      final key = _key('${grade['matricule']}', grade['evaluation_id']);
      final draft = drafts[key];
      if (draft == null) {
        continue;
      }
      draft['valeur_note'] = grade['valeur_note']?.toString() ?? '';
      draft['situation'] = grade['situation'] ?? 'MANQUANTE';
      draft['version_note'] = grade['version_note'] ?? draft['version_note'];
      draft['revision'] = (draft['revision'] as int) + 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyUnsavedEvaluationChanges();
      }
    });
  }

  bool _locked(Map<String, dynamic> evaluation, [Map<String, dynamic>? draft]) {
    final status = (evaluation['transmission'] as Map?)?['statut'];
    if (['VERIFIEE', 'PUBLIEE'].contains(status) &&
        draft?['correction_autorisee'] == true) {
      return false;
    }
    return !widget.allowDrafts || [
      'TRANSMISE',
      'VERIFIEE',
      'VALIDEE_ENSEIGNANT',
      'PUBLIEE',
    ].contains(status);
  }

  bool _cellHasUnsaved(Map<String, dynamic> draft) =>
      draft['valeur_note']?.toString() != draft['initial_value']?.toString() ||
      draft['situation'] != draft['initial_situation'];

  @override
  void dispose() {
    horizontalScrollController.dispose();
    super.dispose();
  }

  Set<int> _unsavedEvaluationIds() => {
    for (final evaluation in widget.evaluations)
      if (widget.students.any((student) {
        final key = _key(
          '${student['matricule']}',
          evaluation['evaluation_id'],
        );
        return _cellHasUnsaved(drafts[key]!);
      }))
        (evaluation['evaluation_id'] as num).toInt(),
  };

  void _notifyUnsavedEvaluationChanges() {
    widget.onUnsavedEvaluationsChanged(_unsavedEvaluationIds());
  }

  String _dateLabel(Object? value) {
    final date = '${value ?? ''}';
    return date.length >= 10 ? date.substring(0, 10) : date;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          widget.evaluations.any(
                (evaluation) =>
                    evaluation['transmission']?['statut'] == 'A_VERIFIER',
              )
              ? 'PV retourné par la cellule · comparez les notes aux valeurs numérisées, corrigez si nécessaire, puis enregistrez avant votre décision.'
              : widget.isCorrection
              ? 'Grille par étudiant · saisissez directement les notes et marquez EL pour une absence.'
              : 'Grille par étudiant · saisissez les notes directement, sans changer d’étudiant dans une liste.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Scrollbar(
                controller: horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    horizontalMargin: 16,
                    columnSpacing: 18,
                    headingRowHeight: 64,
                    dataRowMinHeight: 76,
                    dataRowMaxHeight: 92,
                    columns: [
                      const DataColumn(
                        label: SizedBox(
                          width: 230,
                          child: Text('Étudiant'),
                        ),
                      ),
                      for (final evaluation in widget.evaluations)
                        DataColumn(
                          label: SizedBox(
                            width: 220,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${evaluation['type_eval']} · ${evaluation['poids_evaluation']} %',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _dateLabel(evaluation['date_evaluation']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    rows: [
                      for (final student in widget.students)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 230,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student['prenom'] ?? ''} ${student['nom'] ?? ''}'
                                          .trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${student['matricule'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    if (student['hors_compte'] == true)
                                      Text(
                                        'HORS COMPTE · à vérifier par l’agent',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            for (final evaluation in widget.evaluations)
                              DataCell(_gradeCell(student, evaluation)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Notice(
              widget.evaluations.any(
                    (evaluation) =>
                        evaluation['transmission']?['statut'] == 'A_VERIFIER',
                  )
                  ? 'La cellule a retourné le PV pour vérification. Vous pouvez modifier les notes et les enregistrer. Si une valeur diffère de la numérisation, demandez ensuite une correction afin de renvoyer la grille à la cellule.'
                  : 'Saisissez une note sur 20 dans la cellule de chaque étudiant. Laissez vide si elle reste à saisir ; cochez EL pour signaler une absence. Enregistrez chaque composante avant de la transmettre.',
              warning: widget.evaluations.any(
                (evaluation) =>
                    evaluation['transmission']?['statut'] == 'A_VERIFIER',
              ),
            ),
            const SizedBox(height: 12),
            for (final evaluation in widget.evaluations)
              _evaluationSaveAction(evaluation),
          ],
        ),
      ),
    ],
  );

  Widget _gradeCell(
    Map<String, dynamic> student,
    Map<String, dynamic> evaluation,
  ) {
    final matricule = '${student['matricule']}';
    final evaluationId = evaluation['evaluation_id'];
    final key = _key(matricule, evaluationId);
    final draft = drafts[key]!;
    final disabled = saving || _locked(evaluation, draft);
    final absent = draft['situation'] == 'ABSENTE';
    final score = '${draft['valeur_note'] ?? ''}';
    final parsed = double.tryParse(score.replaceAll(',', '.'));
    final invalid = draft['situation'] == 'INVALIDE' ||
        (!absent &&
            score.isNotEmpty &&
            (parsed == null || parsed < 0 || parsed > 20));
    final stageNote = (student['notes'] as List? ?? [])
        .whereType<Map>()
        .where((note) => '${note['evaluation_id']}' == '$evaluationId')
        .firstOrNull;
    final cellWidth = 220.0;

    return SizedBox(
      width: cellWidth,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('grade-$key-${draft['revision']}'),
              initialValue: score,
              enabled: !disabled && !absent,
              inputFormatters: [_gradeScoreFormatter()],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: absent ? 'EL · absence' : 'Note /20',
                hintText: absent ? null : 'Ex. 14,5',
                isDense: true,
                errorText: invalid ? 'Note invalide' : null,
              ),
              onChanged: (raw) {
                setState(() {
                  final value = raw.trim();
                  final parsed = value.isEmpty
                      ? null
                      : double.tryParse(value.replaceAll(',', '.'));
                  draft['valeur_note'] = raw;
                  draft['situation'] = parsed == null
                      ? (value.isEmpty ? 'MANQUANTE' : 'INVALIDE')
                      : 'NUMERIQUE';
                });
                _notifyUnsavedEvaluationChanges();
              },
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Marquer l’étudiant absent (EL)',
            child: FilterChip(
              label: const Text('EL'),
              selected: absent,
              onSelected: disabled
                  ? null
                  : (selected) {
                      setState(() {
                        draft['situation'] = selected
                            ? 'ABSENTE'
                            : (score.isEmpty ? 'MANQUANTE' : 'NUMERIQUE');
                        if (selected) draft['valeur_note'] = '';
                        draft['revision'] = (draft['revision'] as int) + 1;
                      });
                      _notifyUnsavedEvaluationChanges();
                    },
            ),
          ),
          if (evaluation['transmission']?['statut'] == 'A_VERIFIER' &&
              stageNote?['situation_numerisee'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message:
                    'Cellule : ${stageNote?['situation_numerisee'] == 'NUMERIQUE' ? '${stageNote?['valeur_numerisee']}/20' : stageNote?['situation_numerisee']}',
                child: const Icon(Icons.fact_check_outlined, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _evaluationSaveAction(Map<String, dynamic> evaluation) {
    final evaluationId = (evaluation['evaluation_id'] as num).toInt();
    final changed = widget.students.where((student) {
      final key = _key('${student['matricule']}', evaluationId);
      return _cellHasUnsaved(drafts[key]!);
    }).toList();
    final invalid = changed.any((student) {
      final key = _key('${student['matricule']}', evaluationId);
      final draft = drafts[key]!;
      if (draft['situation'] == 'INVALIDE') return true;
      if (draft['situation'] != 'NUMERIQUE') return false;
      final parsed = double.tryParse(
        '${draft['valeur_note']}'.replaceAll(',', '.'),
      );
      return parsed == null || parsed < 0 || parsed > 20;
    });
    final locked = changed.any((student) {
      final key = _key('${student['matricule']}', evaluationId);
      return _locked(evaluation, drafts[key]);
    });
    final savedCount = widget.students.where((student) {
      final key = _key('${student['matricule']}', evaluationId);
      final draft = drafts[key]!;
      return draft['version_note'] is num &&
          (draft['version_note'] as num) > 0 &&
          !_cellHasUnsaved(draft);
    }).length;
    final status = changed.isNotEmpty
        ? '${changed.length} note(s) modifiée(s) · enregistrement en attente'
        : savedCount > 0
        ? '$savedCount note(s) enregistrée(s) en brouillon · aucune modification en attente'
        : 'Aucune note enregistrée pour ${evaluation['type_eval']}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text('${evaluation['type_eval']} · ${evaluation['poids_evaluation']} % · $status'),
            ),
            if (changed.isEmpty && savedCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            FilledButton.icon(
              onPressed: saving || changed.isEmpty || invalid || locked
                  ? null
                  : () => _saveEvaluation(evaluation, changed),
              icon: const Icon(Icons.save_outlined),
              label: Text('Enregistrer ${evaluation['type_eval']}'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEvaluation(
    Map<String, dynamic> evaluation,
    List<Map<String, dynamic>> changedStudents,
  ) async {
    final evaluationId = (evaluation['evaluation_id'] as num).toInt();
    final submittedDrafts = <Map<String, dynamic>>[];
    final grades = changedStudents.map((student) {
      final key = _key('${student['matricule']}', evaluationId);
      final draft = drafts[key]!;
      final score = '${draft['valeur_note'] ?? ''}'.trim();
      final parsed = score.isEmpty
          ? null
          : double.tryParse(score.replaceAll(',', '.'));
      final situation = draft['situation'] == 'ABSENTE'
          ? 'ABSENTE'
          : score.isEmpty
          ? 'MANQUANTE'
          : 'NUMERIQUE';
      submittedDrafts.add(draft);
      return {
        'matricule': student['matricule'],
        if (student['hors_compte'] == true) 'nom': student['nom'],
        'situation': situation,
        'valeur_note': situation == 'NUMERIQUE' ? parsed : null,
        if (draft['version_note'] is num && (draft['version_note'] as num) > 0)
        'version_note': draft['version_note'],
        if (student['hors_compte'] == true) 'hors_compte': true,
      };
    }).toList();

    setState(() => saving = true);
    try {
      await widget.api.teacherSaveGrades(
        (evaluation['affectation_id'] as num?)?.toInt() ??
            widget.assignmentId,
        evaluationId,
        grades: grades,
      );
      if (!mounted) return;
      setState(() {
        for (var index = 0; index < submittedDrafts.length; index++) {
          final draft = submittedDrafts[index];
          final grade = grades[index];
          draft['valeur_note'] = grade['valeur_note']?.toString() ?? '';
          draft['situation'] = grade['situation'];
          draft['initial_value'] = draft['valeur_note'];
          draft['initial_situation'] = draft['situation'];
          draft['version_note'] = draft['version_note'] ?? 1;
          draft['revision'] = (draft['revision'] as int) + 1;
        }
        saving = false;
      });
      _notifyUnsavedEvaluationChanges();
      widget.onSaved?.call();
      toast(
        context,
        'Notes ${evaluation['type_eval']} enregistrées en brouillon pour ${grades.length} étudiant(s).',
      );
    } catch (error) {
      if (mounted) toast(context, error.toString());
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }
}
