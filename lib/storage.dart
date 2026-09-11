import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStore {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final data = Directory('${dir.path}/NibrasDocs');
    if (!await data.exists()) await data.create(recursive: true);
    return File('${data.path}/workspace.json');
  }

  Future<Map<String, dynamic>> load() async {
    final file = await _file();
    if (!await file.exists()) return {'documents': [], 'folders': []};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {'documents': [], 'folders': []};
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<File> backup(Map<String, dynamic> data) async {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}/NibrasDocs/Backups');
    if (!await backups.exists()) await backups.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${backups.path}/nibras_backup_$stamp.json');
    await file.writeAsString(jsonEncode(data), flush: true);
    return file;
  }
}
