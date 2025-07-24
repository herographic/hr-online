// lib/utils/web_downloader.dart

import 'dart:typed_data';

/// Stub implementation for non-web platforms.
Future<void> downloadFileFromBytes(Uint8List bytes, String fileName) async {
  // This function does nothing on mobile, as the printing package handles it.
  throw UnimplementedError('This function is only available on the web.');
}