import 'dart:convert';
import 'database_service.dart';

class LocalStorageService {
  // ── Auth ─────────────────────────────────────────────────
  Future<void> init() async {
    await DatabaseService.db; // initialise la DB
  }

  Future<void> saveToken(String token) async {
    await DatabaseService.saveAuth('token', token);
  }

  String? getToken() => _syncGet('token');
  String? _tokenCache;

  // Pour les appels synchrones on garde un cache mémoire du token
  static String? cachedToken;
  static Map<String, dynamic>? cachedUser;

  Future<void> saveTokenAsync(String token) async {
    cachedToken = token;
    await DatabaseService.saveAuth('token', token);
  }

  Future<String?> getTokenAsync() async {
    if (cachedToken != null) return cachedToken;
    cachedToken = await DatabaseService.getAuth('token');
    return cachedToken;
  }

  String? getToken2() => cachedToken;

  Future<void> saveUser(dynamic user) async {
    final encoded = jsonEncode(user);
    cachedUser = user is Map<String, dynamic> ? user : jsonDecode(encoded);
    await DatabaseService.saveAuth('user', encoded);
  }

  dynamic getUser() {
    if (cachedUser != null) return cachedUser;
    return null;
  }

  Future<dynamic> getUserAsync() async {
    if (cachedUser != null) return cachedUser;
    final data = await DatabaseService.getAuth('user');
    if (data != null) {
      cachedUser = jsonDecode(data);
      return cachedUser;
    }
    return null;
  }

  String getUserRole() {
    final user = getUser();
    return user != null ? (user['role'] ?? 'USER') : 'USER';
  }

  Future<void> clearAll() async {
    cachedToken = null;
    cachedUser = null;
    await DatabaseService.clearAll();
  }

  // ── Initialisation depuis DB (à appeler au démarrage) ────
  static Future<void> loadCache() async {
    cachedToken = await DatabaseService.getAuth('token');
    final userData = await DatabaseService.getAuth('user');
    if (userData != null) {
      cachedUser = jsonDecode(userData);
    }
  }

  // ── Goals ────────────────────────────────────────────────
  Future<void> saveGoals(List<dynamic> data) async {
    await DatabaseService.saveGoals(
      data.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<dynamic>?> getGoalsAsync() async {
    final rows = await DatabaseService.getGoals();
    return rows.isEmpty ? null : rows;
  }

  // ── Library ──────────────────────────────────────────────
  Future<void> saveLibrary(List<dynamic> data) async {
    await DatabaseService.saveLibrary(
      data.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<List<dynamic>?> getLibraryAsync() async {
    final rows = await DatabaseService.getLibrary();
    return rows.isEmpty ? null : rows;
  }

  // ── Dashboard ────────────────────────────────────────────
  Future<void> saveDashboard(dynamic data) async {
    await DatabaseService.saveDashboard('stats', jsonEncode(data));
  }

  Future<dynamic> getDashboardAsync() async {
    final data = await DatabaseService.getDashboard('stats');
    return data != null ? jsonDecode(data) : null;
  }

  // ── Pending Actions ──────────────────────────────────────
  Future<void> addPendingAction(Map<String, dynamic> action) async {
    await DatabaseService.addPendingSync(
      action: action['type'] ?? 'unknown',
      tableName: _getTableName(action['type']),
      recordId: action['id'],
      data: action,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingActionsAsync() async {
    final rows = await DatabaseService.getPendingSync();
    return rows.map((r) {
      try {
        return Map<String, dynamic>.from(r);
      } catch (_) {
        return r;
      }
    }).toList();
  }

  Future<void> removePendingAction(int id) async {
    await DatabaseService.removePendingSync(id);
  }

  Future<int> getPendingCountAsync() async {
    return DatabaseService.pendingCount;
  }

  // Synchrone pour compatibilité (retourne 0 si pas encore chargé)
  int get pendingCount => 0;

  String _getTableName(String? type) {
    if (type == null) return 'unknown';
    if (type.contains('goal')) return 'goals';
    if (type.contains('library')) return 'library';
    return 'unknown';
  }

  // ── Méthode sync pour compatibilité ─────────────────────
  String? _syncGet(String key) => cachedToken;
}
