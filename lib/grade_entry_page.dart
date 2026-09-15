import 'package:flutter/material.dart';

import 'grade_draft_store.dart';
import 'grade_entry_model.dart';
import 'main.dart' show GuidePage, ink, paper, pending, red, slate, valid;

class GradeEntryPage extends StatefulWidget {
  const GradeEntryPage({super.key, this.store, this.book});

  final GradeDraftStore? store;
  final GradeEntryBook? book;

  @override
  State<GradeEntryPage> createState() => _GradeEntryPageState();
}

class _GradeEntryPageState extends State<GradeEntryPage> {
  late GradeEntryBook book;
  late GradeDraftStore store;
  late String unitId;
  late String elementId;
  String? evaluationId;
  bool loading = true;
  bool saving = false;
  bool dirty = false;
  String? storageMessage;
  int revision = 0;

  GradeUnit get unit => book.units.firstWhere((u) => u.id == unitId);
  GradeElement get element => unit.elements.firstWhere((e) => e.id == elementId);
  GradeEntryStatus get status => book.status(elementId);
  bool get submitted => status == GradeEntryStatus.submitted;

  @override
  void initState() {
    super.initState();
    book = widget.book ?? GradeEntryBook.demo();
    store = widget.store ?? createGradeDraftStore();
    selectFirst();
    restore();
  }

  void selectFirst() {
    unitId = book.units.first.id;
    elementId = book.units.first.elements.first.id;
    evaluationId = null;
  }

  Future<void> restore() async {
    try {
      final saved = await store.read();
      if (!mounted) return;
      if (saved != null) {
        book = GradeEntryBook.fromDraft(saved);
        selectFirst();
        storageMessage = 'Brouillon restauré depuis ${store.locationLabel}. '
            'Vérifie les notes avant de valider à nouveau.';
      }
    } catch (_) {
      storageMessage = 'Le brouillon local n’a pas pu être restauré. '
          'Les données de démonstration sont affichées.';
    }
    if (mounted) setState(() => loading = false);
  }

