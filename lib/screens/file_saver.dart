// =============================================================================
// file_saver.dart - 提出ファイルを「開く / ダウンロード / 共有」する
//   Web     : ブラウザのダウンロードになります
//   Android : 共有シートが開き、再生アプリ・PDFビューア・Drive などへ渡せます
// =============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers.dart';

Future<void> openOrSaveFile(
    BuildContext context, String fileName, Uint8List bytes) async {
  try {
    final file = XFile.fromData(bytes, name: fileName, mimeType: _mime(fileName));
    await SharePlus.instance.share(
      ShareParams(files: [file], fileNameOverrides: [fileName]),
    );
  } catch (e) {
    if (context.mounted) showMessage(context, 'Could not open the file: $e');
  }
}

String _mime(String name) {
  final ext = name.toLowerCase().split('.').last;
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'wav':
      return 'audio/wav';
    case 'aac':
      return 'audio/aac';
    case 'ogg':
      return 'audio/ogg';
    case 'webm':
      return 'audio/webm';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
  }
  return 'application/octet-stream';
}
