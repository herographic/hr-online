// lib/utils/web_downloader_web.dart

import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation for downloading a file.
Future<void> downloadFileFromBytes(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}