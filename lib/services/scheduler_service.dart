import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/provider_config.dart';
import 'agent_engine.dart';

/// Runs scheduled tasks. While the app is alive a Timer checks every minute
/// for due tasks and runs them headlessly through a background AgentEngine.
/// Tasks persist to disk, so they survive restarts and re-arm on launch.
class SchedulerService {
  final List<ModelRouteHolder> _holder;
  Timer? _timer;

  SchedulerService(this._holder);

  Future<File> _file() async {
    final base = await getApplicationDocumentsDirectory();
    final f = File('${base.path}/scheduled_tasks.json');
    if (!f.existsSync()) f.writeAsStringSync('[]');
    return f;
  }

  Future<List<Map<String, dynamic>>> list() async {
    final f = await _file();
    try {
      return (jsonDecode(await f.readAsString()) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> tasks) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(tasks));
  }

  Future<void> add(Map<String, dynamic> task) async {
    final tasks = await list();
    tasks.add(task);
    await _save(tasks);
  }

  Future<void> remove(String id) async {
    final tasks = await list()
      ..removeWhere((t) => t['id'] == id);
    await _save(tasks);
  }

  Future<void> toggle(String id) async {
    final tasks = await list();
    for (final t in tasks) {
      if (t['id'] == id) t['enabled'] = !(t['enabled'] == true);
    }
    await _save(tasks);
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    _tick();
  }

  void stop() => _timer?.cancel();

  Future<void> _tick() async {
    final tasks = await list();
    if (tasks.isEmpty) return;
    final now = DateTime.now();
    var changed = false;
    for (final t in tasks) {
      if (t['enabled'] != true) continue;
      final next = DateTime.tryParse('${t['nextRun'] ?? ''}');
      if (next == null || now.isBefore(next)) continue;

      // run headlessly
      final engine = AgentEngine()
        ..routes = _holder.first.routes
        ..workspace = _holder.first.workspace;
      try {
        await engine.runHeadless(t['prompt'] as String? ?? '');
        await _appendLog(t, 'ok');
      } catch (e) {
        await _appendLog(t, 'erreur: $e');
      }

      final every = t['everyMinutes'];
      if (every is int && every > 0) {
        t['nextRun'] = now.add(Duration(minutes: every)).toIso8601String();
      } else {
        t['enabled'] = false; // one-shot done
      }
      changed = true;
    }
    if (changed) await _save(tasks);
  }

  Future<void> _appendLog(Map<String, dynamic> t, String status) async {
    final base = await getApplicationDocumentsDirectory();
    final f = File('${base.path}/task_log.txt');
    await f.writeAsString(
      '${DateTime.now().toIso8601String()} | ${t['title']} | $status\n',
      mode: FileMode.append,
    );
  }
}

/// Minimal holder so the scheduler always sees current routes/workspace.
class ModelRouteHolder {
  final List<ModelRoute> routes;
  final String workspace;
  ModelRouteHolder(this.routes, this.workspace);
}
