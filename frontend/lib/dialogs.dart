import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'domain.dart';
import 'ui.dart';

class RequestDialog extends StatefulWidget {
  const RequestDialog({super.key, required this.store});
  final DemoStore store;
  @override
  State<RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<RequestDialog> {
  final form = GlobalKey<FormState>();
  final message = TextEditingController();
  String course = 'INF 201', type = 'Vérification de note';
  String? proofName, error;
  Uint8List? bytes;
  bool picking = false;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024 || file.bytes == null || file.size == 0) {
        setState(
          () => error = 'Choisissez un fichier non vide de 5 Mo maximum.',
        );
        return;
      }
      setState(() {
        proofName = file.name;
        bytes = file.bytes;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Impossible de lire ce fichier. Veuillez réessayer.',
        );
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle requête'),
    content: SizedBox(
      width: 490,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Décrivez précisément votre demande pour faciliter son traitement.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: course,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Unité d’enseignement',
                ),
                items: widget.store.courses
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.code,
                        child: Text(
                          '${c.code} · ${c.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => course = value!),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Objet de la demande',
                ),
                items:
                    [
                          'Vérification de note',
                          'Absence justifiée',
                          'Autre demande',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => type = value!),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: message,
                minLines: 4,
                maxLines: 7,
                maxLength: 1500,
                decoration: const InputDecoration(
                  labelText: 'Votre message',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value?.trim().length ?? 0) < 15
                    ? 'Précisez votre demande en au moins 15 caractères.'
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: picking ? null : pick,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(
                  picking
                      ? 'Lecture du fichier…'
                      : proofName == null
                      ? 'Joindre un justificatif'
                      : 'Remplacer le justificatif',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                proofName ?? 'PDF, JPG ou PNG · 5 Mo maximum\nObligatoire pour une absence.',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              if (proofName != null)
                TextButton(
                  onPressed: () => setState(() {
                    proofName = null;
                    bytes = null;
                  }),
                  child: const Text('Retirer la pièce jointe'),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Démonstration : la demande et son justificatif restent uniquement en mémoire.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: picking
            ? null
            : () {
                if (!form.currentState!.validate()) return;
                if (type == 'Absence justifiée' && bytes == null) {
                  setState(
                    () => error =
                        'Joignez une preuve pour justifier cette absence.',
                  );
                  return;
                }
                widget.store.addRequest(
                  AcademicRequest(
                    id: 'REQ-${(widget.store.requests.length + 1).toString().padLeft(3, '0')}',
                    course: course,
                    type: type,
                    message: message.text.trim(),
                    proofName: proofName,
                    proofBytes: bytes,
                  ),
                );
                Navigator.pop(context);
              },
        child: const Text('Soumettre la requête'),
      ),
    ],
  );
}

class EditorField {
  const EditorField(
    this.id,
    this.label, {
    this.options,
    this.initial,
    this.validate,
    this.lines = 1,
  });
  final String id, label;
  final List<String>? options;
  final String? initial;
  final String? Function(String)? validate;
  final int lines;
}

class EditorDialog extends StatefulWidget {
  const EditorDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.note,
    this.submit = 'Enregistrer',
  });
  final String title, submit;
  final String? note;
  final List<EditorField> fields;
  final String? Function(Map<String, String>) onSave;
  @override
  State<EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<EditorDialog> {
  final form = GlobalKey<FormState>();
  late final values = {
    for (final field in widget.fields)
      field.id: field.initial ?? field.options?.first ?? '',
  };
  String? error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.note != null) ...[
                Text(
                  widget.note!,
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
              ],
              ...widget.fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: field.options != null
                      ? DropdownButtonFormField<String>(
                          initialValue: values[field.id],
                          isExpanded: true,
                          decoration: InputDecoration(labelText: field.label),
                          items: field.options!
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => values[field.id] = value!,
                        )
                      : TextFormField(
                          initialValue: values[field.id],
                          minLines: field.lines,
                          maxLines: field.lines,
                          maxLength: field.lines > 1 ? 1000 : 120,
                          decoration: InputDecoration(
                            labelText: field.label,
                            alignLabelWithHint: field.lines > 1,
                          ),
                          onChanged: (value) => values[field.id] = value.trim(),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Ce champ est obligatoire.'
                              : field.validate?.call(value!.trim()),
                        ),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
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
          if (!form.currentState!.validate()) return;
          final failure = widget.onSave(values);
          if (failure != null) {
            setState(() => error = failure);
          } else {
            Navigator.pop(context);
          }
        },
        child: Text(widget.submit),
      ),
    ],
  );
}

