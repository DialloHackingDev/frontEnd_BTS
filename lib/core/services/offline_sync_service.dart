import '../network/api_service.dart';
import '../storage/database_service.dart';

class OfflineSyncService {
  final ApiService _api = ApiService();
  bool _isSyncing = false;

  Future<int> syncPendingActions() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int synced = 0;

    final pending = await DatabaseService.getPendingSync();

    for (final row in pending) {
      final id = row['id'] as int;
      final action = row['action'] as String;
      final recordId = row['record_id'] as int?;

      try {
        bool success = false;

        switch (action) {
          case 'add_goal':
            final response = await _api.post('/goals', {
              'title': row['data']?.toString() ?? '',
            });
            success = response.statusCode == 201;
            break;

          case 'complete_goal':
            if (recordId != null) {
              final response = await _api.put('/goals/$recordId', {'status': 'completed'});
              success = response.statusCode == 200;
            }
            break;

          case 'delete_goal':
            if (recordId != null) {
              final response = await _api.delete('/goals/$recordId');
              success = response.statusCode == 200;
            }
            break;
        }

        if (success) {
          await DatabaseService.removePendingSync(id);
          synced++;
        }
      } catch (_) {}
    }

    _isSyncing = false;
    return synced;
  }

  bool get isSyncing => _isSyncing;
}
