import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'api_client.dart';
import 'file_download.dart';
import 'ui.dart';

class LiveStudentPage extends StatefulWidget {
  const LiveStudentPage({
    super.key,
    required this.page,
    required this.api,
    this.onNavigate,
  });
  final String page;
  final StudentApiClient api;
  final ValueChanged<String>? onNavigate;

  @override
  State<LiveStudentPage> createState() => LiveStudentPageState();
}

class LiveStudentPageState extends State<LiveStudentPage> {
  int semester = 1;
  String period = 'S1';
  late Future<Map<String, dynamic>> enrollmentFuture;
  late Future<List<Map<String, dynamic>>> resultsFuture;
  late Future<Map<String, dynamic>> provisionalResultsFuture;
  late Future<List<Map<String, dynamic>>> requestsFuture;
  late Future<List<Map<String, dynamic>>> retakesFuture;
  late Future<List<Map<String, dynamic>>> notificationsFuture;
  late Future<Map<String, dynamic>> profileFuture;
  late Future<Map<String, dynamic>> academicSheetFuture;
  bool saving = false;
  final Map<int, Set<String>> _enrollmentSelections = {};
  final Set<int> _markingNotificationIds = {};
  final Set<String> _retakeApplicationsInProgress = {};
  List<int> _availableEnrollmentSemesters = [1, 2];
  bool annualEnrollment = false;
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    enrollmentFuture = widget.api.enrollment(semester);
    resultsFuture = widget.api.results(period: period);
    provisionalResultsFuture = widget.api.provisionalResults(period: period);
    requestsFuture = widget.api.requests();
    retakesFuture = widget.api.retakes();
    notificationsFuture = widget.api.notifications();
    profileFuture = widget.api.getProfile();
    academicSheetFuture = widget.api.studentAcademicSheet();
  }

  @override
  void dispose() {
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _refresh() => setState(_reload);

  void refresh() => _refresh();

  @override
  Widget build(BuildContext context) => switch (widget.page) {
    'profile' => _profile(),
    'enrollment' => _enrollment(),
    'results' => _results(),
    'requests' => _requests(),
    'retakes' => _retakes(),
    _ => _home(),
  };

  Widget _home() => FutureBuilder<List<Object>>(
    future: Future.wait<Object>([
      widget.api.results(),
      widget.api.enrollment(1),
      widget.api.notifications(),
    ]),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _error(snapshot.error!);
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final results = snapshot.data![0] as List<Map<String, dynamic>>;
      final enrollment = snapshot.data![1] as Map<String, dynamic>;
      final notices = snapshot.data![2] as List<Map<String, dynamic>>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            'Vue d’ensemble',
            'Votre parcours académique connecté.',
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _metric(
                'Résultats publiés',
                '${results.length}',
                Icons.grade_outlined,
                onTap: () => _go('results'),
              ),
              _metric(
                'UE du semestre',
                '${(enrollment['unites'] as List? ?? []).length}',
                Icons.menu_book_outlined,
                onTap: () => _go('enrollment'),
              ),
              _metric(
                'Notifications non lues',
                '${notices.where((item) => item['lue'] != true).length}',
                Icons.notifications_none,
                onTap: () => _go('profile'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Notice(
            'Les données ci-dessous proviennent de votre compte étudiant et du registre académique.',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Accès rapides'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _go('enrollment'),
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Mon inscription'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _go('results'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Mes résultats'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _go('requests'),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Mes requêtes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  void _go(String page) {
    widget.onNavigate?.call(page);
  }

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) => SizedBox(
    width: 225,
    child: Panel(
      padding: 18,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(icon, color: palette(context, emerald)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        'Profil & notifications',
        'Vos informations personnelles et les actualités de votre dossier.',
      ),
      FutureBuilder<Map<String, dynamic>>(
        future: profileFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final user = snapshot.data!;
          final profil = user['profil'] is Map
              ? Map<String, dynamic>.from(user['profil'])
              : <String, dynamic>{};
          final name = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
          final currentEmail = user['courriel']?.toString() ?? '';
          if (emailController.text != currentEmail)
            emailController.text = currentEmail;
          if (firstNameController.text != (user['prenom']?.toString() ?? '')) {
            firstNameController.text = user['prenom']?.toString() ?? '';
          }
          if (lastNameController.text != (user['nom']?.toString() ?? '')) {
            lastNameController.text = user['nom']?.toString() ?? '';
          }
          return Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Informations personnelles'),
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: palette(
                        context,
                        const Color(0xFFE9F4F0),
                      ),
                      child: Text(
                        _initials(name),
                        style: TextStyle(
                          color: palette(context, emerald),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Étudiant' : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${profil['matricule'] ?? user['login'] ?? ''} · ${user['role'] ?? 'ETUDIANT'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Adresse courriel',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'nom@exemple.com',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: saving ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Enregistrer le profil'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Identifiant : ${user['login'] ?? '—'} · Rôle : ${user['role'] ?? 'ETUDIANT'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                const SectionTitle('Sécurité du compte'),
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : _changePassword,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Changer le mot de passe'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      FutureBuilder<Map<String, dynamic>>(
        future: academicSheetFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sheet = snapshot.data!;
          final available = sheet['available'] == true;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    'Fiche académique de référence',
                    subtitle: 'PDF importé pour votre niveau et votre inscription active.',
                  ),
                  if (available)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(
                        sheet['filename']?.toString() ?? 'Fiche académique',
                      ),
                      subtitle: Text(
                        '${sheet['classe'] ?? ''} · ${sheet['annee_academique'] ?? ''}',
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            onPressed: _viewAcademicSheet,
                            tooltip: 'Visualiser la fiche',
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                          IconButton(
                            onPressed: _downloadAcademicSheet,
                            tooltip: 'Télécharger la fiche',
                            icon: const Icon(Icons.download_outlined),
                          ),
                        ],
                      ),
                    )
                  else
                    const EmptyState(
                      'Aucune fiche importée',
                      'Importez la fiche académique de référence depuis l’inscription pédagogique.',
                    ),
                  for (final item
                      in (sheet['semestres'] as List? ?? []).whereType<Map>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item['statut'] == 'VALIDEE'
                            ? Icons.verified_outlined
                            : item['statut'] == 'REFUSEE'
                            ? Icons.edit_note_outlined
                            : item['statut'] == 'SOUMISE'
                            ? Icons.hourglass_top_outlined
                            : Icons.drafts_outlined,
                      ),
                      title: Text(
                        'Semestre ${item['numero']} · ${_enrollmentStatusLabel(item['statut']?.toString())}',
                      ),
                      subtitle: item['motif'] == null
                          ? null
                          : Text('Motif de l’agent : ${item['motif']}'),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : _importAcademicSheet,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(
                        available ? 'Remplacer le PDF' : 'Importer un PDF',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 20),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
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
                    'Les publications, décisions et échéances apparaîtront ici.',
                  ),
                ...items.map((item) => _notification(item)),
              ],
            ),
          );
        },
      ),
    ],
  );

  Widget _notification(Map<String, dynamic> item) {
    final content = item['contenu'] is Map
        ? Map<String, dynamic>.from(item['contenu'])
        : <String, dynamic>{};
    final read = item['lue'] == true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette(context, canvas),
        border: Border.all(color: palette(context, stroke)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            read
                ? Icons.notifications_none
                : Icons.notifications_active_outlined,
            color: palette(context, emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content['titre']?.toString() ?? 'Notification académique',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  content['message']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  item['date']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!read)
            TextButton(
              onPressed: _markingNotificationIds.contains(item['id'])
                  ? null
                  : () => _markRead(item['id']),
              child: Text(
                _markingNotificationIds.contains(item['id'])
                    ? 'En cours…'
                    : 'Marquer comme lue',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => saving = true);
    try {
      final updated = await widget.api.updateProfile({
        'prenom': firstNameController.text.trim(),
        'nom': lastNameController.text.trim(),
        'courriel': emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
      });
      widget.api.user = updated;
      if (mounted) {
        toast(context, 'Profil enregistré.');
        setState(() => profileFuture = widget.api.getProfile());
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changePassword() async {
    final formKey = GlobalKey<FormState>();
    final current = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Form(
          key: formKey,
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
                      !RegExp(r'\d').hasMatch(text))
                    return '12 caractères minimum, avec lettres et chiffres';
                  if (text == current.text)
                    return 'Choisissez un nouveau mot de passe';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le nouveau mot de passe',
                ),
                validator: (value) => value != password.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
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
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
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
      if (mounted) toast(context, _message(error));
    } finally {
      if (mounted) setState(() => saving = false);
      current.dispose();
      password.dispose();
      confirmation.dispose();
    }
  }

  Future<void> _markRead(Object? id) async {
    if (id is! num) return;
    final notificationId = id.toInt();
    setState(() => _markingNotificationIds.add(notificationId));
    try {
      await widget.api.markNotificationRead(notificationId);
      final items = await notificationsFuture;
      final updatedItems = items.map((item) {
        if (item['id'] != notificationId) return item;
        return {...item, 'lue': true};
      }).toList();
      if (mounted) {
        setState(() => notificationsFuture = Future.value(updatedItems));
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    } finally {
      if (mounted) {
        setState(() => _markingNotificationIds.remove(notificationId));
      }
    }
  }

  Widget _enrollment() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        'Inscription pédagogique',
        'Modifiez votre fiche par semestre ou pour l’année, puis enregistrez ou soumettez vos choix.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_availableEnrollmentSemesters.length > 1)
            ChoiceChip(
              label: const Text('Par semestre'),
              selected: !annualEnrollment,
              onSelected: (_) => setState(() => annualEnrollment = false),
            ),
          if (_availableEnrollmentSemesters.length > 1)
            ChoiceChip(
              label: const Text('Année complète'),
              selected: annualEnrollment,
              onSelected: (_) => setState(() => annualEnrollment = true),
            ),
          if (!annualEnrollment)
            for (final number in _availableEnrollmentSemesters)
              ChoiceChip(
                label: Text('Semestre $number'),
                selected: semester == number,
                onSelected: (_) => setState(() {
                  semester = number;
                  enrollmentFuture = widget.api.enrollment(number);
                }),
              ),
        ],
      ),
      const SizedBox(height: 16),
      if (annualEnrollment)
        ..._availableEnrollmentSemesters.map(
          (number) => _enrollmentSemester(number),
        ),
      if (!annualEnrollment) _enrollmentSemester(semester),
    ],
  );

  Widget _enrollmentSemester(int number) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: FutureBuilder<Map<String, dynamic>>(
      future: number == semester
          ? enrollmentFuture
          : widget.api.enrollment(number),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error!);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final enrollment = snapshot.data!;
        final backendSemesters =
            (enrollment['semestres_disponibles'] as List? ?? [1, 2])
                .whereType<num>()
                .map((value) => value.toInt())
                .toList();
        if (backendSemesters.isNotEmpty &&
            (backendSemesters.length != _availableEnrollmentSemesters.length ||
                !backendSemesters.toSet().containsAll(
                  _availableEnrollmentSemesters,
                ))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _availableEnrollmentSemesters = backendSemesters;
              if (!backendSemesters.contains(semester)) {
                semester = backendSemesters.first;
                enrollmentFuture = widget.api.enrollment(semester);
              }
              if (backendSemesters.length == 1) annualEnrollment = false;
            });
          });
        }
        final effectiveSemester =
            (enrollment['semestre'] as num?)?.toInt() ?? number;
        final units = (enrollment['unites'] as List? ?? [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
        final serverSelected = units
            .where((unit) => unit['selectionnee'] == true)
            .map((unit) => unit['code'].toString())
            .toSet();
        final selected =
            _enrollmentSelections[effectiveSemester] ?? serverSelected;
        final editable = enrollment['peut_modifier'] == true;
        final expectedCount =
            (enrollment['nombre_ue_attendu'] as num?)?.toInt() ?? 6;
        final availableCount =
            (enrollment['nombre_ue_disponible'] as num?)?.toInt() ??
            units.length;
        final redoubling = enrollment['redoublant'] == true;
        final repeatableCount =
            (enrollment['nombre_ue_reprise_disponible'] as num?)?.toInt() ??
            expectedCount;
        final selectionComplete = redoubling
            ? selected.isNotEmpty
            : expectedCount > 0 && selected.length == expectedCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    'Semestre $effectiveSemester · ${enrollment['statut'] ?? 'BROUILLON'}',
                    subtitle: 'Les crédits, enseignants et pondérations viennent du référentiel académique.',
                  ),
                  Notice(
                    '${enrollment['classe'] ?? 'Classe'} · ${enrollment['annee_academique'] ?? ''}${redoubling ? ' · Redoublant : choisissez uniquement les UE non acquises à reprendre. Les UE acquises sont conservées automatiquement.' : ''}',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      redoubling
                          ? 'UE à reprendre sélectionnées : ${selected.length} / $repeatableCount disponibles'
                          : 'UE sélectionnées : ${selected.length} / $expectedCount',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selectionComplete
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (!redoubling && availableCount < expectedCount)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Notice(
                        'Catalogue incomplet : $availableCount UE active(s) disponible(s), $expectedCount requises. L’agent du département doit compléter le catalogue avant votre soumission.',
                      ),
                    ),
                  if (redoubling && repeatableCount == 0)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Notice(
                        'Aucune UE non acquise ne peut être reprise à partir du bulletin précédent. Vérifiez le dossier auprès de la cellule informatique.',
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'État de la fiche · ${_enrollmentStatusLabel(enrollment['statut']?.toString())}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (enrollment['date_soumission'] != null)
                          Text('Soumise le ${enrollment['date_soumission']}'),
                        if (enrollment['motif_decision'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Motif de l’agent : ${enrollment['motif_decision']}',
                          ),
                        ],
                        if (enrollment['fiche_disponible'] == true) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _viewAcademicSheet,
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text('Visualiser la fiche'),
                              ),
                              TextButton.icon(
                                onPressed: _downloadAcademicSheet,
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('Télécharger'),
                              ),
                            ],
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Aucun PDF disponible. Importez votre fiche ou générez-la avec « Télécharger PDF ».',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (units.isEmpty)
                    const EmptyState(
                      'Aucune UE disponible',
                      'Aucune unité active n’est configurée pour ce semestre.',
                    ),
                  ...units.map((unit) {
                    final code = unit['code'].toString();
                    if (redoubling && unit['conservee'] == true) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.verified_outlined),
                        title: Text('$code · ${unit['intitule'] ?? ''}'),
                        subtitle: Text(
                          'UE acquise précédemment · ${unit['note_precedente_sur_20'] ?? '—'}/20 · conservée automatiquement',
                        ),
                        trailing: const StatusBadge(
                          'Conservée',
                          color: emerald,
                        ),
                      );
                    }
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(code),
                      onChanged:
                          !editable ||
                              (redoubling &&
                                  unit['reprise_possible'] != true) ||
                              (!selected.contains(code) &&
                                  !redoubling &&
                                  selected.length >= expectedCount)
                          ? null
                          : (value) => setState(() {
                              final next = Set<String>.from(selected);
                              value == true
                                  ? next.add(code)
                                  : next.remove(code);
                              _enrollmentSelections[effectiveSemester] = next;
                            }),
                      title: Text('$code · ${unit['intitule'] ?? ''}'),
                      subtitle: Text(
                        '${unit['credits'] ?? 0} crédits · ${unit['obligatoire'] == true ? 'Obligatoire' : 'Optionnelle'}${redoubling ? (unit['reprise_possible'] == true ? ' · À reprendre · note précédente ${unit['note_precedente_sur_20'] ?? '—'}/20' : ' · Résultat précédent indisponible') : ''}\nEnseignant(s) : ${(unit['enseignants'] as List? ?? []).join(', ').isEmpty ? 'À confirmer' : (unit['enseignants'] as List).join(', ')}\n${unit['ponderation_libelle'] ?? 'Pondération non communiquée'}',
                      ),
                      isThreeLine: true,
                    );
                  }),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _downloadEnrollmentPdf(enrollment, units, selected),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Télécharger PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: saving ? null : _importAcademicSheet,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Importer la fiche académique PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            !editable ||
                                saving ||
                                (!redoubling && !selectionComplete)
                            ? null
                            : () => _saveEnrollment(
                                effectiveSemester,
                                units,
                                submit: false,
                              ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Enregistrer le brouillon'),
                      ),
                      FilledButton.icon(
                        onPressed: !editable || saving || !selectionComplete
                            ? null
                            : () => _saveEnrollment(
                                effectiveSemester,
                                units,
                                submit: true,
                              ),
                        icon: const Icon(Icons.send_outlined),
                        label: Text(
                          enrollment['statut'] == 'SOUMISE'
                              ? 'Remplacer la soumission'
                              : 'Soumettre les choix',
                        ),
                      ),
                    ],
                  ),
                  if (!editable)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Cette inscription est validée. Contactez la cellule pour demander une correction.',
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _saveEnrollment(
    int targetSemester,
    List<Map<String, dynamic>> units, {
    required bool submit,
  }) async {
    setState(() => saving = true);
    try {
      final codes =
          (_enrollmentSelections[targetSemester] ??
                  units
                      .where((unit) => unit['selectionnee'] == true)
                      .map((unit) => unit['code'].toString())
                      .toSet())
              .toList();
      await widget.api.saveEnrollment(targetSemester, codes);
      if (submit) {
        final currentSheet = await widget.api.studentAcademicSheet();
        if (currentSheet['available'] != true) {
          final saved = await widget.api.enrollment(targetSemester);
          final savedUnits = (saved['unites'] as List? ?? [])
              .whereType<Map>()
              .map((unit) => Map<String, dynamic>.from(unit))
              .toList();
          final selectedCodes = savedUnits
              .where((unit) => unit['selectionnee'] == true)
              .map((unit) => unit['code'].toString())
              .toSet();
          await _downloadEnrollmentPdf(
            saved,
            savedUnits,
            selectedCodes,
            download: false,
            submitted: true,
          );
        }
        await widget.api.submitEnrollment(targetSemester);
      }
      if (mounted) {
        setState(() {
          _enrollmentSelections.remove(targetSemester);
          if (submit) academicSheetFuture = widget.api.studentAcademicSheet();
          if (targetSemester == semester) {
            enrollmentFuture = widget.api.enrollment(targetSemester);
          }
        });
        toast(
          context,
          submit
              ? 'Inscription soumise. Vous pouvez modifier et remplacer cette soumission avant sa validation.'
              : 'Brouillon enregistré.',
        );
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _importAcademicSheet() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (!mounted || picked == null || picked.files.single.bytes == null)
        return;
      if (picked.files.single.size > 15 * 1024 * 1024) {
        toast(context, 'La fiche PDF ne doit pas dépasser 15 Mo.');
        return;
      }
      setState(() => saving = true);
      await widget.api.uploadStudentAcademicSheet(
        filename: picked.files.single.name,
        file: picked.files.single.bytes!,
      );
      if (mounted) {
        setState(() {
          academicSheetFuture = widget.api.studentAcademicSheet();
        });
        toast(
          context,
          'Fiche de référence importée et enregistrée dans votre profil. Cochez manuellement vos UE avant de télécharger votre fiche.',
        );
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _viewAcademicSheet() async {
    try {
      final bytes = await widget.api.downloadStudentAcademicSheet();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 900,
            height: 720,
            child: PdfPreview(
              build: (_) async => bytes,
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Future<void> _downloadAcademicSheet() async {
    try {
      final bytes = await widget.api.downloadStudentAcademicSheet();
      await downloadFile('fiche-inscription-academique.pdf', bytes);
      if (mounted) toast(context, 'Fiche académique téléchargée.');
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  String _enrollmentStatusLabel(String? status) => switch (status) {
    'SOUMISE' => 'En attente de validation par l’agent',
    'VALIDEE' => 'Validée par l’agent',
    'REFUSEE' => 'À corriger puis à soumettre de nouveau',
    _ => 'Brouillon',
  };

  Future<void> _downloadEnrollmentPdf(
    Map<String, dynamic> enrollment,
    List<Map<String, dynamic>> units,
    Set<String> selected, {
    bool download = true,
    bool submitted = false,
  }) async {
    final targetSemester =
        (enrollment['semestre'] as num?)?.toInt() ?? semester;
    final student = widget.api.user ?? {};
    final profile = student['profil'] as Map? ?? {};
    final chosen = units
        .where(
          (unit) =>
              selected.contains(unit['code'].toString()) ||
              unit['conservee'] == true,
        )
        .map((unit) => {...unit, '_semestre': targetSemester})
        .toList();
    final otherSemesters = _availableEnrollmentSemesters
        .where((value) => value != targetSemester)
        .toList();
    final otherSemester = otherSemesters.isEmpty ? null : otherSemesters.first;
    if (otherSemester != null) {
      final otherEnrollment = await widget.api.enrollment(otherSemester);
      final otherUnits = (otherEnrollment['unites'] as List? ?? [])
          .whereType<Map>()
          .map((unit) => Map<String, dynamic>.from(unit))
          .toList();
      final otherSelected =
          _enrollmentSelections[otherSemester] ??
          otherUnits
              .where((unit) => unit['selectionnee'] == true)
              .map((unit) => unit['code'].toString())
              .toSet();
      chosen.addAll(
        otherUnits
            .where(
              (unit) =>
                  otherSelected.contains(unit['code'].toString()) ||
                  unit['conservee'] == true,
            )
            .map((unit) => {...unit, '_semestre': otherSemester}),
      );
    }
    if (chosen.isEmpty) {
      toast(
        context,
        'Cochez au moins une UE avant de télécharger votre fiche.',
      );
      return;
    }
    final mandatory = chosen
        .where((unit) => unit['obligatoire'] == true)
        .toList();
    final optional = chosen
        .where((unit) => unit['obligatoire'] != true)
        .toList();
    final totalCredits = chosen.fold<int>(
      0,
      (sum, unit) => sum + ((unit['credits'] as num?)?.toInt() ?? 0),
    );
    final year = '${enrollment['annee_academique'] ?? ''}';
    final titleStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: pdf.PdfColor.fromHex('#1B2942'),
    );
    final labelStyle = pw.TextStyle(
      fontSize: 7,
      color: pdf.PdfColor.fromHex('#5B5F66'),
    );
    final valueStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );
    final document = pw.Document(
      title: 'Fiche académique - ${profile['matricule'] ?? ''}',
      author: 'GNU - Campus numérique',
    );
    pw.Widget field(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: labelStyle),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(top: 2, bottom: 3),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: pdf.PdfColors.grey, width: .5),
              ),
            ),
            child: pw.Text(value.isEmpty ? ' ' : value, style: valueStyle),
          ),
        ],
      ),
    );
    pw.Widget sectionTable(String title, List<Map<String, dynamic>> rows) =>
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              color: pdf.PdfColor.fromHex('#F1EEE2'),
              child: pw.Text(title, style: titleStyle),
            ),
            if (rows.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Text(
                  'Aucune UE sélectionnée dans cette catégorie.',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['N°', 'CODE UE', 'INTITULÉ', 'SEMESTRE', 'CRÉDITS'],
                data: [
                  for (var i = 0; i < rows.length; i++)
                    [
                      '${i + 1}',
                      '${rows[i]['code'] ?? ''}',
                      '${rows[i]['intitule'] ?? ''}',
                      'SEM${rows[i]['_semestre']}',
                      '${rows[i]['credits'] ?? 0}',
                    ],
                ],
                headerStyle: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerDecoration: const pw.BoxDecoration(
                  color: pdf.PdfColors.white,
                ),
                border: pw.TableBorder.all(
                  color: pdf.PdfColor.fromHex('#DEDACB'),
                  width: .45,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FixedColumnWidth(62),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FixedColumnWidth(58),
                  4: const pw.FixedColumnWidth(48),
                },
              ),
          ],
        );
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 24),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'GNU · Campus numérique  |  ${submitted ? 'Fiche soumise à validation' : 'Document préparatoire'} · Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: pdf.PdfColors.grey),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REPUBLIQUE DU CAMEROUN', style: titleStyle),
                    pw.Text(
                      'Paix - Travail - Patrie',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('PORTAIL GNU · MINESUP', style: titleStyle),
                    pw.Text(
                      'Inscription pédagogique',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text('Fiche académique', style: labelStyle),
                  ],
                ),
              ),
              pw.Container(
                width: 46,
                height: 46,
                margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(
                    color: pdf.PdfColor.fromHex('#A9762C'),
                    width: 1.5,
                  ),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text('GNU', style: titleStyle),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('REPUBLIC OF CAMEROON', style: titleStyle),
                    pw.Text(
                      'Peace - Work - Fatherland',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('STUDENT ACADEMIC RECORD', style: titleStyle),
                    pw.Text(
                      'Academic Registration',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text('MINESUP · LMD', style: labelStyle),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: pdf.PdfColor.fromHex('#8C2F2F'), thickness: 1.2),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'FICHE D’INSCRIPTION ACADÉMIQUE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'ACADEMIC REGISTRATION FORM',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    field(
                      'Filière / Discipline · Programme / Discipline',
                      '${enrollment['classe'] ?? ''}',
                    ),
                    field(
                      'Noms et prénoms · Surname and name',
                      '${student['nom'] ?? ''} ${student['prenom'] ?? ''}'
                          .trim(),
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: field('Date de naissance · Date of birth', ''),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: field(
                            'Lieu de naissance · Place of birth',
                            '',
                          ),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: field(
                            'Région d’origine · Region of origin',
                            '',
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: field('Nationalité · Nationality', ''),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: field(
                            'Matricule · Registration number',
                            '${profile['matricule'] ?? student['login'] ?? ''}',
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: field(
                            'Année académique · Academic year',
                            year,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Container(
                width: 92,
                height: 112,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdf.PdfColors.grey, width: .7),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text('PHOTO', style: labelStyle),
              ),
            ],
          ),
          pw.SizedBox(height: 7),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(7),
            color: pdf.PdfColor.fromHex('#F1EEE2'),
            child: pw.Text(
              'Inscription pédagogique · Année $year   |   ${submitted ? 'SOUMISE À VALIDATION' : enrollment['statut'] ?? 'BROUILLON'}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Nature des enseignements / Type of courses',
              style: titleStyle,
            ),
          ),
          pw.SizedBox(height: 5),
          sectionTable('UE FONDAMENTALES / CORE COURSES', mandatory),
          pw.SizedBox(height: 8),
          sectionTable('UE OPTIONNELLES / ELECTIVE COURSES', optional),
          pw.SizedBox(height: 8),
          pw.Text(
            'Nombre total des UE : ${chosen.length}                         Total des crédits : $totalCredits',
            style: titleStyle,
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Date et signature du responsable de la scolarité',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Date and signature of the admission officer',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 28),
                    pw.Container(height: .5, color: pdf.PdfColors.grey),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Signature et téléphone de l’étudiant',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Student’s signature and phone number',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 28),
                    pw.Container(height: .5, color: pdf.PdfColors.grey),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Ce document présente les choix en cours et ne constitue pas une validation de la scolarité.',
            style: const pw.TextStyle(fontSize: 7, color: pdf.PdfColors.grey),
          ),
        ],
      ),
    );
    final bytes = await document.save();
    try {
      await widget.api.uploadStudentAcademicSheet(
        filename: 'fiche-inscription-academique.pdf',
        file: bytes,
      );
      if (download) {
        await downloadFile('fiche-academique-s$targetSemester.pdf', bytes);
        if (mounted) {
          setState(() {
            academicSheetFuture = widget.api.studentAcademicSheet();
            if (targetSemester == semester) {
              enrollmentFuture = widget.api.enrollment(targetSemester);
            }
          });
          toast(context, 'Fiche académique PDF téléchargée.');
        }
      }
    } catch (error) {
      if (mounted)
        toast(
          context,
          'Enregistrement ou téléchargement impossible : ${_message(error)}',
        );
    }
  }

  Widget _results() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeading(
        'Notes & bulletins',
        'Consultez les bulletins officiels publiés pour votre inscription.',
        action: Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _printResultsPdf,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimer'),
            ),
            OutlinedButton.icon(
              onPressed: _downloadResultsPdf,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Télécharger le PDF'),
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final item in [
            ('S1', 'Semestre 1'),
            ('S2', 'Semestre 2'),
            ('ANNUELLE', 'Année'),
          ])
            ChoiceChip(
              label: Text(item.$2),
              selected: period == item.$1,
              onSelected: (_) => setState(() {
                period = item.$1;
                resultsFuture = widget.api.results(period: period);
                provisionalResultsFuture = widget.api.provisionalResults(
                  period: period,
                );
              }),
            ),
        ],
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final bulletins = snapshot.data!;
          return Column(
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: provisionalResultsFuture,
                builder: (context, provisionalSnapshot) {
                  if (provisionalSnapshot.hasError)
                    return Panel(
                      child: Text(
                        'Bulletin provisoire indisponible : ${_message(provisionalSnapshot.error!)}',
                      ),
                    );
                  if (!provisionalSnapshot.hasData)
                    return const LinearProgressIndicator();
                  final provisional = provisionalSnapshot.data!;
                  final content = provisional['contenu'];
                  final contentMap = content is Map
                      ? Map<String, dynamic>.from(content)
                      : <String, dynamic>{};
                  final rows = _resultRows(content);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionTitle(
                            'Bulletin provisoire · $period',
                            subtitle: 'Actualisé au fil des transmissions de notes · aucune valeur ne constitue une publication officielle.',
                          ),
                          Wrap(
                            spacing: 24,
                            children: [
                              Text(
                                'MGP : ${contentMap['mgp_total'] ?? contentMap['mgp_s1'] ?? contentMap['mgp_s2'] ?? '—'} / 4',
                              ),
                              Text(
                                'Décision : ${contentMap['decision_admission'] ?? 'EN COURS'}',
                              ),
                            ],
                          ),
                          if (contentMap['ues_completees'] != null ||
                              contentMap['ues_en_attente'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${contentMap['ues_completees'] ?? 0} UE complète(s) · '
                                '${contentMap['ues_en_attente'] ?? 0} en attente',
                              ),
                            ),
                          const SizedBox(height: 12),
                          ...rows.map(
                            (row) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${row['code_ue'] ?? ''} · ${row['grade'] ?? (row['el'] == true ? 'EL' : '')}',
                              ),
                              subtitle: Text(
                                '${row['credit'] ?? ''} crédits · '
                                '${row['el'] == true ? 'Éliminé' : (row['statut'] == 'INSCRIPTION_REQUISE' ? 'Inscription à confirmer' : '${row['arrondi'] ?? 'En attente de notes'} /100')}',
                              ),
                              trailing: Text('${row['points'] ?? '—'} pts'),
                            ),
                          ),
                          ...rows.map(_componentGradeDetails),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (bulletins.isEmpty)
                const Notice(
                  'Veuillez attendre la publication d’une note ou choisir un PDF disponible. Veuillez attendre la génération du tableau pour obtenir votre extrait.',
                  warning: true,
                ),
              if (bulletins.isEmpty)
                const Panel(
                  child: EmptyState(
                    'Aucun relevé PDF disponible',
                    'Le téléchargement et l’impression seront disponibles dès qu’un bulletin officiel sera publié.',
                  ),
                ),
              if (bulletins.isNotEmpty)
                ...bulletins.map((bulletin) {
                  final rows = _resultRows(bulletin['contenu']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionTitle(
                            'Bulletin ${bulletin['periode']}',
                            subtitle:
                                'Publié le ${bulletin['publie_le'] ?? ''} · ${bulletin['credits'] ?? 0} crédits',
                          ),
                          Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: [
                              Text(
                                'MGP : ${bulletin['mgp_total'] ?? bulletin['mgp_s1'] ?? '—'} / 4',
                              ),
                              Text('Décision : ${bulletin['decision'] ?? '—'}'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (rows.isEmpty)
                            SelectableText(
                              const JsonEncoder.withIndent('  ')
                                  .convert(bulletin['contenu'] ?? {}),
                            )
                          else
                            ...rows.map(
                              (row) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${row['code'] ?? row['code_ue'] ?? ''} · ${row['intitule'] ?? row['intitule_ue'] ?? row['title'] ?? ''}',
                                ),
                                subtitle: Text(
                                  '${row['credits'] ?? row['credit_ue'] ?? ''} crédits',
                                ),
                                trailing: Text(
                                  '${row['note_sur_100'] ?? row['note_finale'] ?? row['note'] ?? row['mark'] ?? ''} /100',
                                ),
                              ),
                            ),
                          ...rows.map(_componentGradeDetails),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              'Afficher le contenu figé complet',
                            ),
                            children: [
                              SelectableText(
                                const JsonEncoder.withIndent('  ')
                                    .convert(bulletin['contenu'] ?? {}),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    ],
  );

  List<Map<String, dynamic>> _resultRows(Object? snapshot) {
    if (snapshot is! Map) return [];
    for (final key in ['ues', 'resultats_ue', 'resultats', 'lignes']) {
      final value = snapshot[key];
      if (value is List)
        return value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    }
    return [];
  }

  Widget _componentGradeDetails(Map<String, dynamic> unit) {
    final components = (unit['ecs'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (components.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Notes par matière · ${unit['code_ue'] ?? unit['code'] ?? ''}',
      ),
      subtitle: const Text('CC, TP, TPE et session normale après validation'),
      children: components.map((component) {
        final sources = (component['sources'] as List? ?? [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        return ExpansionTile(
          tilePadding: const EdgeInsets.only(left: 12),
          title: Text(component['code_m']?.toString() ?? 'Matière'),
          subtitle: Text(
            component['arrondi'] == null
                ? 'Résultat en attente de validation des composantes'
                : 'Résultat matière : ${component['arrondi']} /100',
          ),
          children: sources.isEmpty
              ? const [
                  ListTile(
                    title: Text('Aucune note publiée pour cette matière.'),
                  ),
                ]
              : sources.map((source) {
                  final status = source['statut_note']?.toString();
                  final validated = status == 'VALIDEE';
                  final value = source['valeur'];
                  final weight = source['poids'];
                  final evaluationId =
                      source['evaluation_origine_id'] ??
                      source['evaluation_id'];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      validated
                          ? Icons.verified_outlined
                          : Icons.hourglass_empty,
                      color: validated ? emerald : null,
                    ),
                    title: Text(
                      '${source['type_eval'] ?? 'Évaluation $evaluationId'} · ${weight ?? '—'} %',
                    ),
                    subtitle: Text(
                      validated && value != null
                          ? '$value /20 · ${source['situation'] ?? 'Note validée'}'
                          : 'En attente de validation par la cellule',
                    ),
                    trailing: validated && value != null
                        ? Text('$value /20')
                        : const Text('—'),
                  );
                }).toList(),
        );
      }).toList(),
    );
  }

  Future<void> _downloadResultsPdf() async {
    try {
      final bytes = await _resultsPdf();
      if (bytes == null) return;
      await downloadFile('releve-$period.pdf', bytes);
      if (mounted) toast(context, 'Bulletin PDF téléchargé.');
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Future<void> _printResultsPdf() async {
    try {
      final bytes = await _resultsPdf();
      if (bytes == null) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'releve-$period.pdf',
      );
    } catch (error) {
      if (mounted)
        toast(
          context,
          'Impression impossible sur cet appareil : ${_message(error)}',
        );
    }
  }

  Future<Uint8List?> _resultsPdf() async {
    final bulletins = await widget.api.results(period: period);
    if (bulletins.isEmpty) {
      if (mounted)
        toast(
          context,
          'Veuillez attendre la publication d’une note ou la génération du tableau pour obtenir votre extrait.',
        );
      return null;
    }
    final lines = <String>[
      'GNU - RELEVE DE NOTES',
      'Etudiant : ${widget.api.user?['prenom'] ?? ''} ${widget.api.user?['nom'] ?? ''}',
      'Periode : $period',
      ' ',
    ];
    for (final bulletin in bulletins) {
      lines.add(
        'Bulletin ${bulletin['periode']} · Version ${bulletin['version']} · Publié le ${bulletin['publie_le'] ?? '—'}',
      );
      lines.add('Décision : ${bulletin['decision'] ?? '—'}');
      lines.add(
        'MGP : ${bulletin['mgp_total'] ?? bulletin['mgp_s1'] ?? '—'} / 4 | Credits : ${bulletin['credits'] ?? '—'}',
      );
      for (final row in _resultRows(bulletin['contenu'])) {
        lines.add(
          '${row['code'] ?? row['code_ue'] ?? ''} | ${row['intitule'] ?? row['intitule_ue'] ?? ''} | ${row['note_sur_100'] ?? row['note_finale'] ?? row['note'] ?? ''}',
        );
      }
      lines.add(
        'Contenu figé complet : ${jsonEncode(bulletin['contenu'] ?? {})}',
      );
      lines.add(' ');
    }
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (context) => [
          pw.Text(
            'GNU · RELEVÉ DE NOTES',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          ...lines
              .skip(1)
              .map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
        ],
      ),
    );
    return document.save();
  }

  Widget _requests() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeading(
        'Mes requêtes',
        'Déposez une demande et suivez sa décision.',
        action: FilledButton.icon(
          onPressed: _newRequest,
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle requête'),
        ),
      ),
      const Notice(
        'Vous pouvez joindre un justificatif PDF, JPG ou PNG de 5 Mo maximum. Il reste facultatif.',
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty)
            return const Panel(
              child: EmptyState(
                'Aucune requête',
                'Vos demandes déposées apparaîtront ici.',
              ),
            );
          return Panel(
            child: Column(
              children: items.map((item) {
                final correctionAutorisee =
                    item['type'] == 'NOTE_MANQUANTE' &&
                    item['statut'] == 'EN_TRAITEMENT' &&
                    item['decision'] == 'AUTORISER_EVALUATION';
                final status = correctionAutorisee
                    ? 'Correction autorisée'
                    : item['statut'] == 'DECIDEE'
                    ? (item['decision']?.toString().contains('REJET') == true
                          ? 'Rejetée'
                          : 'Acceptée')
                    : item['statut'] == 'EN_TRAITEMENT'
                    ? 'En cours'
                    : 'À examiner';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item['titre'] ?? item['type']} · ${item['code_ue']}',
                  ),
                  subtitle: Text(
                    '${item['message'] ?? ''}\n${item['soumise_le'] ?? ''}${correctionAutorisee ? '\nLa note va être complétée, puis repassera par le contrôle et la vérification.' : ''}${item['motif_decision'] == null ? '' : '\nRéponse : ${item['motif_decision']}'}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(
                        status,
                        color: status == 'Rejetée'
                            ? Colors.red
                            : status == 'À examiner'
                            ? const Color(0xFFA26917)
                            : emerald,
                      ),
                      if (item['a_justificatif'] == true)
                        IconButton(
                          tooltip: 'Télécharger le justificatif',
                          onPressed: () => _downloadProof(item['id']),
                          icon: const Icon(Icons.download_outlined),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    ],
  );

  Future<void> _newRequest() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestForm(api: widget.api),
    );
    if (created == true && mounted)
      setState(() => requestsFuture = widget.api.requests());
  }

  Future<void> _downloadProof(Object? id) async {
    if (id is! num) return;
    try {
      final bytes = await widget.api.downloadRequestProof(id.toInt());
      await FilePicker.platform.saveFile(
        fileName: 'justificatif-requete-${id.toInt()}',
        bytes: bytes,
      );
    } catch (error) {
      if (mounted) toast(context, _message(error));
    }
  }

  Widget _retakes() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        'Mes rattrapages',
        'Consultez les candidatures et les sessions enregistrées pour votre parcours.',
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: retakesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty)
            return const Panel(
              child: EmptyState(
                'Aucune UE admissible publiée',
                'Les résultats et sessions de rattrapage apparaîtront ici lorsqu’ils seront enregistrés.',
              ),
            );
          return Panel(
            child: Column(
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.event_repeat,
                        color: Color(0xFFA26917),
                      ),
                      title: Text('${item['code_ue']} · ${item['intitule']}'),
                      subtitle: Text(
                        'Note : ${item['note_sur_20'] ?? '—'}/20 · ${item['session'] ?? 'Session à programmer'} · ${item['date_session'] ?? ''}',
                      ),
                      trailing:
                          item['peut_candidater'] == true &&
                              item['session_id'] is num
                          ? TextButton.icon(
                              onPressed:
                                  _retakeApplicationsInProgress.contains(
                                    item['code_ue'].toString(),
                                  )
                                  ? null
                                  : () => _applyForRetake(item),
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text(
                                _retakeApplicationsInProgress.contains(
                                      item['code_ue'].toString(),
                                    )
                                    ? 'Inscription…'
                                    : 'Candidater',
                              ),
                            )
                          : StatusBadge(
                              _retakeStatusLabel(item),
                              color: item['statut'] == 'PROGRAMMEE'
                                  ? emerald
                                  : const Color(0xFFA26917),
                            ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    ],
  );

  String _retakeStatusLabel(Map<String, dynamic> item) => switch (item['statut']
      ?.toString()) {
    'SOUMISE' => 'Demande envoyée',
    'EN_TRAITEMENT' => 'Transmise à l’enseignant',
    'PROGRAMMEE' => 'Inscrit',
    'COMPOSEE' => 'Composée',
    'ABSENTE' => 'Absent',
    'AUTORISEE' => 'Autorisé',
    'ANNULEE' => 'Annulée',
    _ => item['statut_session'] == 'PREVUE' ? 'Session à venir' : 'Éligible',
  };

  Future<void> _applyForRetake(Map<String, dynamic> item) async {
    final code = item['code_ue']?.toString();
    final sessionId = (item['session_id'] as num?)?.toInt();
    if (code == null || sessionId == null) return;
    setState(() => _retakeApplicationsInProgress.add(code));
    try {
      await widget.api.applyForRetake(unitCode: code, sessionId: sessionId);
      final updatedRetakes = await widget.api.retakes();
      final updatedRequests = await widget.api.requests();
      if (mounted) {
        setState(() {
          retakesFuture = Future.value(updatedRetakes);
          requestsFuture = Future.value(updatedRequests);
        });
        toast(
          context,
          'Votre demande est envoyée à la cellule pour transmission à l’enseignant.',
        );
      }
    } catch (error) {
      if (mounted) toast(context, _message(error));
    } finally {
      if (mounted) {
        setState(() => _retakeApplicationsInProgress.remove(code));
      }
    }
  }

  Widget _error(Object error) => Panel(
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 10),
        Expanded(child: Text(_message(error))),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Réessayer',
        ),
      ],
    ),
  );
  String _message(Object error) => error is ApiFailure
      ? error.message
      : 'Une erreur est survenue. Vérifiez la connexion au serveur et réessayez.';
  String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({required this.api});
  final StudentApiClient api;
  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final formKey = GlobalKey<FormState>();
  final message = TextEditingController();
  String type = 'Vérification de note';
  String? code, codeM, filename, error;
  int? evaluationId;
  Uint8List? bytes;
  bool loading = false;
  late Future<List<Map<String, dynamic>>> courses;
  Future<List<Map<String, dynamic>>>? missingEvaluationFuture;

  @override
  void initState() {
    super.initState();
    courses = _loadCourses();
  }

  Future<List<Map<String, dynamic>>> _loadCourses() async {
    final semesters = await Future.wait([
      widget.api.enrollment(1),
      widget.api.enrollment(2),
    ]);
    final courses = <Map<String, dynamic>>[];
    for (final semester in semesters) {
      for (final rawUnit in semester['unites'] as List? ?? const []) {
        if (rawUnit is! Map || rawUnit['selectionnee'] != true) continue;
        for (final rawElement in rawUnit['elements'] as List? ?? const []) {
          if (rawElement is! Map) continue;
          courses.add({
            'code_ue': rawUnit['code'].toString(),
            'intitule_ue': rawUnit['intitule'].toString(),
            'code_m': rawElement['code_m'].toString(),
            'intitule_matiere': rawElement['intitule'].toString(),
          });
        }
      }
    }
    final uniqueCourses = <String, Map<String, dynamic>>{};
    for (final item in courses) {
      uniqueCourses.putIfAbsent(
        '${item['code_ue']}|${item['code_m']}',
        () => item,
      );
    }
    return uniqueCourses.values.toList();
  }

  void _loadMissingEvaluations() {
    if (code == null || codeM == null) {
      missingEvaluationFuture = null;
      return;
    }
    evaluationId = null;
    missingEvaluationFuture = widget.api.missingEvaluations(
      code: code!,
      codeM: codeM!,
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (!mounted || result == null) return;
    final picked = result.files.single;
    if (picked.bytes == null ||
        picked.size == 0 ||
        picked.size > 5 * 1024 * 1024) {
      setState(() => error = 'Choisissez un fichier non vide de 5 Mo maximum.');
      return;
    }
    setState(() {
      bytes = picked.bytes;
      filename = picked.name;
      error = null;
    });
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    if (type == 'Note manquante' && evaluationId == null) {
      setState(() => error = 'Sélectionnez l’évaluation concernée.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.createRequest(
        code: code!,
        codeM: codeM!,
        type: type,
        message: message.text.trim(),
        evaluationId: type == 'Note manquante' ? evaluationId : null,
        filename: filename,
        file: bytes,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
          () => error = exception is ApiFailure
              ? exception.message
              : 'La requête n’a pas pu être envoyée.',
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle requête'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: courses,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Text(
                      'Chargement des UE impossible : ${snapshot.error}',
                    );
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final items = snapshot.data!;
                  if (items.isEmpty)
                    return const Text(
                      'Aucun EC affecté à un enseignant dans vos UE inscrites.',
                    );
                  code ??= items.first['code_ue'] as String;
                  codeM ??= items.first['code_m'] as String;
                  if (type == 'Note manquante') {
                    missingEvaluationFuture ??= widget.api.missingEvaluations(
                      code: code!,
                      codeM: codeM!,
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: '$code|$codeM',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Élément constitutif concerné',
                    ),
                    items: items.map((item) {
                      final key = '${item['code_ue']}|${item['code_m']}';
                      return DropdownMenuItem(
                        value: key,
                        child: Text(
                          '${item['code_ue']} · ${item['code_m']} · ${item['intitule_matiere']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() {
                      final selected = items.firstWhere(
                        (item) =>
                            '${item['code_ue']}|${item['code_m']}' == value,
                      );
                      code = selected['code_ue'] as String;
                      codeM = selected['code_m'] as String;
                      if (type == 'Note manquante') {
                        _loadMissingEvaluations();
                      }
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Objet de la demande',
                ),
                items:
                    [
                          'Vérification de note',
                          'Note manquante',
                          'Absence justifiée',
                          'Autre demande',
                        ]
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setState(() {
                  type = value ?? type;
                  if (type == 'Note manquante' &&
                      missingEvaluationFuture == null) {
                    _loadMissingEvaluations();
                  }
                }),
              ),
              if (type == 'Note manquante') ...[
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: missingEvaluationFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'Chargement des évaluations impossible : ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final evaluations = snapshot.data!;
                    if (evaluations.isEmpty) {
                      return const Text(
                        'Aucune évaluation réalisée sans note n’est disponible pour cet EC.',
                      );
                    }
                    return DropdownButtonFormField<int>(
                      key: ValueKey('missing-eval-$code-$codeM'),
                      initialValue: evaluationId,
                      decoration: const InputDecoration(
                        labelText: 'Évaluation sans note',
                      ),
                      validator: (value) => value == null
                          ? 'Sélectionnez l’évaluation concernée.'
                          : null,
                      items: evaluations.map((evaluation) {
                        final id = (evaluation['id'] as num).toInt();
                        return DropdownMenuItem(
                          value: id,
                          child: Text(
                            '${evaluation['type_eval']} · ${evaluation['date_evaluation']}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => evaluationId = value),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: message,
                minLines: 3,
                maxLines: 5,
                maxLength: 1500,
                decoration: const InputDecoration(labelText: 'Votre message'),
                validator: (value) => (value?.trim().length ?? 0) < 15
                    ? '15 caractères minimum.'
                    : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(filename ?? 'Joindre un justificatif'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Facultatif · PDF, JPG ou PNG · 5 Mo maximum',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: loading ? null : _submit,
        child: Text(loading ? 'Envoi…' : 'Soumettre'),
      ),
    ],
  );
}
