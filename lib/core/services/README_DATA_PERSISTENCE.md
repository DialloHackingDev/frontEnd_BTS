# Service de Persistance des Données

## Vue d'ensemble

Le `DataPersistenceService` gère automatiquement la synchronisation des données entre le serveur et la base locale SQLite. Il fonctionne en mode **hybride online/offline** transparent pour l'utilisateur.

## Fonctionnalités

- ✅ **Offline First** : Les données sont toujours lues depuis SQLite d'abord
- ✅ **Sync automatique** : Mise à jour en arrière-plan quand online
- ✅ **Persistance** : Données conservées entre les sessions
- ✅ **Notifications** : Les écrans sont notifiés des changements
- ✅ **CRUD offline** : Créer/modifier/supprimer même hors ligne

## Données synchronisées

| Type | Sync Auto | Offline CRUD | Persistant |
|------|-----------|--------------|------------|
| Goals | ✅ | ✅ | ✅ |
| Library | ✅ | ❌ (lecture seule) | ✅ |
| Events | ✅ | ❌ (lecture seule) | ✅ |
| Conferences | ✅ | ❌ (lecture seule) | ✅ |
| Profile | ✅ | ❌ | ✅ |
| Dashboard | ✅ | ❌ | ✅ |

## Utilisation

### 1. Initialisation (déjà fait dans main.dart)

```dart
void main() async {
  // ...
  await DataPersistenceService().initialize();
  runApp(const MyApp());
}
```

### 2. Dans un Screen - Récupérer les données

```dart
import '../../../core/services/data_persistence_service.dart';

class _GoalsScreenState extends State<GoalsScreen> {
  final DataPersistenceService _dataService = DataPersistenceService();
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    // Écouter les changements
    _dataService.addListener('goals', _onGoalsUpdated);
  }

  @override
  void dispose() {
    _dataService.removeListener('goals', _onGoalsUpdated);
    super.dispose();
  }

  void _onGoalsUpdated() {
    if (mounted) _loadGoals();
  }

  Future<void> _loadGoals() async {
    final goals = await _dataService.getGoals();
    setState(() {
      _goals = goals;
      _isLoading = false;
    });
  }
}
```

### 3. Créer/Modifier/Supprimer

```dart
// Créer un goal (fonctionne offline)
await _dataService.createGoal('Mon nouveau goal', description: '...');

// Compléter un goal
await _dataService.completeGoal(goalId);

// Supprimer un goal
await _dataService.deleteGoal(goalId);
```

### 4. Rafraîchir manuellement

```dart
// Forcer une sync complète
await _dataService.forceSync();

// Ou rafraîchir un type spécifique
await _dataService.refresh('goals');
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FLUTTER UI                          │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│            DataPersistenceService                       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐   │
│  │ getGoals()  │  │createGoal()  │  │ forceSync()   │   │
│  │ getLibrary()│  │completeGoal()│  │ refresh()     │   │
│  │ getEvents() │  │deleteGoal()  │  │               │   │
│  └──────┬──────┘  └──────┬───────┘  └───────┬───────┘   │
└─────────┼────────────────┼──────────────────┼───────────┘
          │                │                  │
          ▼                ▼                  ▼
┌─────────────────────────────────────────────────────────┐
│                   SQLite (Local)                      │
│         ┌────────┐ ┌────────┐ ┌──────────────┐         │
│         │ goals  │ │library │ │ pending_sync │         │
│         └────────┘ └────────┘ └──────────────┘         │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ (quand online)
┌─────────────────────────────────────────────────────────┐
│                   Backend API                           │
└─────────────────────────────────────────────────────────┘
```

## Comportement Offline

Quand l'utilisateur est hors ligne :

1. **Lecture** : Données lues depuis SQLite (toujours disponibles)
2. **Écriture** : Actions stockées dans `pending_sync`
3. **Affichage** : Les modifications sont visibles immédiatement (mode optimiste)
4. **Sync** : Automatique quand la connexion revient

## Exemple complet : GoalsScreen simplifié

```dart
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final DataPersistenceService _dataService = DataPersistenceService();
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _dataService.addListener('goals', _onDataUpdated);
    _dataService.addListener('all', _onDataUpdated);
  }

  @override
  void dispose() {
    _dataService.removeListener('goals', _onDataUpdated);
    _dataService.removeListener('all', _onDataUpdated);
    super.dispose();
  }

  void _onDataUpdated() => _loadData();

  Future<void> _loadData() async {
    final goals = await _dataService.getGoals();
    final pending = await _dataService.pendingCount;
    setState(() {
      _goals = goals;
      _pendingCount = pending;
      _isLoading = false;
    });
  }

  Future<void> _addGoal() async {
    final title = await _showAddGoalDialog();
    if (title != null) {
      setState(() => _isLoading = true);
      await _dataService.createGoal(title);
      await _loadData();
    }
  }

  Future<void> _completeGoal(int id) async {
    await _dataService.completeGoal(id);
    await _loadData();
  }

  Future<void> _deleteGoal(int id) async {
    await _dataService.deleteGoal(id);
    await _loadData();
  }

  Future<void> _refresh() async {
    await _dataService.forceSync();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Goals'),
        actions: [
          if (_pendingCount > 0)
            Badge(
              label: Text('$_pendingCount'),
              child: const Icon(Icons.sync),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _goals.length,
              itemBuilder: (context, index) {
                final goal = _goals[index];
                return ListTile(
                  title: Text(goal['title']),
                  subtitle: goal['pending'] == true 
                      ? const Text('En attente de sync...', 
                          style: TextStyle(color: Colors.orange))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (goal['status'] != 'completed')
                        IconButton(
                          icon: const Icon(Icons.check_circle),
                          onPressed: () => _completeGoal(goal['id']),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteGoal(goal['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```
