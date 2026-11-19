import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

/// Shared printable header and footer for GNU academic procès-verbaux.
pw.Widget gnuPvHeader({
  required pw.MemoryImage? crest,
  required String university,
  required String faculty,
  required String department,
  required String title,
  required String details,
  String? subtitle,
  String? status,
}) => pw.Column(
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _headerText('RÉPUBLIQUE DU CAMEROUN', bold: true),
              _headerText('Paix - Travail - Patrie'),
              _headerText(university, bold: true),
            ],
          ),
        ),
        pw.SizedBox(
          width: 46,
          height: 46,
          child: crest == null ? null : pw.Image(crest, fit: pw.BoxFit.contain),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _headerText('REPUBLIC OF CAMEROON', bold: true),
              _headerText('Peace - Work - Fatherland'),
              _headerText('THE UNIVERSITY OF YAOUNDÉ I', bold: true),
            ],
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      '$faculty · $department',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
    pw.Divider(color: pdf.PdfColors.blueGrey800, thickness: 1),
    pw.SizedBox(height: 3),
    pw.Text(
      title,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
    if (subtitle != null && subtitle.isNotEmpty)
      pw.Text(
        subtitle,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    pw.Text(
      details,
      textAlign: pw.TextAlign.center,
      style: const pw.TextStyle(fontSize: 8),
    ),
    if (status != null)
      pw.Text(
        status,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
    pw.SizedBox(height: 5),
  ],
);

pw.Widget gnuPvFooter(String label, pw.Context context) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
    pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
    pw.Text(
      '${context.pageNumber}/${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 7),
    ),
  ],
);

pw.Widget _headerText(String value, {bool bold = false}) => pw.Text(
  value,
  style: pw.TextStyle(
    fontSize: 7,
    fontWeight: bold ? pw.FontWeight.bold : null,
  ),
);

/// Each assessment starts on its own page and retains its own marks.
void addEvaluationMinutes(
  pw.Document document,
  pw.MemoryImage header,
  Map<String, dynamic> source,
  Map<String, dynamic> evaluation,
  List<Map<String, dynamic>> students, {
  required bool distinguishEvaluation,
}) {
  final type = evaluation['type_eval'].toString();
  final label = switch (type) {
    'CC' => 'CONTROLE CONTINU',
    'TP' => 'TRAVAUX PRATIQUES',
    'TPE' => 'TRAVAIL PERSONNEL DE L’ETUDIANT',
    _ => type,
  };
  final unit = source['code_ue'] ?? '-';
  final semester = source['numero_semestre'] ?? '-';
  final year = source['annee_academique'] ?? '-';
  final program = source['code_filiere'] ?? '-';
  final today = DateTime.now();
  final date =
      "${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}";
  final identifier = [
    evaluation['code_m'],
    evaluation['date_evaluation'],
    'n° ${evaluation['evaluation_id']}',
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  pw.TextStyle style(double size, {bool bold = false}) => pw.TextStyle(
    font: bold ? pw.Font.timesBold() : pw.Font.times(),
    fontSize: size,
  );
  pw.Widget line(String value, double size, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6.5),
    child: pw.Text(
      value,
      textAlign: pw.TextAlign.center,
      style: style(size, bold: bold),
    ),
  );

  final rows = <List<String>>[];
  for (final student in students) {
    final note = (student['notes'] as List? ?? [])
        .whereType<Map>()
        .where(
          (n) => "${n['evaluation_id']}" == "${evaluation['evaluation_id']}",
        )
        .firstOrNull;
    final value = num.tryParse(
      "${note?['valeur_note'] ?? ''}".replaceAll(',', '.'),
    );
    final absent = note?['situation'] == 'ABSENTE';
    final numeric = note?['situation'] == 'NUMERIQUE' && value != null;
    final mark = numeric
        ? value
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'\.?0+$'), '')
              .replaceAll('.', ',')
        : absent
        ? 'EL'
        : '—';
    final observation = note?['observation'] ?? student['observation'];
    rows.add([
      '${rows.length + 1}',
      "${student['matricule'] ?? ''}",
      (student['nom_complet_pv'] ?? student['nom'] ?? '').toString().trim().toUpperCase(),
      mark,
      observation != null && observation.toString().trim().isNotEmpty
          ? observation.toString()
          : student['hors_compte'] == true
          ? 'Etudiant non autorisé'
          : absent
          ? 'Absence'
          : numeric
          ? 'OK'
          : 'Note manquante',
    ]);
  }
  document.addPage(
    pw.MultiPage(
      pageFormat: pdf.PdfPageFormat.a4,
      maxPages: rows.length + 2,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 20),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              '© UY1/CI     PV $unit - $program imprimé le :$date   Semestre $semester   Année académique : $year',
              style: style(8),
            ),
          ),
          pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}', style: style(9)),
        ],
      ),
      build: (_) => [
        pw.Image(header, width: 539, height: 134),
        pw.Column(
          children: [
            line("PROCES VERBAL DE L'UNITE D'ENSEIGNEMENT", 15, bold: true),
            line(
              "$unit-${source['intitule_ue'] ?? ''}".toUpperCase(),
              13,
              bold: true,
            ),
            line('$label ( $type )', 11, bold: true),
            if (distinguishEvaluation) line(identifier, 9),
            line(
              "FILIERE : $program - ${source['filiere'] ?? '-'}".toUpperCase(),
              10,
            ),
            line(
              "SPECIALITE : ${source['specialite'] ?? '-'}".toUpperCase(),
              10,
            ),
            line(
              "GRADE : ${source['code_niveau'] ?? source['niveau'] ?? '-'}   SEMESTRE : $semester    Année académique : $year",
              10,
            ),
          ],
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
        ),
        pw.TableHelper.fromTextArray(
          headers: [
            'NUM',
            'MATRICULE',
            'NOMS ET PRENOMS',
            '$type /\n20',
            'OBSERVATIONS',
          ],
          data: rows,
          columnWidths: {
            for (final e in [38, 62, 190, 32, 187].asMap().entries)
              e.key: pw.FixedColumnWidth(e.value.toDouble()),
          },
          tableWidth: pw.TableWidth.min,
          headerStyle: style(8, bold: true),
          cellStyle: style(9),
          cellAlignment: pw.Alignment.topLeft,
          headerAlignment: pw.Alignment.topLeft,
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 1.4,
          ),
          border: pw.TableBorder.all(
            color: pdf.PdfColors.cyanAccent,
            width: .65,
          ),
        ),
      ],
      crossAxisAlignment: pw.CrossAxisAlignment.center,
    ),
  );
}
