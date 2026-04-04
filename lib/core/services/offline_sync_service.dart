import '../network/api_service.dart';
import '../storage/local_storage_service.dart';

class OfflineSyncService {
  final ApiService _api = ApiService();
  final LocalStorageService _storage = LocalStorageService();

  bool _isSyncing = false;

  /// Synchronise toutes les actions en attente avec le serveur
  /// Retourne le nombre d'actions synchronisées
  Future<int> syncPendingActions() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int synced = 0;
    final keys = _storage.getPendingActionKeys();
    final actions = _storage.getPendingActions();

    for (int i = 0; i < actions.length; i++) {
      final action = actions[i];
      final key = keys[i];

      try {
        final success = await _executeAction(action);
        if (success) {
          await _storage.removePendingAction(key);
          synced++;
        }
      } catch (_) {
        // On garde l'action en attente si elle échoue
      }
    }

    _isSyncing = false;
    return synced;
  }

  Future<bool> _executeAction(Map<String, dynamic> action) async {
    final type = action['type'] as String;
    final data = Map<String, dynamic>.from(action['data'] ?? {});

    switch (type) {
      case 'add_goal':
        final response = await _api.post('/goals', data);
        return response.statusCode == 201;

      case 'complete_goal':
        final id = action['id'];
        final response = await _api.put('/goals/$id', {'status': 'completed'});
        return response.statusCode == 200;

      case 'delete_goal':
        final id = action['id'];
        final response = await _api.delete('/goals/$id');
        return response.statusCode == 200;

      default:
        return false;
    }
  }

  bool get isSyncing => _isSyncing;
}
