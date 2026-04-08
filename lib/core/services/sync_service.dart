import 'dart:convert';
import 'dart:developer' as developer;
import '../network/api_service.dart';
import '../storage/database_service.dart';

/// Service de synchronisation avec retry et logging
/// Gère la sync bidirectionnelle entre l'app et le backend
class SyncService {
  final ApiService _api = ApiService();
  bool _isSyncing = false;
  
  /// Nombre maximum de tentatives pour les requêtes
  static const int maxRetries = 3;
  
  /// Délai entre les tentatives (en millisecondes)
  static const int retryDelayMs = 1000;

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
            success = await _syncGoalActionWithRetry(action, recordId, row['data'] as String);
          }
        } catch (e, stackTrace) {
          developer.log(
            'Sync action failed: $action for goal $recordId',
            name: 'SyncService',
            error: e,
            stackTrace: stackTrace,
          );
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

  /// Exécute une action avec retry automatique
  Future<bool> _syncGoalActionWithRetry(String action, int? recordId, String dataStr) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < maxRetries) {
      try {
        return await _syncGoalAction(action, recordId, dataStr);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempts++;
        
        if (attempts < maxRetries) {
          developer.log(
            'Retry $attempts/$maxRetries for action $action',
            name: 'SyncService',
          );
          await Future.delayed(Duration(milliseconds: retryDelayMs * attempts));
        }
      }
    }
    
    developer.log(
      'Failed after $maxRetries attempts for action $action: $lastError',
      name: 'SyncService',
      error: lastError,
    );
    return false;
  }

  // ── Goals ────────────────────────────────────────────────
  Future<void> _syncGoalsFromServer() async {
    try {
      developer.log('Syncing goals from server...', name: 'SyncService');
      final response = await _api.get('/goals', queryParams: {'limit': '100'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data'] ?? data;
        await DatabaseService.saveGoals(
          items.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        developer.log('Synced ${items.length} goals from server', name: 'SyncService');
      } else {
        developer.log(
          'Failed to sync goals: HTTP ${response.statusCode}',
          name: 'SyncService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error syncing goals from server',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
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
      developer.log('Syncing library from server...', name: 'SyncService');
      final response = await _api.get('/library', queryParams: {'limit': '50'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data'] ?? data;
        await DatabaseService.saveLibrary(
          items.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        developer.log('Synced ${items.length} library items', name: 'SyncService');
      } else {
        developer.log(
          'Failed to sync library: HTTP ${response.statusCode}',
          name: 'SyncService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error syncing library from server',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Events ───────────────────────────────────────────────
  Future<void> _syncEventsFromServer() async {
    try {
      developer.log('Syncing events from server...', name: 'SyncService');
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
        developer.log('Synced ${items.length} events', name: 'SyncService');
      } else {
        developer.log(
          'Failed to sync events: HTTP ${response.statusCode}',
          name: 'SyncService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error syncing events from server',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Conferences ──────────────────────────────────────────
  Future<void> _syncConferencesFromServer() async {
    try {
      developer.log('Syncing conferences from server...', name: 'SyncService');
      final response = await _api.get('/conferences/active');
      if (response.statusCode == 200) {
        final List<dynamic> items = jsonDecode(response.body);
        await DatabaseService.saveConferences(
          items.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        developer.log('Synced ${items.length} conferences', name: 'SyncService');
      } else {
        developer.log(
          'Failed to sync conferences: HTTP ${response.statusCode}',
          name: 'SyncService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error syncing conferences from server',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Dashboard ────────────────────────────────────────────
  Future<void> _syncDashboardFromServer() async {
    try {
      developer.log('Syncing dashboard stats...', name: 'SyncService');
      final response = await _api.get('/dashboard/stats');
      if (response.statusCode == 200) {
        await DatabaseService.saveDashboard('stats', response.body);
        developer.log('Dashboard stats synced', name: 'SyncService');
      } else {
        developer.log(
          'Failed to sync dashboard: HTTP ${response.statusCode}',
          name: 'SyncService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error syncing dashboard from server',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Helper ───────────────────────────────────────────────
  Map<String, dynamic> _parseData(String dataStr) {
    try {
      return Map<String, dynamic>.from(jsonDecode(dataStr));
    } catch (e) {
      developer.log(
        'Failed to parse sync data: $dataStr',
        name: 'SyncService',
        error: e,
      );
      return {};
    }
  }

  bool get isSyncing => _isSyncing;
}
