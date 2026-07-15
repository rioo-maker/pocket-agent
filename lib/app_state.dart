import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'models/provider_config.dart';
import 'services/agent_engine.dart';
import 'services/scheduler_service.dart';
import 'services/storage_service.dart';
import 'ui/theme.dart';

/// Global app state: skin, model routes, workspace, agent engine, scheduler.
class AppState extends ChangeNotifier {
  final StorageService storage = StorageService();
  final AgentEngine engine = AgentEngine();
  late final SchedulerService scheduler;

  TerminalSkin skin = TerminalSkin.claude;
  List<ModelRoute> routes = [];
  String workspace = '';
  bool onboarded = false;
  bool loaded = false;

  AppState() {
    scheduler = SchedulerService([ModelRouteHolder(routes, workspace)]);
  }

  ModelRouteHolder get _holder => ModelRouteHolder(routes, workspace);

  Future<void> init() async {
    skin = TerminalSkin.byId(await storage.loadSkin());
    routes = await storage.loadRoutes();
    onboarded = await storage.isOnboarded();

    var ws = await storage.loadWorkspace();
    if (ws == null || !Directory(ws).existsSync()) {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      ws = '${dir.path}/workspace';
      Directory(ws).createSync(recursive: true);
      await storage.saveWorkspace(ws);
    }
    workspace = ws;

    engine.routes = routes;
    engine.workspace = workspace;
    await engine.restoreLast();

    scheduler = SchedulerService([_holder]);
    scheduler.start();

    loaded = true;
    notifyListeners();
  }

  Future<void> setSkin(String id) async {
    skin = TerminalSkin.byId(id);
    await storage.saveSkin(id);
    notifyListeners();
  }

  Future<void> setWorkspace(String path) async {
    workspace = path;
    Directory(path).createSync(recursive: true);
    await storage.saveWorkspace(path);
    engine.workspace = path;
    notifyListeners();
  }

  Future<void> addRoute({
    required String label,
    required ApiType apiType,
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    routes.add(ModelRoute(
      id: const Uuid().v4(),
      label: label,
      apiType: apiType,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      priority: routes.length,
    ));
    await _persist();
  }

  Future<void> removeRoute(String id) async {
    routes.removeWhere((r) => r.id == id);
    _renumber();
    await _persist();
  }

  Future<void> toggleRoute(String id) async {
    final r = routes.where((r) => r.id == id).firstOrNull;
    if (r != null) r.enabled = !r.enabled;
    await _persist();
  }

  Future<void> moveRoute(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final r = routes.removeAt(oldIndex);
    routes.insert(newIndex, r);
    _renumber();
    await _persist();
  }

  void _renumber() {
    for (var i = 0; i < routes.length; i++) {
      routes[i].priority = i;
    }
  }

  Future<void> _persist() async {
    _renumber();
    await storage.saveRoutes(routes);
    engine.routes = routes;
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    await storage.setOnboarded();
    notifyListeners();
  }
}
