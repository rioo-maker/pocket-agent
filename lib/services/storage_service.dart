import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider_config.dart';

/// Persists settings (SharedPreferences) and model routes with API keys
/// (flutter_secure_storage, encrypted by Android Keystore).
class StorageService {
  static const _routesKey = 'model_routes_v1';
  static const _skinKey = 'skin';
  static const _onboardedKey = 'onboarded';
  static const _workspaceKey = 'workspace';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<List<ModelRoute>> loadRoutes() async {
    final raw = await _secure.read(key: _routesKey) ?? '';
    try {
      return ModelRoute.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRoutes(List<ModelRoute> routes) async {
    await _secure.write(key: _routesKey, value: ModelRoute.encodeList(routes));
  }

  Future<String> loadSkin() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_skinKey) ?? 'claude';
  }

  Future<void> saveSkin(String skin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_skinKey, skin);
  }

  Future<bool> isOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_onboardedKey, true);
  }

  Future<String?> loadWorkspace() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_workspaceKey);
  }

  Future<void> saveWorkspace(String path) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_workspaceKey, path);
  }
}
