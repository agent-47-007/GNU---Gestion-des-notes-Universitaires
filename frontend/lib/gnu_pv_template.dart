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
  style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : null),
);
