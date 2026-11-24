import 'dart:io';
import 'package:flutter/services.dart';

abstract final class CsvDocuments {
  static const _channel = MethodChannel('dev.pixelbudget.app/csv_documents');

  static Future<Uint8List?> open() async {
    final path = await _channel.invokeMethod<String>('openToFile');
    if (path == null) return null;
    final file = File(path);
    try {
      return await file.readAsBytes();
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  static Future<bool?> save(String name, Uint8List bytes) async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'pixel_budget_export_${DateTime.now().microsecondsSinceEpoch}.csv',
    );
    await file.writeAsBytes(bytes, flush: true);
    try {
      return await _channel.invokeMethod<bool>('saveFromFile', {
        'name': name,
        'path': file.path,
      });
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}
