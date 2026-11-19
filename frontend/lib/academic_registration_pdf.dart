import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A4 registration form. Coordinates match the blank institutional form.
void addAcademicRegistration(
  pw.Document document,
  pw.MemoryImage form,
  Map identity,
  List<Map<String, dynamic>> selected, {
  required String status,
}) {
  String field(String key) => "${identity[key] ?? ''}".trim();
  final birth = field('date_naissance');
  final iso = RegExp(r'^(\d{4})-(\d\d)-(\d\d)').firstMatch(birth);
  final units = [...selected]
    ..sort((a, b) => "${a['code']}".compareTo("${b['code']}"));
  pw.TextStyle style(double size, {bool bold = false, bool italic = false}) =>
      pw.TextStyle(
        font: bold
            ? pw.Font.timesBold()
            : italic
            ? pw.Font.timesItalic()
            : pw.Font.times(),
        fontSize: size,
      );
  pw.Widget entry(
    double left,
    double top,
    double width,
    String text, {
    bool bold = false,
  }) => pw.Positioned(
    left: left - 28,
    top: top - 28,
    child: pw.SizedBox(
      width: width,
      height: 11,
      child: text.isEmpty ? null : pw.FittedBox(
        alignment: pw.Alignment.centerLeft,
        fit: pw.BoxFit.scaleDown,
        child: pw.Text(text, style: style(8.5, bold: bold)),
      ),
    ),
  );
  pw.Widget table(bool mandatory) {
    final rows = units
        .where((u) => (u['obligatoire'] == true) == mandatory)
        .toList();
    return pw.TableHelper.fromTextArray(
      headers: [
        'N°',
        'CODE UE',
        mandatory ? 'FONDAMENTALE' : 'OPTIONNELLE',
        'SEMESTRE',
        'CREDIT',
      ],
      data: [
        for (final (i, u) in rows.indexed)
          [
            '${i + 1}',
            "${u['code'] ?? ''}",
            "${u['intitule'] ?? ''}".toUpperCase(),
            "SEM${u['_semestre']}",
            "${u['credits'] ?? ''}",
          ],
      ],
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FixedColumnWidth(49),
        2: pw.FlexColumnWidth(),
        3: pw.FixedColumnWidth(55),
        4: pw.FixedColumnWidth(38),
      },
      headerStyle: style(8, bold: true),
      cellStyle: style(8),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {2: pw.Alignment.centerLeft},
      headerAlignment: pw.Alignment.center,
      headerAlignments: {2: pw.Alignment.center},
      cellHeight: 20,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      border: pw.TableBorder.all(color: PdfColors.grey600, width: .45),
    );
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 22),
      maxPages: units.length + 4,
      footer: (ctx) => pw.Text(
        "$status · ${field('classe')} · ${ctx.pageNumber}/${ctx.pagesCount}",
        style: style(7, italic: true),
      ),
      build: (_) => [
        pw.SizedBox(
          height: 316,
          child: pw.Stack(
            children: [
              pw.Image(form, width: 539.5, height: 316, fit: pw.BoxFit.fill),
              entry(82, 141, 355, field('filiere').toUpperCase(), bold: true),
              pw.Positioned(
                left: 0,
                top: 147,
                child: pw.SizedBox(
                  width: 415,
                  child: pw.Text(
                    'Quitus pour le paiement des droits universitaires : à valider par le service de la scolarité.',
                    textAlign: pw.TextAlign.center,
                    style: style(8.5, bold: true),
                  ),
                ),
              ),
              entry(
                115,
                209,
                322,
                "${field('nom')} ${field('prenom')}".trim().toUpperCase(),
              ),
              entry(
                115,
                234,
                132,
                iso == null ? birth : '${iso[3]}/${iso[2]}/${iso[1]}',
              ),
              entry(336, 234, 225, field('lieu_naissance')),
              entry(115, 258, 132, field('region_origine')),
              entry(336, 258, 225, field('nationalite')),
              entry(115, 283, 132, field('matricule')),
              entry(336, 283, 225, field('annee_academique')),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'Nature des enseignements / Type of courses',
            style: style(11, bold: true),
          ),
        ),
        pw.SizedBox(height: 2),
        table(true),
        table(false),
        pw.SizedBox(height: 10),
        pw.Inseparable(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (heading, fr, en, width) in [
                (
                  'Nombre total des UEs :      ${units.length}',
                  'Date et signature du responsable de la scolarité',
                  'Date and signature of the admissions officer',
                  355.0,
                ),
                (
                  'Yaoundé, le',
                  "Signature et Téléphone de l'étudiant",
                  "Student's signature and phone number",
                  182.0,
                ),
              ])
                pw.SizedBox(
                  width: width,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(heading, style: style(8.5, bold: true)),
                      pw.SizedBox(height: 14),
                      pw.Text(fr, style: style(8)),
                      pw.Text(en, style: style(7, italic: true)),
                      pw.SizedBox(height: 30),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
