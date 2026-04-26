import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailManager {
  static Future<Directory> _getThumbDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${appDir.path}/thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  static Future<String> saveThumbnail(int tabId, int kifId, Uint8List bytes) async {
    final dir = await _getThumbDir();
    final file = File('${dir.path}/thumb_${tabId}_$kifId.png');
    await file.writeAsBytes(bytes);
    await FileImage(file).evict(); // キャッシュクリア
    return file.path; 
  }
}
