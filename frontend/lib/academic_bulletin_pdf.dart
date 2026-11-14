import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'pdf_theme.dart';

Future<Uint8List> buildAcademicBulletinsPdf({
  required List<Map<String, dynamic>> bulletins,
  required Map<String, dynamic> structure,
  required String period,
  required String academicYear,
  required bool official,
  required pw.MemoryImage? crest,
  Map<String, dynamic> studentProfile = const {},
}) async {
  final document = pw.Document(theme: await gnuPdfTheme());
  final examYear = academicYear.split(RegExp('[-/]')).last;
  final university = '${structure['universite'] ?? 'UNIVERSITÉ DE YAOUNDÉ I'}';
  final faculty = '${structure['faculte'] ?? 'FACULTÉ DES SCIENCES'}';

  for (final bulletin in bulletins) {
    final content = Map<String, dynamic>.from(
      bulletin['contenu'] as Map? ?? {},
    );
    final units = (content['ues'] as List? ?? []).whereType<Map>().toList();
    final credits = (content['total_credits'] as num?)?.toDouble() ?? 0;
    final capitalizedCredits = units.fold<double>(
      0,
      (sum, unit) =>
          sum +
          (((unit['arrondi'] as num?) ?? 0) >= 35
              ? ((unit['credit'] as num?)?.toDouble() ?? 0)
              : 0),
    );
    final mgp = bulletin['mgp_total'] ??
        bulletin['mgp_s1'] ??
        bulletin['mgp_s2'] ??
        content['mgp_total'] ??
        content['mgp_s1'] ??
        content['mgp_s2'] ??
        '—';
    final name = [bulletin['nom'], bulletin['prenom']]
        .where((part) => part != null && '$part'.trim().isNotEmpty)
        .join(' ');
    final matricule = '${bulletin['matricule'] ?? studentProfile['matricule'] ?? '—'}';
    final publicationDate = '${bulletin['publie_le'] ?? ''}';
    final reference = '${bulletin['reference_officielle'] ?? ''}';
    final version = bulletin['version'] ?? bulletin['version_bulletin'];
    final bulletinPeriod = '${bulletin['periode'] ?? period}';
    final bulletinPeriodLabel = switch (bulletinPeriod) {
      'S1' => 'SEMESTRE 1 / SEMESTER 1',
      'S2' => 'SEMESTRE 2 / SEMESTER 2',
      _ => 'ANNUEL / ANNUAL',
    };
    final dateOfBirth = '${bulletin['date_naissance'] ?? studentProfile['date_naissance'] ?? ''}';
    final placeOfBirth = '${bulletin['lieu_naissance'] ?? studentProfile['lieu_naissance'] ?? ''}';
    final domain = '${structure['domaine'] ?? ''}';

    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 22, 32, 28),
        header: (_) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _headerSide(
                    'RÉPUBLIQUE DU CAMEROUN',
                    'Paix - Travail - Patrie',
                    university,
                  ),
                ),
                pw.SizedBox(
                  width: 56,
                  height: 56,
                  child: crest == null
                      ? null
                      : pw.Image(crest, fit: pw.BoxFit.contain),
                ),
                pw.Expanded(
                  child: _headerSide(
                    'REPUBLIC OF CAMEROON',
                    'Peace - Work - Fatherland',
                    'THE UNIVERSITY OF YAOUNDÉ I',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              faculty.toUpperCase(),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${structure['departement'] ?? ''}',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'RELEVÉ DE NOTES / TRANSCRIPT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              official
                  ? 'PUBLICATION OFFICIELLE${version == null ? '' : ' · VERSION $version'}'
                  : 'APERÇU DE TRAVAIL · NON OFFICIEL',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(color: pdf.PdfColors.blueGrey800, thickness: 1),
          if (reference.isNotEmpty)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Référence officielle : $reference',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'GNU · $academicYear · $matricule · $bulletinPeriod',
              style: const pw.TextStyle(fontSize: 6.5),
            ),
            pw.Text(
              '${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6.5),
            ),
          ],
        ),
        build: (_) => [
          pw.Row(
            children: [
              pw.Expanded(child: _info('Noms et prénoms / Surname and name', name)),
              pw.Expanded(child: _info('Matricule / Registration N°', matricule)),
            ],
          ),
          if (dateOfBirth.isNotEmpty || placeOfBirth.isNotEmpty)
            pw.Row(
              children: [
                pw.Expanded(child: _info('Né(e) le / Date of birth', dateOfBirth)),
                pw.Expanded(child: _info('À / Place of birth', placeOfBirth)),
              ],
            ),
          if (domain.isNotEmpty)
            _info('Domaine / Domain', domain),
          pw.Row(
            children: [
              pw.Expanded(
                child: _info(
                  'Niveau / Level',
                  '${structure['niveau'] ?? '—'}',
                ),
              ),
              pw.Expanded(
                child: _info(
                  'Filière / Discipline',
                  '${structure['filiere'] ?? '—'}',
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: _info(
                  'Spécialité / Option',
                  '${structure['specialite'] ?? '—'}',
                ),
              ),
              pw.Expanded(
                child: _info('Année académique / Academic year', academicYear),
              ),
            ],
          ),
          _info('Période / Period', bulletinPeriodLabel),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Code UE',
              'Intitulé de l’UE / UE title',
              'Crédits',
              'Moy /100',
              'Mention',
              'Sem.',
              'Année',
              'Décision',
            ],
            data: [
              for (final unit in units)
                [
                  '${unit['code_ue'] ?? unit['code'] ?? ''}',
                  '${unit['intitule_ue'] ?? unit['intitule'] ?? ''}',
                  '${unit['credit'] ?? 0}',
                  unit['arrondi'] == null
                      ? '—'
                      : (unit['arrondi'] as num).toStringAsFixed(2),
                  '${unit['grade'] ?? '—'}',
                  '${unit['semestre'] ?? ''}',
                  examYear,
                  _unitDecision(unit),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 6.2,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.2),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {1: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(
              color: pdf.PdfColors.blueGrey800,
              width: .45,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: pdf.PdfColor(.86, .91, .89),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 3,
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(45),
              1: const pw.FlexColumnWidth(3.4),
              2: const pw.FixedColumnWidth(30),
              3: const pw.FixedColumnWidth(42),
              4: const pw.FixedColumnWidth(36),
              5: const pw.FixedColumnWidth(26),
              6: const pw.FixedColumnWidth(34),
              7: const pw.FixedColumnWidth(38),
            },
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Crédits capitalisés : ${capitalizedCredits.toStringAsFixed(0)} / ${credits.toStringAsFixed(0)} (${credits == 0 ? '0' : (capitalizedCredits / credits * 100).toStringAsFixed(2)} %)',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Moyenne Générale Pondérée (MGP) : $mgp / 4',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Décision : ${bulletin['decision'] ?? content['decision_admission'] ?? '—'}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 7),
          pw.Text(
            'Légende / Legend',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Note /100', 'Code', 'Points de qualité', 'Mention'],
            data: const [
              ['80-100', 'A', '4.00', 'Très bien / Excellent'],
              ['75-79', 'A-', '3.70', 'Très bien / Very good'],
              ['70-74', 'B+', '3.30', 'Bien / Good'],
              ['65-69', 'B', '3.00', 'Bien / Good'],
              ['60-64', 'B-', '2.70', 'Assez bien / Fairly good'],
              ['55-59', 'C+', '2.30', 'Passable / Satisfactory'],
              ['50-54', 'C', '2.00', 'Passable / Satisfactory'],
              ['45-49', 'C-', '1.70', 'Capitalisé non transférable'],
              ['40-44', 'D+', '1.30', 'Capitalisé non transférable'],
              ['35-39', 'D', '1.00', 'Capitalisé non transférable'],
              ['30-34', 'E', '0.00', 'Échec / Fail'],
              ['< 30', 'F', '0.00', 'Échec / Fail'],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 5.8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 5.8),
            border: pw.TableBorder.all(
              color: pdf.PdfColors.blueGrey800,
              width: .35,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: pdf.PdfColor(.86, .91, .89),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 2,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: _signature('Le Président du Jury / President of the Jury'),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: _signature('Le Chef de Département / Head of Department'),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _signature('Cachet officiel / Official stamp')),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text(
              official
                  ? 'Original GNU · Publié le $publicationDate · Copie à certifier par les autorités compétentes.'
                  : 'Aperçu GNU · Non officiel · Les signatures et le cachet seront apposés après validation.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 6.5),
            ),
          ),
        ],
      ),
    );
  }

  return document.save();
}

String _unitDecision(Map unit) {
  final score = unit['arrondi'];
  if (unit['en_attente'] == true || unit['statut'] == 'INSCRIPTION_REQUISE') {
    return 'EN ATTENTE';
  }
  if (unit['el'] == true || unit['grade'] == 'EL') return 'EL';
  if (score is! num) return '—';
  if (score >= 50) return 'CA';
  if (score >= 35) return 'CANT';
  return 'NC';
}

pw.Widget _headerSide(String title, String motto, String university) => pw.Column(
  children: [
    pw.Text(
      title,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
    ),
    pw.Text(motto, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6)),
    pw.SizedBox(height: 4),
    pw.Text(
      university,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
  ],
);

pw.Widget _info(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.fromLTRB(2, 3, 5, 3),
  child: pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label : ',
          style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 7.2)),
      ],
    ),
  ),
);

pw.Widget _signature(String label) => pw.Column(
  children: [
    pw.SizedBox(height: 20),
    pw.Container(height: .7, color: pdf.PdfColors.black),
    pw.SizedBox(height: 4),
    pw.Text(label, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.2)),
    pw.SizedBox(height: 30),
  ],
);