  void notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> saveDraft() async {
    if (saving) return;
    final savedRevision = revision;
    final snapshot = book.encodeDraft();
    setState(() => saving = true);
    try {
      await store.write(snapshot);
      if (!mounted) return;
      setState(() {
        if (revision == savedRevision) dirty = false;
        storageMessage = 'Brouillon enregistré dans ${store.locationLabel}. '
            'Les notes restaurées devront être validées à nouveau.';
      });
      notice('Brouillon enregistré dans ${store.locationLabel}.');
    } catch (_) {
      if (mounted) notice('Enregistrement impossible. Les modifications restent dans la page.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void changeNote(String studentId, String evalId, String value) {
    setState(() {
      book.updateNote(elementId, studentId, evalId, value);
      dirty = true;
      revision++;
      storageMessage = null;
    });
  }

  void validate() {
    final issues = book.validationIssues(elementId);
    if (issues.isNotEmpty) {
      notice('Validation impossible : ${issues.join(' ')}');
      return;
    }
    setState(() => book.validateEc(elementId));
    notice('Saisie de ${element.code} vérifiée dans la démonstration. Aucune transmission effectuée.');
  }

  Future<void> simulateSubmission() async {
    if (status != GradeEntryStatus.validated) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simuler la transmission au Décanat'),
        content: Text('La saisie de ${element.code} sera marquée comme transmise '
            'dans cette démonstration. Aucun document ne sera envoyé au Décanat '
            'et aucun résultat ne sera publié.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer la simulation')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => book.submitEc(elementId));
  }

  Future<bool> confirmLeave() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Modifications non enregistrées'),
            content: const Text('Enregistre le brouillon pour retrouver ces notes plus tard.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Rester sur la page')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quitter sans enregistrer')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> leave() async {
    if (!await confirmLeave() || !mounted) return;
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.maybePop(context);
    });
  }

  Widget panel(Widget child) => Card(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) leave();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('GNU · Saisie des notes', style: TextStyle(fontFamily: 'Fraunces', color: ink)),
            actions: [
              IconButton(tooltip: 'Guide de notation', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidePage())), icon: const Icon(Icons.help_outline)),
              IconButton(tooltip: 'Tableau de bord', onPressed: leave, icon: const Icon(Icons.dashboard_outlined)),
              const SizedBox(width: 8),
            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('DÉMONSTRATION · REGISTRE DE SAISIE', style: TextStyle(fontFamily: 'monospace', color: red)),
                            const SizedBox(height: 8),
                            Text('Saisie & Vérifications des Notes', style: Theme.of(context).textTheme.headlineLarge),
                            const SizedBox(height: 8),
                            Text('${book.students.length} étudiants de démonstration · '
                                'Brouillons conservés dans ${store.locationLabel} · Transmission simulée'),
                            const SizedBox(height: 20),
                            selectors(),
                            const SizedBox(height: 16),
                            Text('Registre ${unit.code} / ${element.code} · ${element.credits} crédits EC', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(spacing: 12, runSpacing: 12, children: [
                              for (final evaluation in element.evaluations)
                                Chip(label: Text('${evaluation.code} · ${evaluation.weight} %')),
                            ]),
                            const SizedBox(height: 10),
                            const Text('Saisie sur 20, conversion sur 100. Le résultat de chaque EC est arrondi '
                                'à l’entier supérieur sur 100. La moyenne des EC, pondérée par leurs crédits, '
                                'est ensuite arrondie à l’entier supérieur pour obtenir le résultat de l’UE.'),
                            const SizedBox(height: 8),
                            const Text('Admission annuelle : chaque UE ≥ 35/100 (7/20), MGP ≥ 2/4 et aucun EL. '
                                'EL correspond à une absence au rattrapage. Une note faible de CC, TP ou SN '
                                'ne produit pas à elle seule une élimination.', style: TextStyle(color: slate)),
                          ])),
                          const SizedBox(height: 12),
                          summaryPanel(),
                          const SizedBox(height: 12),
                          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              ChoiceChip(label: const Text('Toutes les évaluations'), selected: evaluationId == null, onSelected: (_) => setState(() => evaluationId = null)),
                              for (final evaluation in element.evaluations)
                                ChoiceChip(label: Text(evaluation.code), selected: evaluationId == evaluation.id, onSelected: (_) => setState(() => evaluationId = evaluation.id)),
                            ]),
                            const SizedBox(height: 12),
                            const Text('Entre une note entre 0 et 20, ou ABS pour une absence. '
                                'Une cellule vide représente une note manquante. '
                                'Une absence en session normale reste à régulariser avant finalisation.'),
                            const SizedBox(height: 8),
                            const Text('Les résultats affichés sont des aperçus provisoires. '
                                'Le grade concerne l’UE entière ; la décision annuelle dépend du bulletin complet.', style: TextStyle(color: slate)),
                          ])),
                          gradeTable(),
                          const SizedBox(height: 12),
                          commitmentPanel(),
                          const SizedBox(height: 12),
                          panel(Wrap(spacing: 12, runSpacing: 8, children: [
                            for (final label in ['Importer Excel', 'Exporter la liste vierge', 'Exporter le bordereau'])
                              OutlinedButton.icon(
                                onPressed: () => notice('$label : simulation. Aucun fichier n’a été importé ou créé.'),
                                icon: const Icon(Icons.table_view_outlined),
                                label: Text('$label (simulation)'),
                              ),
                          ])),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );

  Widget selectors() => LayoutBuilder(builder: (context, constraints) {
        final ueSelector = DropdownButtonFormField<String>(
          key: ValueKey('unit-$unitId'),
          initialValue: unitId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Unité d’enseignement (UE)', border: OutlineInputBorder()),
          items: [for (final u in book.units) DropdownMenuItem(value: u.id, child: Text('${u.code} · ${u.title}', overflow: TextOverflow.ellipsis))],
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              unitId = id;
              elementId = unit.elements.first.id;
              evaluationId = null;
            });
          },
        );
        final ecSelector = DropdownButtonFormField<String>(
          key: ValueKey('element-$unitId-$elementId'),
          initialValue: elementId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Élément constitutif (EC)', border: OutlineInputBorder()),
          items: [for (final e in unit.elements) DropdownMenuItem(value: e.id, child: Text('${e.code} · ${e.title}', overflow: TextOverflow.ellipsis))],
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              elementId = id;
              evaluationId = null;
            });
          },
        );
        if (constraints.maxWidth < 750) return Column(children: [ueSelector, const SizedBox(height: 16), ecSelector]);
        return Row(children: [Expanded(child: ueSelector), const SizedBox(width: 16), Expanded(child: ecSelector)]);
      });

  Widget summaryPanel() {
    final summary = book.summary(elementId);
    return panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Contrôle de ${element.code}', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        metric('Notes numériques', '${summary.numeric} / ${summary.total}', ink),
        metric('Manquantes', '${summary.missing}', summary.missing > 0 ? red : valid),
        metric('Absences', '${summary.absent}', summary.absent > 0 ? pending : valid),
        metric('Saisies invalides', '${summary.invalid}', summary.invalid > 0 ? red : valid),
        metric('Résultats UE < 35/100', '${summary.belowUeThreshold}', summary.belowUeThreshold > 0 ? red : valid),
      ]),
      const SizedBox(height: 12),
      Text('Complétude numérique : ${summary.completionPercent.toStringAsFixed(1)} % · '
          'Le seuil UE est calculé seulement lorsque tous ses EC sont complets.'),
    ]));
  }

  Widget metric(String label, String value, Color color) => Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 23, color: color, fontWeight: FontWeight.bold)),
          Text(label),
        ]),
      );

  Widget gradeTable() {
    final evaluations = element.evaluations.where((e) => evaluationId == null || e.id == evaluationId).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 66,
          dataRowMinHeight: 78,
          dataRowMaxHeight: 86,
          columnSpacing: 22,
          columns: [
            const DataColumn(label: Text('ÉTUDIANT')),
            for (final e in evaluations) DataColumn(label: Text('${e.code} /20\n${e.weight} %')),
            const DataColumn(label: Text('EC BRUT\n/100')),
            const DataColumn(label: Text('EC ARRONDI\n/100')),
            const DataColumn(label: Text('UE ARRONDIE\n/100')),
            const DataColumn(label: Text('GRADE UE\nPOINTS /4')),
            const DataColumn(label: Text('CONTRÔLE PROVISOIRE')),
          ],
          rows: [
            for (final student in book.students)
              DataRow(cells: [
                DataCell(SizedBox(width: 225, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(student.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(student.matricule, style: const TextStyle(fontFamily: 'monospace', color: slate)),
                ]))),
                for (final e in evaluations) DataCell(noteField(student, e)),
                DataCell(Text(formatResult(book.ecResult(elementId, student.id).raw100))),
                DataCell(Text('${book.ecResult(elementId, student.id).score100 ?? '—'}')),
                DataCell(Text('${book.ueResult(unitId, student.id).score100 ?? '—'}')),
                DataCell(Text(gradeText(student.id))),
                DataCell(SizedBox(width: 230, child: Text(resultStatus(student.id), style: TextStyle(color: resultColor(student.id))))),
              ]),
          ],
        ),
      ),
    );
  }

  String formatResult(num? value) => value == null ? '—' : value.toStringAsFixed(2);

  String gradeText(String studentId) {
    final result = book.ueResult(unitId, studentId);
    if (result.eliminated) return 'EL · 0.00';
    if (!result.complete) return '—';
    return '${result.grade} · ${formatResult(result.points)}';
  }

  String resultStatus(String studentId) {
    if (element.evaluations.any((e) => book.note(elementId, studentId, e.id).kind == GradeNoteKind.invalid)) return 'Saisie invalide à corriger';
    if (element.evaluations.any((e) => book.note(elementId, studentId, e.id).kind == GradeNoteKind.missing)) return 'Note manquante';
    if (element.evaluations.any((e) => book.note(elementId, studentId, e.id).kind == GradeNoteKind.absent && !e.isResit)) return 'Absence à régulariser';
    final result = book.ueResult(unitId, studentId);
    if (result.eliminated) return 'EL · Absence au rattrapage';
    if (!result.complete) return 'Autre EC à compléter';
    if (result.belowAnnualThreshold) return 'UE sous le minimum annuel (35/100)';
    if (result.score100! < 50) return 'UE < 50/100 · Reprise à prévoir';
    return 'UE ≥ 50/100 · Résultat provisoire';
  }

  Color resultColor(String studentId) {
    final result = book.ueResult(unitId, studentId);
    if (result.eliminated || result.belowAnnualThreshold) return red;
    if (!result.complete || result.score100! < 50) return pending;
    return valid;
  }

  Widget noteField(GradeStudent student, GradeEvaluation evaluation) {
    final note = book.note(elementId, student.id, evaluation.id);
    return SizedBox(
      width: 125,
      child: TextFormField(
        key: ValueKey('note-$elementId-${student.id}-${evaluation.id}'),
        initialValue: book.rawNote(elementId, student.id, evaluation.id),
        enabled: !submitted,
        keyboardType: TextInputType.text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: '0–20 / ABS',
          border: const OutlineInputBorder(),
          errorText: note.kind == GradeNoteKind.invalid ? 'Note invalide' : null,
          helperText: note.kind == GradeNoteKind.absent ? 'Absence' : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        onChanged: (value) => changeNote(student.id, evaluation.id, value),
      ),
    );
  }

  Widget commitmentPanel() {
    final issues = book.validationIssues(elementId);
    final statusLabel = switch (status) {
      GradeEntryStatus.draft => 'Brouillon · À vérifier',
      GradeEntryStatus.validated => 'Saisie validée · Non transmise',
      GradeEntryStatus.submitted => 'Transmission simulée · Aucun envoi réel',
    };
    return panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Vérification & transmission de ${element.code}', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Text(statusLabel, key: const ValueKey('entry-status'), style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(dirty ? 'Modifications non enregistrées.' : storageMessage ?? 'Les données de démonstration peuvent être modifiées.'),
      if (issues.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Finalisation bloquée : ${issues.join(' ')}', style: const TextStyle(color: red))),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 10, children: [
        OutlinedButton.icon(key: const ValueKey('save-draft'), onPressed: saving ? null : saveDraft, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Enregistrement…' : 'Enregistrer le brouillon')),
        FilledButton.icon(key: const ValueKey('validate-entry'), onPressed: status == GradeEntryStatus.draft && issues.isEmpty ? validate : null, icon: const Icon(Icons.fact_check_outlined), label: const Text('Vérifier & valider l’EC')),
        FilledButton.icon(key: const ValueKey('submit-entry'), onPressed: status == GradeEntryStatus.validated ? simulateSubmission : null, icon: const Icon(Icons.send_outlined), label: const Text('Simuler la transmission au Décanat')),
        if (submitted) OutlinedButton(onPressed: () => setState(() => book.reopenEc(elementId)), child: const Text('Reprendre la saisie')),
      ]),
      const SizedBox(height: 12),
      const Text('Toute modification de note impose une nouvelle validation de l’EC. '
          'La publication officielle des résultats relève ensuite de l’agent habilité.', style: TextStyle(color: slate)),
    ]));
  }
}
