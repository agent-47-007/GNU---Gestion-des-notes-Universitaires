// Server entry point: read one published snapshot on stdin, emit one PDF on stdout.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import '../lib/transcript_layout.dart';

Future<void> main(List<String> args) async {
  final input = jsonDecode(await stdin.transform(utf8.decoder).join()) as Map;
  final assets = Directory(args.single);
  Future<pw.Font> font(String name) async => pw.Font.ttf(ByteData.sublistView(
      await File('${assets.path}/fonts/$name.ttf').readAsBytes()));
  final theme = pw.ThemeData.withFont(base: await font('DejaVuSans'), bold: await font('DejaVuSans-Bold'));
  final doc = pw.Document(theme: theme, title: input['reference_officielle']);
  final structure = input['structure'] as Map;
  final encoded = structure['logo']?['base64'];
  final logo = encoded != null ? base64Decode(encoded) :
      structure['universite'].toString().toUpperCase().contains('YAOUND')
      ? await File('${assets.path}/uy1_crest.png').readAsBytes() : null;
  addTranscript(doc, input, structure, {}, input['periode'], structure['annee'], true,
      logo == null ? null : pw.MemoryImage(logo));
  stdout.add(await doc.save());
  await stdout.flush();
}
