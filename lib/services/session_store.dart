import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists chat sessions as JSON files so conversations survive app restarts.
class SessionStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/sessions');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<void> save(String id, Map<String, dynamic> data) async {
    final d = await _dir();
    await File('${d.path}/$id.json').writeAsString(jsonEncode(data));
  }

  Future<Map<String, dynamic>?> load(String id) async {
    final d = await _dir();
    final f = File('${d.path}/$id.json');
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listMeta() async {
    final d = await _dir();
    final metas = <Map<String, dynamic>>[];
    for (final f in d.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        metas.add({
          'id': j['id'],
          'title': j['title'] ?? 'Session',
          'updatedAt': j['updatedAt'] ?? '',
        });
      } catch (_) {}
    }
    metas.sort((a, b) =>
        (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));
    return metas;
  }

  Future<void> delete(String id) async {
    final d = await _dir();
    final f = File('${d.path}/$id.json');
    if (f.existsSync()) await f.delete();
  }

  Future<String?> lastSessionId() async {
    final metas = await listMeta();
    return metas.isEmpty ? null : metas.first['id'] as String?;
  }
}
