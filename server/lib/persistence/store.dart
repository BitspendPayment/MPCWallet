import 'dart:convert';
import 'package:hive/hive.dart';

class SessionStore {
  static const _sessionBoxName = 'sessions';
  late Box _box;

  Future<void> init() async {
    // Initialize Hive in the current directory (for now)
    Hive.init('hive_db');
    _box = await Hive.openBox(_sessionBoxName);
  }

  Future<void> saveSession(String deviceId, String jsonData) async {
    await _box.put(deviceId, jsonData);
  }

  String? getSession(String deviceId) {
    return _box.get(deviceId);
  }

  // Clean up if needed
  Future<void> close() async {
    await _box.close();
  }
}
