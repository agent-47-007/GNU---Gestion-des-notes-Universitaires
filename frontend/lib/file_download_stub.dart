import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> downloadFile(String filename, Uint8List bytes) async {
  await FilePicker.platform.saveFile(
    fileName: filename,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: [filename.split('.').last],
  );
}
