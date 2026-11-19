import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

double? _number(Object? value) => double.tryParse('$value');
String _decimal(Object? value) =>
    _number(value)?.toStringAsFixed(2).replaceAll('.', ',') ?? '—';
String _date(Object? value) {
  final text = value?.toString() ?? '';
  final parts = RegExp(r'^(\d{4})-(\d\d)-(\d\d)').firstMatch(text);
  return parts == null ? text : '${parts[3]}/${parts[2]}/${parts[1]}';
}

String _decision(Map unit) {
  if (unit['en_attente'] == true || unit['statut'] == 'INSCRIPTION_REQUISE')
    return 'EN ATTENTE';
  if (unit['el'] == true || unit['grade'] == 'EL') return 'EL';
  final n = _number(unit['arrondi']);
  return n == null
      ? '—'
      : n >= 50
      ? 'CA'
      : n >= 35
      ? 'CANT'
      : 'NC';
}

pw.Widget _text(
  String value,
  double size, {
  bool bold = false,
  bool center = false,
}) => pw.Text(
  value,
  textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
  style: pw.TextStyle(
    fontSize: size,
    fontWeight: bold ? pw.FontWeight.bold : null,
  ),
);

pw.Widget _identity(String fr, String en, Object? value) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 9),
        children: [
          pw.TextSpan(
            text: '$fr :   ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value?.toString() ?? ''),
        ],
      ),
    ),
    _text(en, 7),
    pw.SizedBox(height: 3),
  ],
);

