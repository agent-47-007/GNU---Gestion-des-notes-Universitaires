import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> downloadFile(String filename, Uint8List bytes) async {
  final extension = filename.split('.').last.toLowerCase();
  final mimeType = switch (extension) {
    'pdf' => 'application/pdf',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'csv' => 'text/csv;charset=utf-8',
    _ => 'application/octet-stream',
  };
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
