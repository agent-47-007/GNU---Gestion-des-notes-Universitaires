import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

double? _number(Object? v) => double.tryParse('$v'.replaceAll(',', '.'));
String _display(num v) => v
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.00$'), '')
    .replaceAll('.', ',');

// GNU's grade_ue scale, applied to the rounded normal-session total only.
String _mention(double total) {
  const grades = ['A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'E'];
  for (var i = 0; i < grades.length; i++) {
    if (total >= 80 - 5 * i) return grades[i];
  }
  return 'F';
}

void addSessionNormale(
  pw.Document document,
  pw.MemoryImage header,
  Map<String, dynamic> ue,
  List<Map<String, dynamic>> evaluations,
  List<Map<String, dynamic>> students,
) {
  // Each EC contributes according to its credits. A shared UE plan has one group.
  final credits = <Object?, double>{};
  final weights = <Object?, double>{};
  for (final e in evaluations) {
    final ec = e['affectation_id'];
    credits[ec] = _number(e['credit_ec']) ?? 0;
    weights[ec] = (weights[ec] ?? 0) + (_number(e['poids_evaluation']) ?? 0);
  }
  if (!evaluations.any((e) => e['type_eval'] == 'SN') ||
      weights.values.any((v) => (v - 100).abs() > 0.001) ||
      credits.length > 1 && credits.values.any((v) => v <= 0)) {
    throw const FormatException(
      'Le plan doit contenir une SN et totaliser 100 % par EC, avec des crédits définis pour chaque EC.',
    );
  }
  final creditTotal = credits.values.fold(0.0, (a, b) => a + b);
  double weight(Map e) =>
      _number(e['poids_evaluation'])! *
      (credits.length == 1 ? 1 : credits[e['affectation_id']]! / creditTotal);
  final columns = [
    for (final type in ['CC', 'SN', 'TP', 'TPE'])
      if (evaluations.any((e) => e['type_eval'] == type)) type,
  ];
  String label(String t) => switch (t) {
    'SN' => 'EE',
    'TP' => 'EP',
    _ => t,
  };
  final level = "${ue['code_niveau'] ?? ue['niveau'] ?? '-'}";
  final program = "${ue['code_filiere'] ?? '-'}";
  final year = "${ue['annee_academique'] ?? '-'}";
  final semester = "${ue['numero_semestre'] ?? '-'}";
  final code = "${ue['code_ue'] ?? '-'}";
  final headers = [
    'NUM',
    'MATRICULE',
    'NOMS ET PRENOMS',
    'NIVEAU',
    for (final t in columns) ...[
      'ANO_${label(t)}',
      '${label(t)}/${_display(evaluations.where((e) => e['type_eval'] == t).fold<double>(0, (a, e) => a + weight(e)))}',
    ],
    'TOTAL/100',
    'DEC',
    'MENTION',
  ];
  final mainRows = <List<String>>[], privateRows = <List<String>>[];
  final counts = {'CA': 0, 'CANT': 0, 'NC': 0, 'EL': 0, 'EN ATTENTE': 0};
  for (final s in students) {
    final notes = {
      for (final n in (s['notes'] as List? ?? []).whereType<Map>())
        "${n['evaluation_id']}": n,
    };
    final confidential = s['hors_compte'] == true;
    final target = confidential ? privateRows : mainRows;
    final row = [
      '${target.length + 1}',
      "${s['matricule'] ?? ''}",
      "${s['nom_complet_pv'] ?? s['nom'] ?? ''}".toUpperCase(),
      '$program-$level',
    ];
    var total = 0.0, missing = false, absent = false;
    for (final t in columns) {
      var points = 0.0, incomplete = false, eliminated = false;
      for (final e in evaluations.where((e) => e['type_eval'] == t)) {
        final note = notes["${e['evaluation_id']}"];
        final mark = _number(note?['valeur_note']);
        if (note?['situation'] == 'ABSENTE') {
          eliminated = true;
        } else if (note?['situation'] != 'NUMERIQUE' ||
            mark == null ||
            mark < 0 ||
            mark > 20) {
          incomplete = true;
        } else {
          points += mark * weight(e) / 20;
        }
      }
      row.addAll([
        '',
        eliminated
            ? 'EL'
            : incomplete
            ? ''
            : _display(points),
      ]);
      total += points;
      absent |= eliminated;
      missing |= incomplete;
    }
    total = double.parse(total.toStringAsFixed(2));
    final decision = confidential
        ? ''
        : absent
        ? 'EL'
        : missing
        ? 'EN ATTENTE'
        : total >= 50
        ? 'CA'
        : total >= 35
        ? 'CANT'
        : 'NC';
    final complete = !confidential && !absent && !missing;
    row.addAll([
      complete ? _display(total) : '',
      decision,
      complete ? _mention(total) : '',
    ]);
    if (confidential) {
      row.add("${s['observation'] ?? 'Étudiant non autorisé'}");
    } else {
      counts[decision] = counts[decision]! + 1;
    }
    target.add(row);
  }

  pw.Widget table(
    List<String> h,
    List<List<String>> rows, {
    bool roster = false,
  }) => pw.TableHelper.fromTextArray(
    headers: h,
    data: rows,
    columnWidths: roster
        ? {
            for (var i = 0; i < h.length; i++)
              i: pw.FlexColumnWidth(
                i == 2
                    ? 4
                    : i == 1 || h[i] == 'OBSERVATION'
                    ? 2.1
                    : 1,
              ),
          }
        : null,
    headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 8),
    headerAlignment: pw.Alignment.centerLeft,
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    border: pw.TableBorder.all(color: PdfColors.grey500, width: .35),
  );
  final now = DateTime.now();
  for (final annex in [false, if (privateRows.isNotEmpty) true]) {
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: students.length + 5,
        margin: const pw.EdgeInsets.fromLTRB(29, 15, 29, 17),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '© UY1/CI    PV $code - $program    Imprimé le ${now.day}/${now.month}/${now.year}    Semestre $semester    Année académique : $year    Copie de travail enseignant',
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (_) => [
          pw.Center(child: pw.Image(header, height: 105)),
          for (final line in [
            if (annex) 'RAPPORT À NE PAS AFFICHER',
            "PROCES VERBAL DE L'UNITE D'ENSEIGNEMENT",
            "$code-${ue['intitule_ue'] ?? ''}".toUpperCase(),
            "FILIERE : $program - ${ue['filiere'] ?? '-'}",
            "SPECIALITE : ${ue['specialite'] ?? '-'}",
            'GRADE : $level   SEMESTRE : $semester    Année académique : $year',
          ])
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  line,
                  style: pw.TextStyle(
                    fontSize: line.contains('VERBAL') ? 14 : 10,
                  ),
                ),
              ),
            ),
          table(
            [...headers, if (annex) 'OBSERVATION'],
            annex ? privateRows : mainRows,
            roster: true,
          ),
          if (!annex)
            pw.Inseparable(
              child: pw.Column(
                children: [
                  pw.SizedBox(height: 8),
                  pw.Text('STATISTIQUES DE VALIDATION'),
                  pw.SizedBox(height: 4),
                  table(
                    [
                      'Filière',
                      'Grade',
                      'Niveau',
                      'Année',
                      'Semestre',
                      'UE',
                      'Effectif',
                      for (final d in counts.keys) ...[d, '% $d'],
                    ],
                    [
                      [
                        program,
                        level.replaceAll(RegExp(r'[0-9]'), ''),
                        level,
                        year,
                        semester,
                        code,
                        '${mainRows.length}',
                        for (final count in counts.values) ...[
                          '$count',
                          _display(
                            mainRows.isEmpty
                                ? 0
                                : count * 100 / mainRows.length,
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
