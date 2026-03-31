import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class LocalStorageService {
  static const String dashboardBox = 'dashboard_cache';
  static const String goalsBox = 'goals_cache';
  static const String libraryBox = 'library_cache';
  static const String authBox = 'auth_data';

  // Open all necessary boxes
  Future<void> init() async {
    await Hive.openBox(dashboardBox);
    await Hive.openBox(goalsBox);
    await Hive.openBox(libraryBox);
    await Hive.openBox(authBox);
  }

  // --- Auth ---
  Future<void> saveToken(String token) async {
    var box = Hive.box(authBox);
    await box.put('token', token);
  }

  String? getToken() {
    var box = Hive.box(authBox);
    return box.get('token');
  }

  Future<void> saveUser(dynamic user) async {
    var box = Hive.box(authBox);
    await box.put('user', jsonEncode(user));
  }

  dynamic getUser() {
    var box = Hive.box(authBox);
    final data = box.get('user');
    return data != null ? jsonDecode(data) : null;
  }

  String getUserRole() {
    final user = getUser();
    return user != null ? (user['role'] ?? 'USER') : 'USER';
  }

  // --- Dashboard ---
  Future<void> saveDashboard(dynamic data) async {
    var box = Hive.box(dashboardBox);
    await box.put('stats', jsonEncode(data));
  }

  dynamic getDashboard() {
    var box = Hive.box(dashboardBox);
    final data = box.get('stats');
    return data != null ? jsonDecode(data) : null;
  }

  // --- Goals ---
  Future<void> saveGoals(List<dynamic> data) async {
    var box = Hive.box(goalsBox);
    await box.put('list', jsonEncode(data));
  }

  List<dynamic>? getGoals() {
    var box = Hive.box(goalsBox);
    final data = box.get('list');
    return data != null ? jsonDecode(data) : null;
  }

  // --- Library ---
  Future<void> saveLibrary(List<dynamic> data) async {
    var box = Hive.box(libraryBox);
    await box.put('items', jsonEncode(data));
  }

  List<dynamic>? getLibrary() {
    var box = Hive.box(libraryBox);
    final data = box.get('items');
    return data != null ? jsonDecode(data) : null;
  }

  // Clear all cache (e.g. on logout)
  Future<void> clearAll() async {
    await Hive.box(dashboardBox).clear();
    await Hive.box(goalsBox).clear();
    await Hive.box(libraryBox).clear();
    await Hive.box(authBox).clear();
  }
}
