import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Police intégrée aux documents GNU : évite les glyphes manquants pour le
/// français (accents, apostrophes typographiques) dans les lecteurs PDF.
Future<pw.ThemeData> gnuPdfTheme() async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  return pw.ThemeData.withFont(base: regular, bold: bold);
}
