import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

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
  String registrationSemester = 'Semestre 1';
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
          headingRowColor: WidgetStatePropertyAll(palette(context, canvas)),
          headingTextStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette(context, muted),
          ),
          dataTextStyle: TextStyle(fontSize: 13, color: palette(context, navy)),
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
    final isAnnual = semester == 'Année';
    final available =
        student || isFirst || isAnnual || store.publicationVersion > 0;
    final resultCourses = store.studentResults
        .where((item) => isAnnual || item.semester == semester)
        .toList();
    final courses = resultCourses
        .where((item) => matches('${item.code} ${item.title}'))
        .toList();
    final mgp = mgpForResults(
      resultCourses.map((item) => (credits: item.credits, mark: item.mark)),
    );
    return stack([
      PageHeading(
        'Notes & bulletins',
        'Consultez uniquement les résultats publiés de votre parcours.',
        action: OutlinedButton.icon(
          onPressed: !available ? null : exportReportPdf,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Télécharger le relevé PDF'),
        ),
      ),
      const Notice(
        'Les résultats affichés sont fictifs. Le PDF téléchargé porte la mention « document de démonstration » et n’est pas un bulletin officiel.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: ['Semestre 1', 'Semestre 2', 'Année']
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
            'Les résultats du semestre 2 seront visibles après publication du registre de démonstration.',
          ),
        )
      else
        Panel(
          child: stack([
            SectionTitle(
              isAnnual
                  ? 'Synthèse annuelle'
                  : isFirst
                  ? 'Relevé du semestre 1'
                  : 'Relevé du semestre 2',
              subtitle: isAnnual
                  ? 'Licence 2 · deux semestres · données de démonstration'
                  : isFirst
                  ? 'Informatique · Licence 2 · ${resultCourses.fold<int>(0, (sum, item) => sum + item.credits)} crédits'
                  : 'Informatique · Licence 2 · ${resultCourses.fold<int>(0, (sum, item) => sum + item.credits)} crédits',
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF183B36)
                    : const Color(0xFFEAF5F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MGP pondérée',
                        style: TextStyle(color: palette(context, muted)),
                      ),
                      Text(
                        '${mgp.toStringAsFixed(2)} / 4',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  Text(
                    'Somme(crédit UE × points) ÷ somme des crédits UE · ${resultCourses.fold<int>(0, (sum, item) => sum + item.credits)} crédits pris en compte',
                  ),
                ],
              ),
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
                  'GRADE',
                  'POINTS',
                  'RÉSULTAT',
                ],
                courses.map((item) {
                  final score = item.mark;
                  final grade = gradeForMark(score);
                  return [
                    Text(item.code),
                    SizedBox(width: 230, child: Text(item.title)),
                    Text('${item.credits}'),
                    Text(
                      score.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(grade.grade),
                    Text(grade.points.toStringAsFixed(2)),
                    StatusBadge(
                      grade.result,
                      color: score >= 50
                          ? emerald
                          : score >= 35
                          ? const Color(0xFFA26917)
                          : Theme.of(context).colorScheme.error,
                    ),
                  ];
                }).toList(),
              ),
            if (courses.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Divider(),
              const SectionTitle(
                'Détail indicatif des notes par EC',
                subtitle: 'Notes fictives. Les pondérations suivent la grille académique officielle.',
              ),
              ...courses.map((item) {
                final unit = store.registrationUnits.firstWhere(
                  (candidate) => candidate.code == item.code,
                );
                final isMixed = unit.weighting.contains('TP 30%');
                final hasTpe = unit.weighting.contains('TPE 20%');
                final ccWeight = isMixed || hasTpe ? 20 : 30;
                final tpWeight = isMixed ? 30 : 0;
                final tpeWeight = hasTpe ? 20 : 0;
                final snWeight = isMixed
                    ? 50
                    : hasTpe
                    ? 60
                    : 70;
                final unitMarks = [
                  AssessmentMark(
                    code: '${item.code}-EC1',
                    title: item.title,
                    cc: item.mark * ccWeight / 500,
                    tp: item.mark * tpWeight / 500,
                    tpe: item.mark * tpeWeight / 500,
                    sn: item.mark * snWeight / 500,
                    ccWeight: ccWeight,
                    tpWeight: tpWeight,
                    tpeWeight: tpeWeight,
                    snWeight: snWeight,
                  ),
                ];
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('${item.code} · ${item.title}'),
                  subtitle: const Text('Afficher le détail de démonstration'),
                  children: unitMarks
                      .map(
                        (mark) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 16),
                          title: Text('${mark.code} · ${mark.title}'),
                          subtitle: Text(
                            'CC ${mark.cc.toStringAsFixed(1)}/20 (${mark.ccWeight} %) · ${mark.tpWeight == 0 ? 'TP absent' : 'TP ${mark.tp.toStringAsFixed(1)}/20 (${mark.tpWeight} %)'} · ${mark.tpeWeight == 0 ? 'TPE absent' : 'TPE ${mark.tpe.toStringAsFixed(1)}/20 (${mark.tpeWeight} %)'} · SN ${mark.sn.toStringAsFixed(1)}/20 (${mark.snWeight} %)',
                          ),
                          trailing: Text(
                            '${mark.total.toStringAsFixed(2)}/20',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                );
              }),
            ],
          ]),
        ),
    ]);
  }

  Future<void> exportReportPdf() async {
    final rows = store.studentResults
        .where((item) => semester == 'Année' || item.semester == semester)
        .toList();
    final score = mgpForResults(
      rows.map((item) => (credits: item.credits, mark: item.mark)),
    );
    final lines = <String>[
      'GNU - CAMPUS NUMERIQUE',
      'RELEVE DE NOTES - DOCUMENT DE DEMONSTRATION',
      'Etudiant : Alex Mouna',
      'Periode : $semester | Annee academique 2026-2027',
      'MGP : ${score.toStringAsFixed(2)} / 4',
      ' ',
      'CODE       UNITE D\'ENSEIGNEMENT                                      CREDITS NOTE GRADE POINTS',
      ...rows.map(
        (item) =>
            '${item.code.padRight(10)} ${item.title} | ${item.credits} | ${item.mark.toStringAsFixed(1)} | ${gradeForMark(item.mark).grade} | ${gradeForMark(item.mark).points.toStringAsFixed(2)}',
      ),
      ' ',
      'MGP = somme(credits UE x points) / somme des credits UE.',
      'Grille : A 4.00, A- 3.70, B+ 3.30, B 3.00, B- 2.70, C+ 2.30, C 2.00, C- 1.70, D+ 1.30, D 1.00, E/F 0.00.',
      'Ce document et les notes ci-dessus sont fictifs et sans valeur officielle.',
    ];
    final bytes = _makeSimplePdf(lines);
    final filename =
        'releve-${semester.toLowerCase().replaceAll(' ', '-')}-demo.pdf';
    try {
      if (kIsWeb) {
        // Trigger a browser download without writing to the server or external service.
        await downloadBytes(filename, bytes, 'application/pdf');
      } else {
        await FilePicker.platform.saveFile(
          fileName: filename,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
      }
    } catch (_) {
      if (mounted)
        toast(
          context,
          'Le téléchargement du PDF a échoué. Réessayez depuis le navigateur.',
        );
    }
  }

  Uint8List _makeSimplePdf(
    List<String> lines, {
    List<String> hiddenLines = const [],
  }) {
    String esc(String value) => value
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('é', 'e')
        .replaceAll('É', 'E')
        .replaceAll('è', 'e')
        .replaceAll('È', 'E')
        .replaceAll('ê', 'e')
        .replaceAll('Ê', 'E')
        .replaceAll('à', 'a')
        .replaceAll('À', 'A')
        .replaceAll('ù', 'u')
        .replaceAll('Ù', 'U')
        .replaceAll('ô', 'o')
        .replaceAll('Ô', 'O')
        .replaceAll('î', 'i')
        .replaceAll('Î', 'I')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C')
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('×', 'x')
        .replaceAll('÷', '/')
        .replaceAll('·', '-')
        .replaceAll('—', '-');
    final content = StringBuffer('BT\n/F1 10 Tf\n48 790 Td\n14 TL\n');
    for (final line in lines) {
      var remaining = line;
      while (remaining.length > 105) {
        content.writeln('(${esc(remaining.substring(0, 105))}) Tj T*');
        remaining = remaining.substring(105);
      }
      content.writeln('(${esc(remaining)}) Tj T*');
    }
    if (hiddenLines.isNotEmpty) {
      content.write('3 Tr\n');
      for (final line in hiddenLines) {
        content.writeln('(${esc(line)}) Tj T*');
      }
      content.write('0 Tr\n');
    }
    content.write('ET');
    final stream = content.toString();
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Length ${utf8.encode(stream).length} >>\nstream\n$stream\nendstream',
    ];
    final pdf = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    var length = utf8.encode(pdf.toString()).length;
    for (var i = 0; i < objects.length; i++) {
      offsets.add(length);
      final object = '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
      pdf.write(object);
      length += utf8.encode(object).length;
    }
    final xref = length;
    pdf.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    pdf.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF',
    );
    return Uint8List.fromList(utf8.encode(pdf.toString()));
  }

  Future<void> downloadBytes(
    String filename,
    Uint8List bytes,
    String mimeType,
  ) async {
    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        fileName: filename,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [filename.split('.').last],
      );
    } else {
      await FilePicker.platform.saveFile(
        fileName: filename,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [filename.split('.').last],
      );
    }
  }

  Future<void> importEnrollmentPdf() async {
    if (store.submittedEnrollmentSemesters.contains(registrationSemester)) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.single.bytes == null) return;
    final content = latin1.decode(result.files.single.bytes!);
    final offered = store.registrationUnits
        .where((unit) => unit.semester == registrationSemester)
        .toList();
    final selections = <String, bool>{};
    final pdfTextStrings = RegExp(r'\(((?:\\.|[^\\)])*)\)\s*Tj');
    String unescape(String value) => value
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
    final extractedLines = pdfTextStrings
        .allMatches(content)
        .map((match) => unescape(match.group(1)!));
    var hasMatchingSemester = false;
    for (final line in extractedLines) {
      final semesterMatch = RegExp(r'^GNU_ENROLLMENT\|(.+)$').firstMatch(line);
      if (semesterMatch != null &&
          semesterMatch.group(1) == registrationSemester) {
        hasMatchingSemester = true;
        continue;
      }
      final unitMatch = RegExp(r'^GNU_UE\|([A-Z0-9]+)\|([01])$')
          .firstMatch(line);
      if (unitMatch == null) continue;
      final code = unitMatch.group(1)!;
      if (offered.any((item) => item.code == code)) {
        selections[code] = unitMatch.group(2) == '1';
      }
    }
    if (!hasMatchingSemester || selections.isEmpty) {
      if (mounted) {
        toast(
          context,
          'Ce PDF ne contient pas une fiche GNU valide pour $registrationSemester.',
        );
      }
      return;
    }
    store.importEnrollmentSelections(registrationSemester, selections);
    final imported = offered
        .where((unit) => store.selectedCourses.contains(unit.code))
        .length;
    if (mounted)
      toast(context, '$imported UE importées pour $registrationSemester.');
  }

  Uint8List enrollmentPdf() {
    final units = store.registrationUnits
        .where((unit) => unit.semester == registrationSemester)
        .toList();
    final lines = <String>[
      'GNU - CAMPUS NUMERIQUE',
      'FICHE D\'INSCRIPTION PEDAGOGIQUE - DEMONSTRATION',
      'Etudiant : Alex Mouna | Matricule : 24I001',
      'Formation : Informatique - Licence 2',
      'Semestre : $registrationSemester',
      ' ',
      'Cochez les UE choisies dans le portail, puis soumettez vos choix.',
      'La fiche PDF conserve ces choix pour permettre leur reimportation.',
      ' ',
      'UE disponibles :',
      ...units.map((unit) {
        final selected = store.selectedCourses.contains(unit.code);
        final mark = selected ? '[X]' : '[ ]';
        return '$mark ${unit.code} | ${unit.title} | ${unit.credits} credits | ${unit.required ? 'Obligatoire' : 'Optionnelle'}';
      }),
      ' ',
      'Enseignants et ponderations : consulter les details de chaque UE dans le portail.',
      'Ponderations officielles selon le type d’UE : CC, TP, TPE et SN.',
      'Document de demonstration sans valeur officielle.',
    ];
    final hiddenLines = <String>[
      'GNU_ENROLLMENT|$registrationSemester',
      ...units.map(
        (unit) =>
            'GNU_UE|${unit.code}|${store.selectedCourses.contains(unit.code) ? 1 : 0}',
      ),
    ];
    return _makeSimplePdf(lines, hiddenLines: hiddenLines);
  }

  Widget enrollment() => stack([
    PageHeading(
      student ? 'Mon inscription pédagogique' : 'Suivi des inscriptions',
      'Licence 2 · Informatique · Choix par semestre',
    ),
    if (!student) ...[
      Panel(
        child: stack([
          const SectionTitle('Demandes à vérifier'),
          if (store.submittedEnrollmentSemesters.isEmpty)
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
              'Inscription en attente · ${store.submittedEnrollmentSemesters.join(', ')}',
            ),
            const SizedBox(height: 16),
            ...store.registrationUnits
                .where(
                  (unit) =>
                      store.submittedEnrollmentSemesters.contains(
                        unit.semester,
                      ) &&
                      store.selectedCourses.contains(unit.code),
                )
                .map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.title),
                    subtitle: Text(c.code),
                    trailing: Text('${c.credits} crédits'),
                  ),
                ),
            const SizedBox(height: 16),
            if (store.approvedEnrollmentSemesters.containsAll(
              store.submittedEnrollmentSemesters,
            ))
              const StatusBadge('Inscription vérifiée')
            else
              FilledButton(
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Vérifier cette inscription ?',
                    'Confirmer les choix pédagogiques de cet étudiant dans la démonstration.',
                  ))
                    for (final submitted
                        in store.submittedEnrollmentSemesters) {
                      store.approveEnrollment(submitted);
                    }
                },
                child: const Text('Valider l’inscription'),
              ),
          ],
        ]),
      ),
    ] else ...[
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final label in ['Semestre 1', 'Semestre 2'])
            ChoiceChip(
              label: Text(label),
              selected: registrationSemester == label,
              onSelected: (_) => setState(() => registrationSemester = label),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Notice(
        store.approvedEnrollmentSemesters.contains(registrationSemester)
            ? 'Votre inscription a été vérifiée par la cellule informatique.'
            : store.submittedEnrollmentSemesters.contains(registrationSemester)
            ? 'Vos choix ont été transmis. Ils sont en attente de vérification.'
            : 'Sélectionnez vos UE pour $registrationSemester. Vérifiez les crédits, les enseignants et les pondérations avant de soumettre.',
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => downloadBytes(
              'fiche-inscription-${registrationSemester.toLowerCase().replaceAll(' ', '-')}.pdf',
              enrollmentPdf(),
              'application/pdf',
            ),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Télécharger la fiche PDF'),
          ),
          OutlinedButton.icon(
            onPressed:
                store.submittedEnrollmentSemesters.contains(
                  registrationSemester,
                )
                ? null
                : importEnrollmentPdf,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Importer une fiche PDF GNU'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ResponsiveSplit(
        main: Panel(
          child: stack([
            SectionTitle(
              'Mes unités d’enseignement',
              subtitle:
                  '$registrationSemester · choisissez vous-même les UE à suivre. En cas de redoublement, sélectionnez uniquement celles correspondant à votre situation. Les choix restent en brouillon jusqu’à leur soumission.',
            ),
            ...store.registrationUnits
                .where((unit) => unit.semester == registrationSemester)
                .map(
                  (c) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: store.selectedCourses.contains(c.code),
                    onChanged:
                        store.submittedEnrollmentSemesters.contains(
                          registrationSemester,
                        )
                        ? null
                        : (value) =>
                              store.selectRegistrationUnit(c, value ?? false),
                    title: Text(
                      c.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${c.code} · ${c.credits} crédits · ${c.required ? 'Obligatoire dans la maquette' : 'Optionnelle'}\nEnseignant(s) : ${c.professors}\nPondération : ${c.weighting}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette(context, muted),
                      ),
                    ),
                  ),
                ),
            const Divider(),
          ]),
        ),
        aside: Panel(
          child: stack([
            const SectionTitle('Mon récapitulatif'),
            Text(
              '${store.selectedCreditsFor(registrationSemester)}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text(
              'crédits sélectionnés',
              style: TextStyle(color: palette(context, muted)),
            ),
            const SizedBox(height: 20),
            Text(
              '${store.selectedUnitsFor(registrationSemester)} unités d’enseignement',
            ),
            if (store.selectedUnitsFor(registrationSemester) == 0) ...[
              const SizedBox(height: 12),
              Text(
                'Aucune UE sélectionnée. Vous pouvez garder cette fiche en brouillon sans la transmettre.',
                style: TextStyle(color: palette(context, muted), fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    store.submittedEnrollmentSemesters.contains(
                          registrationSemester,
                        ) ||
                        store.selectedUnitsFor(registrationSemester) == 0
                    ? null
                    : () async {
                        if (await confirm(
                          context,
                          'Soumettre mes choix ?',
                          'Vous avez sélectionné ${store.selectedUnitsFor(registrationSemester)} UE pour ${store.selectedCreditsFor(registrationSemester)} crédits pour $registrationSemester. Les choix seront verrouillés pour cette période.',
                        ))
                          store.submitEnrollment(registrationSemester);
                      },
                child: Text(
                  store.submittedEnrollmentSemesters.contains(
                        registrationSemester,
                      )
                      ? 'Choix transmis'
                      : store.selectedUnitsFor(registrationSemester) == 0
                      ? 'Sélectionnez au moins une UE'
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
              (student || r.course == store.registrationUnits.first.code) &&
              (filter == 'Toutes' || r.status == filter) &&
              matches('${r.id} ${r.course} ${r.message}'),
        )
        .toList();
    return stack([
      PageHeading(
        student ? 'Mes requêtes' : 'Requêtes étudiantes',
        student
            ? 'Une demande, une réponse et un suivi transparent.'
            : 'Examinez les demandes concernant votre enseignement.',
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
                        style: TextStyle(
                          color: palette(context, muted),
                          fontSize: 12,
                        ),
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
      'INF211 · PROGRAMMATION ORIENTÉE OBJET · Licence 2',
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
          subtitle: 'Profil standard de la grille officielle : CC 30 % · SN 70 % · notes sur 20',
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
        Text(
          'Enregistrement automatique dans la session. Toute modification annule la validation et la transmission précédentes.',
          style: TextStyle(color: palette(context, muted), fontSize: 12),
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
      'Aperçu du profil théorique ou pratique : CC 30 % et session normale 70 %. Le portail connecté applique aussi les profils officiels avec TPE et pour les UE mixtes.',
    ),
    Panel(
      child: stack([
        SectionTitle(
          'INF211 · PROGRAMMATION ORIENTÉE OBJET',
          subtitle: 'Plan de démonstration · CC 30 % · SN 70 %',
        ),
        MetricGrid([
          (
            'Contrôle continu',
            '30 %',
            'Évaluation en cours de semestre',
            Icons.edit_note,
          ),
          ('Examen', '70 %', 'Session normale', Icons.description_outlined),
        ]),
      ]),
    ),
  ]);

  Widget retakes() {
    if (student) {
      final eligibleCourses = store.studentResults
          .where((item) => item.mark <= 50)
          .toList();
      return stack([
        const PageHeading(
          'Mes rattrapages',
          'Consultez les unités concernées et les informations de session publiées.',
        ),
        const Notice(
          'Selon la grille officielle, une UE notée à 50 / 100 ou moins peut être reprise à l’unique session organisée après la session normale. La date et le lieu sont communiqués par l’établissement.',
        ),
        Panel(
          child: stack([
            SectionTitle(
              'Unités à suivre',
              subtitle:
                  'Selon les résultats de démonstration des deux semestres',
            ),
            if (eligibleCourses.isEmpty)
              const EmptyState(
                'Aucun rattrapage à afficher',
                'Vos résultats publiés ne signalent aucune unité à reprendre.',
              )
            else
              ...eligibleCourses.map(
                (course) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF5E4),
                    child: Icon(Icons.event_repeat, color: Color(0xFFA26917)),
                  ),
                  title: Text('${course.code} · ${course.title}'),
                  subtitle: Text(
                    '${course.credits} crédits · Note publiée : ${course.mark.toStringAsFixed(0)}/100',
                  ),
                  trailing: const StatusBadge(
                    'À reprendre',
                    color: Color(0xFFA26917),
                  ),
                ),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.calendar_month_outlined,
                color: palette(context, muted),
              ),
              title: Text('Calendrier de session'),
              subtitle: Text(
                'Aucune date ou convocation publiée dans cette démo.',
              ),
            ),
          ]),
        ),
      ]);
    }
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
          const SectionTitle('Unités d’enseignement · Licence 2 Informatique'),
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
                    ? '${store.registrationUnits.length} UE · ${store.registrationUnits.fold<int>(0, (sum, item) => sum + item.credits)} crédits · Démonstration'
                    : 'Nouveau programme · Brouillon',
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),
          const SectionTitle('UE · Informatique Licence 2'),
          ...store.registrationUnits.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.title, style: const TextStyle(fontSize: 14)),
              subtitle: Text(c.code),
              trailing: Text('${c.credits} crédits'),
            ),
          ),
        ]),
      ),
      aside: Panel(
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
              style: TextStyle(color: palette(context, muted), fontSize: 12),
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
        'Publication locale limitée à un registre de démonstration. Le calcul officiel des bulletins, les arrondis réglementaires et le gel en base seront assurés par le serveur.',
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
              Text(
                'INF211 · Semestre 1',
                style: TextStyle(color: palette(context, muted)),
              ),
              const SizedBox(height: 20),
              Text(
                'Les modifications ultérieures du registre ne changent pas cette copie. Une nouvelle validation et publication sont nécessaires.',
                style: TextStyle(color: palette(context, muted), fontSize: 12),
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
      'Règles académiques',
      'Grille officielle des notes, pondérations et mentions.',
    ),
    Panel(
      child: stack([
        const SectionTitle(
          'Pondération officielle des évaluations',
          subtitle: 'Les notes saisies sur 20 sont calculées avec la grille de la Faculté des Sciences.',
        ),
        table(
          const ['TYPE D’UE', 'CC', 'TP', 'TPE', 'SN'],
          const [
            [
              Text('Théorique ou pratique'),
              Text('30 %'),
              Text('—'),
              Text('—'),
              Text('70 %'),
            ],
            [
              Text('Théorique ou pratique avec TPE'),
              Text('20 %'),
              Text('—'),
              Text('20 %'),
              Text('60 %'),
            ],
            [
              Text('Mixte'),
              Text('20 %'),
              Text('30 %'),
              Text('—'),
              Text('50 %'),
            ],
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Les évaluations d’un même type (par exemple plusieurs CC) sont combinées selon leur poids relatif dans ce type, puis la grille officielle est appliquée. La note finale de l’EC sur 100 correspond à la note pondérée sur 20 multipliée par 5. La note de l’UE est la moyenne des notes de ses EC pondérée par leurs crédits.',
        ),
        const SizedBox(height: 12),
        Text(
          'Les notes finales d’EC et d’UE ainsi que la MGP sont arrondies au centième. Une note d’évaluation manquante ou une absence doit être régularisée avant le calcul officiel.',
          style: TextStyle(color: palette(context, muted)),
        ),
        const SizedBox(height: 24),
        const SectionTitle(
          'Grille des grades et des mentions',
          subtitle: 'La note de l’UE est exprimée sur 100. Les points alimentent le calcul de la MGP.',
        ),
        table(
          const [
            'NOTE / 100',
            'CÔTE',
            'QUALITÉ DE POINTS',
            'MENTION',
            'RÉSULTAT',
          ],
          [
            for (var index = 0; index < gradeScale.length; index++)
              () {
                final band = gradeScale[index];
                final range = band.minimum == 80
                    ? '80 et plus'
                    : '${band.minimum},00–${(gradeScale[index - 1].minimum - 0.01).toStringAsFixed(2).replaceAll('.', ',')}';
                return [
                  Text(range),
                  Text(band.grade),
                  Text(band.points.toStringAsFixed(2)),
                  Text(band.appreciation),
                  Text(band.result),
                ];
              }(),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle('Moyenne générale pondérée'),
        const Text(
          'Pour chaque UE, les points de qualité sont multipliés par les crédits de l’UE. La MGP = somme(points × crédits) ÷ somme des crédits. Exemple du guide : 163,8 points accumulés ÷ 60 crédits = 2,73 / 4.',
        ),
        const SizedBox(height: 24),
        const SectionTitle('Validation annuelle'),
        const Text(
          'La décision annuelle est « Admis » lorsque la MGP atteint au moins 2,00 / 4 et que chaque UE fondamentale atteint au moins 35 / 100. Une UE notée à 50 / 100 ou moins peut être reprise à l’unique session de rattrapage organisée après la session normale. EL signifie « éliminé » (absence non justifiée), S « suspension » (interdiction de se présenter) et R « reprise ou redoublement ». Seul un bulletin publié est officiel.',
        ),
      ]),
    ),
  ]);

  Widget profile() => stack([
    const PageHeading(
      'Profil & notifications',
      'Vos informations personnelles et les dernières actualités académiques.',
    ),
    ResponsiveSplit(
      main: Panel(
        child: stack([
          const SectionTitle('Informations personnelles'),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: palette(context, const Color(0xFFE9F4F0)),
                child: Text(
                  'AM',
                  style: TextStyle(
                    color: palette(context, emerald),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alex Mouna',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Étudiant · 24I001'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          _profileDetail(
            context,
            Icons.school_outlined,
            'Formation',
            'Licence 2 · Informatique',
          ),
          const SizedBox(height: 14),
          _profileDetail(
            context,
            Icons.mail_outline,
            'Adresse courriel',
            'alex@example.test',
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => toast(
                context,
                'La modification sera raccordée à l’API Laravel.',
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifier le profil'),
            ),
          ),
        ]),
      ),
      aside: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Notifications récentes'),
            _notificationTile(
              context,
              icon: Icons.description_outlined,
              title: 'Résultats disponibles',
              message: 'Le relevé du semestre 1 est consultable.',
              status: 'Disponible',
            ),
            const SizedBox(height: 12),
            _notificationTile(
              context,
              icon: Icons.playlist_add_check_outlined,
              title: 'Inscription pédagogique',
              message: 'Pensez à vérifier vos UE avant de soumettre vos choix.',
              status: 'À compléter',
              attention: true,
            ),
          ],
        ),
      ),
    ),
  ]);

  Widget _profileDetail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: palette(context, muted)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ],
  );

  Widget _notificationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String status,
    bool attention = false,
  }) {
    final color = attention
        ? const Color(0xFFA26917)
        : palette(context, emerald);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette(context, canvas),
        border: Border.all(color: palette(context, stroke)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 9),
                StatusBadge(status, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
              Text('INF211 · PROGRAMMATION ORIENTÉE OBJET'),
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