void addTranscript(
  pw.Document doc,
  Map bulletin,
  Map structure,
  Map profile,
  String period,
  String academicYear,
  bool official,
  pw.MemoryImage? crest,
) {
  final content = bulletin['contenu'] as Map? ?? {};
  final units = (content['ues'] as List? ?? []).whereType<Map>().toList()
    ..sort(
      (a, b) => "${a['code_ue'] ?? a['code']}".compareTo(
        "${b['code_ue'] ?? b['code']}",
      ),
    );
  final p = bulletin['periode'] ?? period;
  final key = p == 'S1'
      ? 'mgp_s1'
      : p == 'S2'
      ? 'mgp_s2'
      : 'mgp_total';
  final mgp = bulletin[key] ?? content[key];
  final credits = _number(
    content['total_credits'] ??
        bulletin['total_credits'] ??
        bulletin['credits'],
  );
  final acquired = units
      .where((u) => {'CA', 'CANT'}.contains(_decision(u)))
      .fold<double>(0, (n, u) => n + (_number(u['credit']) ?? 0));
  final id = bulletin['matricule'] ?? profile['matricule'] ?? '—';
  final status = official
      ? 'Publié · V${bulletin['version'] ?? bulletin['version_bulletin'] ?? '—'}'
      : 'Aperçu de travail';
  final published = _date(bulletin['publie_le']);
  final ref = bulletin['reference_officielle'] ?? '—';
  final university = structure['universite'] ?? 'UNIVERSITÉ DE YAOUNDÉ I';
  final uy1 = university.toString().toUpperCase().contains('YAOUND');
  final faculty = structure['faculte'] ?? 'FACULTÉ DES SCIENCES';
  final decision =
      bulletin['decision'] ??
      content['decision_admission'] ??
      bulletin['decision_admission'];
  final frDecision = decision == 'NON_APPLICABLE'
      ? 'Non applicable au semestre'
      : decision ?? '—';
  String examYear(Map u) {
    final y =
        u['annee_obtention'] ??
        (u['source_bulletin_id'] == null ? academicYear : null);
    return y == null ? '—' : y.toString().split(RegExp('[-/]')).last;
  }

  pw.Widget headSide(String country, String motto, String name) => pw.Column(
    children: [
      _text(country, 9, bold: true, center: true),
      _text(motto, 7, center: true),
      _text('——————', 7),
      _text(name, 9, bold: true, center: true),
    ],
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 16, 40, 24),
      maxPages: units.length + 4,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _text('$status · $p · $id', 7),
          _text('N° $ref', 7),
          _text('${ctx.pageNumber}/${ctx.pagesCount}', 7),
        ],
      ),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: headSide(
                'RÉPUBLIQUE DU CAMEROUN',
                'Paix - Travail - Patrie',
                university.toString().toUpperCase(),
              ),
            ),
            pw.SizedBox(
              height: 60,
              width: 60,
              child: crest == null
                  ? null
                  : pw.Image(crest, fit: pw.BoxFit.contain),
            ),
            pw.Expanded(
              child: headSide(
                'REPUBLIC OF CAMEROON',
                'Peace - Work - Fatherland',
                uy1 ? 'UNIVERSITY OF YAOUNDE I' : university.toString(),
              ),
            ),
          ],
        ),
        pw.Center(
          child: _text(faculty.toString().toUpperCase(), 14, bold: true),
        ),
        if (uy1 && faculty.toString().toUpperCase().contains('SCIENCE'))
          pw.Center(
            child: _text(
              'BP/P.O.Box 812 Yaoundé-CAMEROUN / Tel:222 234 496 / Email: diplome@facsciences.uy1.cm',
              8,
            ),
          ),
        pw.Center(child: _text('RELEVÉ DE NOTES/TRANSCRIPT', 19, bold: true)),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _text('N° $ref', 8, bold: true),
        ),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: _identity(
                'Noms et Prénoms',
                'Surname and Name',
                [
                  bulletin['nom'],
                  bulletin['prenom'],
                ].whereType<String>().join(' ').toUpperCase(),
              ),
            ),
            pw.Expanded(child: _identity('Matricule', 'Registration N°', id)),
          ],
        ),
        pw.Row(
          children: [
            pw.Expanded(
              child: _identity(
                'Né(e) le',
                'Born on',
                _date(bulletin['date_naissance'] ?? profile['date_naissance']),
              ),
            ),
            pw.Expanded(
              child: _identity(
                'À',
                'At',
                bulletin['lieu_naissance'] ?? profile['lieu_naissance'],
              ),
            ),
          ],
        ),
        _identity('Domaine', 'Domain', structure['domaine']),
        pw.Row(
          children: [
            pw.Expanded(
              child: _identity('Niveau', 'Level', structure['niveau']),
            ),
            pw.Expanded(
              flex: 2,
              child: _identity('Filière', 'Discipline', structure['filiere']),
            ),
          ],
        ),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: _identity('Spécialité', 'Option', structure['specialite']),
            ),
            pw.Expanded(
              child: _identity(
                'Année académique',
                'Academic Year',
                academicYear,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Code UE',
            "Intitulé de l’UE/UE Title",
            'Crédit\nCredit',
            'Moy\n/100',
            'Mention\nGrade',
            'Semestre\nSemester',
            'Année\nYear',
            'Décision\nDecision',
          ],
          data: [
            for (final u in units)
              [
                "${u['code_ue'] ?? u['code'] ?? ''}",
                "${u['intitule_ue'] ?? u['intitule'] ?? ''}".toUpperCase(),
                "${u['credit'] ?? ''}",
                _decimal(u['arrondi']),
                "${u['grade'] ?? ''}",
                "${u['semestre'] ?? ''}",
                examYear(u),
                _decision(u),
              ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(40),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(33),
            3: pw.FixedColumnWidth(30),
            4: pw.FixedColumnWidth(38),
            5: pw.FixedColumnWidth(47),
            6: pw.FixedColumnWidth(30),
            7: pw.FixedColumnWidth(44),
          },
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerStyle: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
          cellAlignment: pw.Alignment.center,
          cellAlignments: {1: pw.Alignment.centerLeft},
          headerAlignments: {1: pw.Alignment.center},
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 2,
          ),
          border: pw.TableBorder.all(width: .55),
        ),
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _text(
                      'Crédits capitalisés :    ${acquired.toStringAsFixed(0)} /${credits?.toStringAsFixed(0) ?? '—'} (${credits != null && credits > 0 ? _decimal(100 * acquired / credits) : '—'} %)',
                      9,
                      bold: true,
                    ),
                    _text(
                      'Moyenne Générale Pondérée (MGP) : ${_decimal(mgp)} /4',
                      9,
                      bold: true,
                    ),
                    _text('Décision :    $frDecision', 9, bold: true),
                  ],
                ),
              ),
              _text('Légende', 7, bold: true),
              _text(
                'CA : Capitalisé\nCANT : Capitalisé non transférable\nNC : Non capitalisé',
                6,
              ),
              pw.SizedBox(height: 3),
              pw.SizedBox(width: 225, child: _legend(content)),
            ],
          ),
        ),
        pw.Inseparable(
          child: pw.Column(
            children: [
              pw.SizedBox(height: 48),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: _text('Yaoundé, le $published', 8),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _text(
                    'Le Président du Jury\nThe President of the Jury',
                    8,
                    center: true,
                  ),
                  _text(
                    'Le Chef de Département\nThe Head of Department',
                    8,
                    center: true,
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              _text(
                official
                    ? 'Exemplaire numérique · $status'
                    : 'Aperçu de travail · Non officiel',
                7,
                center: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _legend(Map content) {
  const rows = [
    ['80–100', 'A', '4,00', 'Très bien'],
    ['75–79', 'A-', '3,70', 'Bien'],
    ['70–74', 'B+', '3,30', 'Bien'],
    ['65–69', 'B', '3,00', 'Assez bien'],
    ['60–64', 'B-', '2,70', 'Assez bien'],
    ['55–59', 'C+', '2,30', 'Passable'],
    ['50–54', 'C', '2,00', 'Passable'],
    ['45–49', 'C-', '1,70', 'Capitalisé non transférable'],
    ['40–44', 'D+', '1,30', 'Capitalisé non transférable'],
    ['35–39', 'D', '1,00', 'Capitalisé non transférable'],
    ['30–34', 'E', '0,00', 'Échec'],
    ['< 30', 'F', '0,00', 'Échec'],
  ];
  final scale = {
    for (final entry in (content['bareme'] as List? ?? []).whereType<Map>())
      entry['grade']: entry['points'],
  };
  return pw.TableHelper.fromTextArray(
    headers: const ['Note/100', 'Cote', 'Qualité de points', 'Mention'],
    data: [
      for (final r in rows)
        [r[0], r[1], scale[r[1]] == null ? r[2] : _decimal(scale[r[1]]), r[3]],
    ],
    headerStyle: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 5.8),
    cellAlignment: pw.Alignment.center,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: .6),
    border: pw.TableBorder.all(width: .4),
  );
}