class DecisionDialog extends StatelessWidget {
  const DecisionDialog({super.key, required this.store, required this.request});
  final DemoStore store;
  final AcademicRequest request;
  @override
  Widget build(BuildContext context) => EditorDialog(
    title: 'Examiner ${request.id}',
    submit: 'Enregistrer la décision',
    note: 'Une décision ne modifie pas automatiquement la note. Toute correction doit être saisie et revalidée dans le registre.',
    fields: [
      const EditorField(
        'decision',
        'Décision',
        options: ['Accepter', 'Rejeter'],
      ),
      EditorField(
        'reason',
        'Réponse motivée à l’étudiant',
        lines: 4,
        validate: (v) =>
            v.length < 10 ? 'Rédigez au moins 10 caractères.' : null,
      ),
    ],
    onSave: (values) {
      store.decide(
        request,
        values['decision'] == 'Accepter',
        values['reason']!,
      );
      return null;
    },
  );
}

class AccountDialog extends StatelessWidget {
  const AccountDialog({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => EditorDialog(
    title: 'Ajouter un compte',
    note: 'Fiche locale de démonstration, sans création d’accès serveur.',
    fields: [
      const EditorField('name', 'Nom complet'),
      EditorField(
        'email',
        'Adresse e-mail',
        validate: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
            ? null
            : 'Saisissez une adresse e-mail valide.',
      ),
      EditorField(
        'role',
        'Rôle',
        options: UserRole.values.map((r) => r.label).toList(),
      ),
    ],
    onSave: (values) {
      if (store.accounts.any(
        (a) => a.email.toLowerCase() == values['email']!.toLowerCase(),
      ))
        return 'Cette adresse e-mail existe déjà.';
      store.addAccount(
        DemoAccount(
          values['name']!,
          values['email']!,
          UserRole.values.firstWhere((r) => r.label == values['role']),
        ),
      );
      return null;
    },
  );
}

class ProgramDialog extends StatelessWidget {
  const ProgramDialog({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => EditorDialog(
    title: 'Ajouter un programme',
    fields: const [
      EditorField('title', 'Intitulé de la filière'),
      EditorField(
        'level',
        'Niveau',
        options: [
          'Licence 1',
          'Licence 2',
          'Licence 3',
          'Master 1',
          'Master 2',
        ],
      ),
    ],
    onSave: (values) {
      final title = '${values['title']} · ${values['level']}';
      if (store.programs.any((p) => p.toLowerCase() == title.toLowerCase()))
        return 'Ce programme existe déjà.';
      store.addProgram(title);
      return null;
    },
  );
}

class AssignmentDialog extends StatelessWidget {
  const AssignmentDialog({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) {
    final teachers = store.accounts
        .where((a) => a.role == UserRole.teacher && a.active)
        .map((a) => '${a.name} (${a.email})')
        .toList();
    if (teachers.isEmpty)
      return AlertDialog(
        title: const Text('Aucun enseignant actif'),
        content: const Text(
          'Ajoutez ou réactivez un enseignant avant de créer une affectation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      );
    return EditorDialog(
      title: 'Ajouter une affectation',
      note: 'Les espaces de démonstration conservent leur périmètre fixe. Les affectations réelles seront appliquées par le serveur.',
      fields: [
        EditorField('teacher', 'Enseignant', options: teachers),
        EditorField(
          'course',
          'Unité d’enseignement',
          options: store.courses.map((c) => '${c.code} · ${c.title}').toList(),
        ),
      ],
      onSave: (values) {
        if (store.assignments.any((a) => a.contains('→ ${values['course']}')))
          return 'Cette UE a déjà un enseignant responsable.';
        store.addAssignment('${values['teacher']} → ${values['course']}');
        return null;
      },
    );
  }
}

class ScheduleDialog extends StatefulWidget {
  const ScheduleDialog({super.key, required this.store});
  final DemoStore store;
  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  DateTime? date;
  final room = TextEditingController();
  final form = GlobalKey<FormState>();
  String? error;
  @override
  void dispose() {
    room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Préparer une évaluation'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INF 201 · Rattrapage de démonstration\nCette préparation ne vaut pas autorisation officielle.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final selected = await showDatePicker(
                  context: context,
                  initialDate: date ?? now,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year + 1, now.month, now.day),
                  helpText: 'Date de l’évaluation',
                  cancelText: 'Annuler',
                  confirmText: 'Choisir',
                );
                if (selected != null && mounted)
                  setState(() => date = selected);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                date == null
                    ? 'Choisir une date'
                    : '${date!.day}/${date!.month}/${date!.year}',
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: room,
              decoration: const InputDecoration(labelText: 'Salle / lieu'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Indiquez une salle.' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
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
          if (!form.currentState!.validate()) return;
          if (date == null) {
            setState(() => error = 'Choisissez une date.');
            return;
          }
          widget.store.addSession(
            'INF 201 · ${date!.day}/${date!.month}/${date!.year} · ${room.text.trim()}',
          );
          Navigator.pop(context);
        },
        child: const Text('Enregistrer la préparation'),
      ),
    ],
  );
}
