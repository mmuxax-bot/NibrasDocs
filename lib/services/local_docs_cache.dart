import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline local cache so documents survive without cloud login.
class LocalDocsCache {
  static const _key = 'nibras_local_docs';

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> saveDoc({
    required String id,
    required String title,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await load();
    final idx = docs.indexWhere((d) => d['id'] == id);
    final entry = {
      'id': id,
      'title': title,
      'content': content,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (idx >= 0) {
      docs[idx] = entry;
    } else {
      docs.insert(0, entry);
    }
    await prefs.setString(_key, jsonEncode(docs));
  }
}
