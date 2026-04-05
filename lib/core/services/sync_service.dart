import 'dart:convert';
import '../network/api_service.dart';
import '../storage/database_service.dart';

class SyncService {
  final ApiService _api = ApiService();
  bool _isSyncing = false;

  /// Synchronise toutes les données depuis le backend vers SQLite
  Future<void> syncFromServer() async {
    await Future.wait([
      _syncGoalsFromServer(),
      _syncLibraryFromServer(),
      _syncEventsFromServer(),
      _syncConferencesFromServer(),
      _syncDashboardFromServer(),
    ]);
  }

  /// Synchronise les actions locales en attente vers le backend
  /// Retourne le nombre d'actions synchronisées
  Future<int> syncPendingToServer() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;

    try {
      final pending = await DatabaseService.getPendingSync();

      for (final row in pending) {
        final id = row['id'] as int;
        final action = row['action'] as String;
        final tableName = row['table_name'] as String;
        final recordId = row['record_id'] as int?;

        bool success = false;

        try {
          if (tableName == 'goals') {
            success = await _syncGoalAction(action, recordId, row['data'] as String);
          }
        } catch (_) {
          success = false;
        }

        if (success) {
          await DatabaseService.removePendingSync(id);
          synced++;
        }
      }

      // Après sync des actions locales, re-fetch depuis le serveur
      if (synced > 0) await _syncGoalsFromServer();
    } finally {
      _isSyncing = false;
    }

    return synced;
  }

  // ── Goals ────────────────────────────────────────────────
  Future<void> _syncGoalsFromServer() async {
    try {
      final response = await _api.get('/goals', queryParams: {'limit': '100'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data'] ?? data;
        await DatabaseService.saveGoals(
          items.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (_) {}
  }

  Future<bool> _syncGoalAction(String action, int? recordId, String dataStr) async {
    switch (action) {
      case 'add_goal':
        final data = _parseData(dataStr);
        final response = await _api.post('/goals', {
          'title': data['title'],
          'description': data['description'],
        });
        return response.statusCode == 201;

      case 'complete_goal':
        if (recordId == null) return false;
        final response = await _api.put('/goals/$recordId', {'status': 'completed'});
        return response.statusCode == 200;

      case 'delete_goal':
        if (recordId == null) return false;
        final response = await _api.delete('/goals/$recordId');
        return response.statusCode == 200;

      default:
        return false;
    }
  }

  // ── Library ──────────────────────────────────────────────
  Future<void> _syncLibraryFromServer() async {
    try {
      final response = await _api.get('/library', queryParams: {'limit': '50'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data'] ?? data;
        await DatabaseService.saveLibrary(
          items.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (_) {}
  }

  // ── Events ───────────────────────────────────────────────
  Future<void> _syncEventsFromServer() async {
    try {
      final now = DateTime.now();
      final response = await _api.get('/events', queryParams: {
        'month': '${now.month}',
        'year': '${now.year}',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['events'] ?? [];
        await DatabaseService.saveEvents(
          items.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (_) {}
  }

  // ── Conferences ──────────────────────────────────────────
  Future<void> _syncConferencesFromServer() async {
    try {
      final response = await _api.get('/conferences/active');
      if (response.statusCode == 200) {
        final List<dynamic> items = jsonDecode(response.body);
        await DatabaseService.saveConferences(
          items.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (_) {}
  }

  // ── Dashboard ────────────────────────────────────────────
  Future<void> _syncDashboardFromServer() async {
    try {
      final response = await _api.get('/dashboard/stats');
      if (response.statusCode == 200) {
        await DatabaseService.saveDashboard('stats', response.body);
      }
    } catch (_) {}
  }

  // ── Helper ───────────────────────────────────────────────
  Map<String, dynamic> _parseData(String dataStr) {
    try {
      return Map<String, dynamic>.from(jsonDecode(dataStr));
    } catch (_) {
      // Format toString() de Dart — conversion basique
      return {};
    }
  }

  bool get isSyncing => _isSyncing;
}
