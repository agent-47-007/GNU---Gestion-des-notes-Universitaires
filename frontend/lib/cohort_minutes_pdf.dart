import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'gnu_pv_template.dart';

double? _number(Object? v) => double.tryParse('$v');
String _fmt(Object? v, {bool fixed = false}) {
  final n = _number(v);
  if (n == null) return '—';
  return (fixed
          ? n.toStringAsFixed(2)
          : n.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), ''))
      .replaceAll('.', ',');
}

void addCohortMinutes(
  pw.Document document,
  pw.MemoryImage logo,
  Map<String, dynamic> data,
) {
  final students = (data['etudiants'] as List).whereType<Map>().toList()
    ..sort(
      (a, b) => "${a['nom']} ${a['prenom']} ${a['matricule']}"
          .toUpperCase()
          .compareTo(
            "${b['nom']} ${b['prenom']} ${b['matricule']}".toUpperCase(),
          ),
    );
  final structure = data['structure'] as Map? ?? {};
  final period = data['periode'];
  final annual = period == 'ANNUELLE';
  final year = data['annee_academique'].toString();
  final level = (data['code_niveau'] ?? structure['niveau'] ?? '').toString();
  final subjects = <String, Map>{};
  final counts = <String, int>{'ADMIS': 0, 'AUTORISÉ': 0, 'ÉCHEC': 0};
  final gradeRows = <Map<String, Map>>[];
  final totals = <List<String>>[];
  String unitKey(Map unit) => "${unit['ue_id'] ?? unit['code_ue']}";
  for (final s in students) {
    final content = s['contenu'] as Map;
    final units = <String, Map>{};
    var earned = 0.0;
    final threshold =
        _number((content['regles'] as Map?)?['admission_ue_min']) ?? 35;
    for (final u in (content['ues'] as List? ?? []).whereType<Map>()) {
      subjects.putIfAbsent(unitKey(u), () => u);
      units[unitKey(u)] = u;
      if (u['el'] != true && (_number(u['arrondi']) ?? -1) >= threshold)
        earned += _number(u['credit']) ?? 0;
    }
    gradeRows.add(units);
    final chosen = _number(content['total_credits'] ?? s['total_credits']);
    final raw = content['decision_admission'] ?? s['decision_admission'];
    final decision = switch (raw) {
      'ECHEC' => 'ÉCHEC',
      'AUTORISE' => 'AUTORISÉ',
      'NON_APPLICABLE' || null => '—',
      _ => raw.toString(),
    };
    if (annual) counts.update(decision, (n) => n + 1, ifAbsent: () => 1);
    final mgpKey = annual
        ? 'mgp_total'
        : 'mgp_${period.toString().toLowerCase()}';
    totals.add([
      _fmt(earned),
      _fmt(chosen),
      _fmt(
        chosen != null && chosen > 0 ? earned * 100 / chosen : null,
        fixed: true,
      ),
      _fmt(content[mgpKey] ?? s[mgpKey], fixed: true),
      decision,
    ]);
  }
  final all = subjects.keys.toList()
    ..sort((a, b) {
      final x = subjects[a]!, y = subjects[b]!;
      final semester = (_number(x['semestre']) ?? 0).compareTo(
        _number(y['semestre']) ?? 0,
      );
      return semester != 0
          ? semester
          : "${x['code_ue']}".compareTo("${y['code_ue']}");
    });
  final pages = math.max(1, (all.length / 12).ceil());
  final status = data['version'] == null
      ? 'APERÇU DE TRAVAIL'
      : 'BULLETINS PUBLIÉS · VERSION ${data['version']}';
  final printed = DateTime.now().toIso8601String().split('T').first;
  for (var group = 0; group < pages; group++) {
    final keys = all.skip(group * 12).take(12).toList();
    String cell(Map? u) {
      if (u == null) return '';
      final mark = u['el'] == true ? 'EL' : _fmt(u['arrondi'], fixed: true);
      final origin =
          u['annee_obtention'] ??
          (u['source_bulletin_id'] != null ? 'report' : year);
      final yearLabel = RegExp(r'\d{4}$').firstMatch(origin.toString())?.group(0) ?? origin.toString();
      return "$mark\nS${u['semestre'] ?? '—'}/$yearLabel";
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        maxPages: students.length + 5,
        footer: (ctx) => gnuPvFooter(
          "PV de classe · ${data['code_classe']} · $period · $year · $status · Imprimé le $printed",
          ctx,
        ),
        build: (_) => [
          gnuPvHeader(
            crest: logo,
            university: "${structure['universite'] ?? ''}",
            faculty: "${structure['faculte'] ?? ''}",
            department: "${structure['departement'] ?? ''}",
            title: 'PROCÈS-VERBAL RÉCAPITULATIF DE CLASSE',
            subtitle:
                "${data['code_classe']} · Filière : ${structure['filiere'] ?? '—'} · Spécialité : ${structure['specialite'] ?? '—'}",
            details:
                "Niveau : $level · Semestre : ${annual ? 'TOUS' : period} · Année académique : $year",
            status:
                "$status${pages > 1 ? ' · Groupe d’UE ${group + 1}/$pages' : ''}",
          ),
          pw.TableHelper.fromTextArray(
            headers: [
              'N°',
              'NOMS ET PRÉNOMS',
              'MATRICULE',
              'NIVEAU',
              for (final k in keys)
                "${subjects[k]!['code_ue']}\n${_fmt(subjects[k]!['credit'])} cr.",
              'CRÉDITS\nCAP.',
              'CRÉDITS\nCHOISIS',
              '% CAP.',
              'MGP /4',
              'DÉCISION',
            ],
            data: [
              for (var i = 0; i < students.length; i++)
                [
                  '${i + 1}',
                  "${students[i]['nom']} ${students[i]['prenom']}"
                      .toUpperCase(),
                  "${students[i]['matricule']}",
                  level,
                  for (final k in keys) cell(gradeRows[i][k]),
                  ...totals[i],
                ],
            ],
            columnWidths: {
              for (var i = 0; i < keys.length + 9; i++)
                i: pw.FlexColumnWidth(
                  i == 0
                      ? 0.55
                      : i == 1
                      ? 3.5
                      : i == 2
                      ? 1.6
                      : i == keys.length + 8
                      ? 1.35
                      : 1,
                ),
            },
            headerStyle: pw.TextStyle(
              fontSize: 6.4,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.4),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {1: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(width: .45),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 1,
              vertical: 3,
            ),
          ),
          if (group == pages - 1)
            pw.Inseparable(
              child: pw.Column(
                children: [
                  pw.SizedBox(height: 12),
                  pw.Text(annual ? 'TAUX DE RÉUSSITE' : 'EFFECTIF DU SEMESTRE'),
                  pw.SizedBox(height: 4),
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'FILIÈRE',
                      'NIVEAU',
                      'ANNÉE',
                      'SEMESTRE',
                      'EFFECTIF',
                      if (annual)
                        for (final d in counts.keys) ...[d, '% $d'],
                    ],
                    data: [
                      [
                        "${structure['filiere'] ?? ''}",
                        level,
                        year,
                        annual ? 'TOUS' : '$period',
                        '${students.length}',
                        if (annual)
                          for (final n in counts.values) ...[
                            '$n',
                            _fmt(n * 100 / students.length, fixed: true),
                          ],
                      ],
                    ],
                    cellStyle: const pw.TextStyle(fontSize: 7),
                    headerStyle: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    cellAlignment: pw.Alignment.center,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Text('Membres du jury'),
                      pw.Text('Le Président du jury'),
                    ],
                  ),
                  pw.SizedBox(height: 25),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
