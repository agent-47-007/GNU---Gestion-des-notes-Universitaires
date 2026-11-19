import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import 'pdf_theme.dart';
import 'transcript_layout.dart';

Future<Uint8List> buildAcademicBulletinsPdf({
  required List<Map<String, dynamic>> bulletins,
  required Map<String, dynamic> structure,
  required String period,
  required String academicYear,
  required bool official,
  required pw.MemoryImage? crest,
  Map<String, dynamic> studentProfile = const {},
}) async {
  final document = pw.Document(
    theme: await gnuPdfTheme(),
    title: 'Relevé de notes / Transcript',
  );
  for (final bulletin in bulletins) {
    addTranscript(
      document,
      bulletin,
      structure,
      studentProfile,
      period,
      academicYear,
      official,
      crest,
    );
  }
  return document.save();
}
