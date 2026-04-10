import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../network/api_service.dart';
import '../storage/database_service.dart';
import '../storage/local_storage_service.dart';
import 'sync_service.dart';

/// Service de persistance des données - Mode Hybride Online/Offline
/// 
/// Gère automatiquement :
/// - Synchronisation au démarrage
/// - Mise à jour en temps réel quand online
/// - Fallback offline transparent
/// - Persistance locale intelligente
class DataPersistenceService {
  static final DataPersistenceService _instance = DataPersistenceService._internal();
  factory DataPersistenceService() => _instance;
  DataPersistenceService._internal();

  final ApiService _api = ApiService();
  final SyncService _sync = SyncService();
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _backgroundSyncTimer;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Callbacks pour notifier les changements
  final Map<String, List<Function()>> _listeners = {};

  /// Initialise le service et lance la première sync
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Sync initiale depuis le serveur
    await _initialSync();
    
    // Écouter les changements de connexion
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (isConnected) {
        // Connexion revenue → sync automatique
        _onConnectionRestored();
      }
    });
    
    // Sync périodique en arrière-plan (toutes les 15 minutes seulement)
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _backgroundSync();
    });
    
    _isInitialized = true;
  }

  /// Libère les ressources
  void dispose() {
    _connectivitySubscription?.cancel();
    _backgroundSyncTimer?.cancel();
    _listeners.clear();
  }

  // ─────────────────────────────────────────────────────────────
  // GESTION DES LISTENERS
  // ─────────────────────────────────────────────────────────────

  /// Écoute les changements d'un type de données
  void addListener(String dataType, Function() callback) {
    _listeners.putIfAbsent(dataType, () => []);
    _listeners[dataType]!.add(callback);
  }

  /// Arrête d'écouter
  void removeListener(String dataType, Function() callback) {
    _listeners[dataType]?.remove(callback);
  }

  /// Notifie les listeners d'un changement
  void _notifyListeners(String dataType) {
    _listeners[dataType]?.forEach((cb) => cb());
  }

  // ─────────────────────────────────────────────────────────────
  // SYNCHRONISATION
  // ─────────────────────────────────────────────────────────────

  /// Sync initiale au démarrage de l'app
  Future<void> _initialSync() async {
    await _sync.syncFromServer();
  }

  /// Appelé quand la connexion revient
  Future<void> _onConnectionRestored() async {
    // Sync les actions locales d'abord
    await _sync.syncPendingToServer();
    // Puis récupère les données serveur
    await _sync.syncFromServer();
    
    // Notifier tous les listeners
    _notifyListeners('all');
  }

  DateTime? _lastBackgroundSync;
  
  /// Sync périodique en arrière-plan (max une fois toutes les 10 minutes)
  Future<void> _backgroundSync() async {
    try {
      // Éviter les syncs trop fréquents
      if (_lastBackgroundSync != null) {
        final diff = DateTime.now().difference(_lastBackgroundSync!);
        if (diff.inMinutes < 10) return; // Minimum 10 minutes entre syncs
      }
      
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        _lastBackgroundSync = DateTime.now();
        await _sync.syncFromServer();
        _notifyListeners('all');
      }
    } catch (_) {
      // Silencieux en cas d'erreur
    }
  }

  /// Force une sync manuelle
  Future<void> forceSync() async {
    await _sync.syncPendingToServer();
    await _sync.syncFromServer();
    _notifyListeners('all');
  }

  // ─────────────────────────────────────────────────────────────
  // RÉCUPÉRATION DES DONNÉES (Online/Offline)
  // ─────────────────────────────────────────────────────────────

  /// Récupère les goals (offline first, sync en arrière-plan)
  Future<List<Map<String, dynamic>>> getGoals() async {
    // Toujours retourner les données locales d'abord
    final localGoals = await DatabaseService.getGoals();
    
    // Sync en arrière-plan si online
    _syncGoalsInBackground();
    
    return localGoals;
  }

  /// Récupère la library (offline first)
  Future<List<Map<String, dynamic>>> getLibrary() async {
    final localLibrary = await DatabaseService.getLibrary();
    _syncLibraryInBackground();
    return localLibrary;
  }

  /// Récupère les événements (offline first)
  Future<List<Map<String, dynamic>>> getEvents() async {
    final localEvents = await DatabaseService.getEvents();
    _syncEventsInBackground();
    return localEvents;
  }

  /// Récupère les conférences (offline first)
  Future<List<Map<String, dynamic>>> getConferences() async {
    final localConferences = await DatabaseService.getConferences();
    _syncConferencesInBackground();
    return localConferences;
  }

  /// Récupère le profil utilisateur (persistant)
  Future<Map<String, dynamic>?> getUserProfile() async {
    // 1. Essayer le cache mémoire
    if (LocalStorageService.cachedUser != null) {
      return LocalStorageService.cachedUser;
    }
    
    // 2. Essayer la base locale
    final userData = await DatabaseService.getAuth('user');
    if (userData != null) {
      return jsonDecode(userData);
    }
    
    // 3. Essayer le serveur
    try {
      final response = await _api.get('/auth/profile');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await DatabaseService.saveAuth('user', jsonEncode(data['user']));
        LocalStorageService.cachedUser = data['user'];
        return data['user'];
      }
    } catch (_) {}
    
    return null;
  }

  /// Récupère les stats dashboard (offline first)
  Future<Map<String, dynamic>?> getDashboardStats() async {
    final statsData = await DatabaseService.getDashboard('stats');
    if (statsData != null) {
      return jsonDecode(statsData);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // SYNC EN ARRIÈRE-PLAN (Silencieux)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncGoalsInBackground() async {
    try {
      final response = await _api.get('/goals', queryParams: {'limit': '100'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data'] ?? data;
        await DatabaseService.saveGoals(
          (items as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        _notifyListeners('goals');
      }
    } catch (_) {}
  }

  Future<void> _syncLibraryInBackground() async {
    try {
      final response = await _api.get('/library', queryParams: {'limit': '50'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data'] ?? data;
        await DatabaseService.saveLibrary(
          (items as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        _notifyListeners('library');
      }
    } catch (_) {}
  }

  Future<void> _syncEventsInBackground() async {
    try {
      final now = DateTime.now();
      final response = await _api.get('/events', queryParams: {
        'month': '${now.month}',
        'year': '${now.year}',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['events'] ?? [];
        await DatabaseService.saveEvents(
          (items as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        _notifyListeners('events');
      }
    } catch (_) {}
  }

  Future<void> _syncConferencesInBackground() async {
    try {
      final response = await _api.get('/conferences/active');
      if (response.statusCode == 200) {
        final items = jsonDecode(response.body);
        await DatabaseService.saveConferences(
          (items as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        _notifyListeners('conferences');
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // OPÉRATIONS CRUD AVEC SYNC AUTO
  // ─────────────────────────────────────────────────────────────

  /// Crée un goal (local + server si online, pending si offline)
  Future<bool> createGoal(String title, {String? description}) async {
    try {
      // Essayer online d'abord
      final response = await _api.post('/goals', {
        'title': title,
        'description': description,
      });
      
      if (response.statusCode == 201) {
        // Succès online → sync locale
        await _syncGoalsInBackground();
        return true;
      }
    } catch (_) {
      // Offline → sauvegarder comme pending
    }
    
    // Mode offline: ajouter aux pending
    await DatabaseService.addPendingSync(
      action: 'add_goal',
      tableName: 'goals',
      data: {'title': title, 'description': description, 'pending': true},
    );
    
    // Ajouter aussi en local pour affichage immédiat
    final localGoals = await DatabaseService.getGoals();
    localGoals.add({
      'id': DateTime.now().millisecondsSinceEpoch, // ID temporaire
      'title': title,
      'description': description,
      'status': 'pending',
      'pending': true,
    });
    await DatabaseService.saveGoals(localGoals);
    _notifyListeners('goals');
    
    return true;
  }

  /// Complète un goal
  Future<bool> completeGoal(int goalId) async {
    try {
      final response = await _api.put('/goals/$goalId', {'status': 'completed'});
      if (response.statusCode == 200) {
        await _syncGoalsInBackground();
        return true;
      }
    } catch (_) {}
    
    // Mode offline
    await DatabaseService.addPendingSync(
      action: 'complete_goal',
      tableName: 'goals',
      recordId: goalId,
      data: {'status': 'completed', 'pending': true},
    );
    
    // Mettre à jour localement
    final goals = await DatabaseService.getGoals();
    final index = goals.indexWhere((g) => g['id'] == goalId);
    if (index != -1) {
      goals[index]['status'] = 'completed';
      goals[index]['pending'] = true;
      await DatabaseService.saveGoals(goals);
      _notifyListeners('goals');
    }
    
    return true;
  }

  /// Supprime un goal
  Future<bool> deleteGoal(int goalId) async {
    try {
      final response = await _api.delete('/goals/$goalId');
      if (response.statusCode == 200) {
        await _syncGoalsInBackground();
        return true;
      }
    } catch (_) {}
    
    // Mode offline
    await DatabaseService.addPendingSync(
      action: 'delete_goal',
      tableName: 'goals',
      recordId: goalId,
      data: {'deleted': true, 'pending': true},
    );
    
    // Supprimer localement
    final goals = await DatabaseService.getGoals();
    goals.removeWhere((g) => g['id'] == goalId);
    await DatabaseService.saveGoals(goals);
    _notifyListeners('goals');
    
    return true;
  }

  /// Rafraîchit une donnée spécifique
  Future<void> refresh(String dataType) async {
    switch (dataType) {
      case 'goals':
        await _syncGoalsInBackground();
        break;
      case 'library':
        await _syncLibraryInBackground();
        break;
      case 'events':
        await _syncEventsInBackground();
        break;
      case 'conferences':
        await _syncConferencesInBackground();
        break;
      case 'all':
        await forceSync();
        break;
    }
  }

  /// Retourne le nombre d'actions en attente
  Future<int> get pendingCount => DatabaseService.pendingCount;

  /// Vérifie si une sync est en cours
  bool get isSyncing => _sync.isSyncing;
}
