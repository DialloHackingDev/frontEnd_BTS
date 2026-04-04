import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../models/goal.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final ApiService _apiService = ApiService();
  final LocalStorageService _storage = LocalStorageService();
  List<Goal> _goals = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _activeFilter = 0;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isOffline = false;
  int _pendingCount = 0;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _fetchGoals(reset: true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
        _pendingCount = _storage.pendingCount;
      });
    }
  }

  Future<void> _fetchGoals({bool reset = false}) async {
    if (reset) { _page = 1; _hasMore = true; _goals = []; }
    if (!_hasMore) return;

    if (mounted) setState(() => reset ? _isLoading = true : _isLoadingMore = true);

    try {
      final response = await _apiService.get('/goals', queryParams: {'page': '$_page', 'limit': '20'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data'] ?? data;
        if (mounted) {
          setState(() {
            _goals.addAll(items.map((json) => Goal.fromJson(json)).toList());
            _hasMore = _page < (data['totalPages'] ?? 1);
            _page++;
            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage = null;
            _isOffline = false;
          });
        }
      }
    } catch (_) {
      // Hors ligne — charger depuis le cache
      if (mounted) {
        final cached = _storage.getGoals();
        setState(() {
          _isOffline = true;
          _isLoading = false;
          _isLoadingMore = false;
          _pendingCount = _storage.pendingCount;
          if (cached != null && _goals.isEmpty) {
            _goals = cached.map((json) => Goal.fromJson(Map<String, dynamic>.from(json))).toList();
          } else if (_goals.isEmpty) {
            _errorMessage = 'Aucune donnée en cache. Connectez-vous une première fois.';
          }
        });
      }
    }
  }

  // ── Ajouter un objectif (online ou offline) ──────────────
  Future<void> _addGoal(BuildContext dialogContext) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final isOnline = await _isOnline();

    if (isOnline) {
      try {
        final response = await _apiService.post('/goals', {
          'title': title,
          'description': _descController.text.trim(),
        });
        if (response.statusCode == 201) {
          _titleController.clear();
          _descController.clear();
          if (mounted) {
            Navigator.of(dialogContext).pop();
            _fetchGoals(reset: true);
            _showSnack('Objectif ajouté ✅', Colors.green);
          }
        }
      } catch (_) {
        await _addGoalOffline(title, dialogContext);
      }
    } else {
      await _addGoalOffline(title, dialogContext);
    }
  }

  Future<void> _addGoalOffline(String title, BuildContext dialogContext) async {
    // Ajouter localement avec un ID temporaire négatif
    final tempId = -(DateTime.now().millisecondsSinceEpoch);
    final tempGoal = Goal(
      id: tempId,
      title: title,
      description: _descController.text.trim(),
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // Sauvegarder dans la file d'attente
    await _storage.addPendingAction({
      'type': 'add_goal',
      'data': {'title': title, 'description': _descController.text.trim()},
    });

    // Mettre à jour le cache local
    final cached = _storage.getGoals() ?? [];
    cached.insert(0, tempGoal.toJson());
    await _storage.saveGoals(cached);

    _titleController.clear();
    _descController.clear();

    if (mounted) {
      Navigator.of(dialogContext).pop();
      setState(() {
        _goals.insert(0, tempGoal);
        _pendingCount = _storage.pendingCount;
      });
      _showSnack('Objectif sauvegardé hors ligne 📴 — sera synchronisé au retour du réseau', Colors.orange);
    }
  }

  // ── Marquer comme terminé (online ou offline) ────────────
  Future<void> _markGoalCompleted(Goal goal) async {
    final isOnline = await _isOnline();

    if (isOnline) {
      try {
        final response = await _apiService.put('/goals/${goal.id}', {'status': 'completed'});
        if (response.statusCode == 200) {
          _fetchGoals(reset: true);
        }
      } catch (_) {
        await _markCompletedOffline(goal);
      }
    } else {
      await _markCompletedOffline(goal);
    }
  }

  Future<void> _markCompletedOffline(Goal goal) async {
    if (goal.id > 0) {
      // ID réel → mettre en file d'attente
      await _storage.addPendingAction({'type': 'complete_goal', 'id': goal.id});
    }
    // Mettre à jour localement
    if (mounted) {
      setState(() {
        final idx = _goals.indexWhere((g) => g.id == goal.id);
        if (idx != -1) {
          _goals[idx] = Goal(
            id: goal.id, title: goal.title, description: goal.description,
            status: 'completed', dueDate: goal.dueDate, createdAt: goal.createdAt,
          );
          _pendingCount = _storage.pendingCount;
        }
      });
    }
  }

  // ── Supprimer (online ou offline) ────────────────────────
  Future<void> _deleteGoal(Goal goal) async {
    final isOnline = await _isOnline();

    if (isOnline && goal.id > 0) {
      try {
        final response = await _apiService.delete('/goals/${goal.id}');
        if (response.statusCode == 200) {
          if (mounted) setState(() => _goals.removeWhere((g) => g.id == goal.id));
          return;
        }
      } catch (_) {}
    }

    // Offline ou ID temporaire
    if (goal.id > 0) {
      await _storage.addPendingAction({'type': 'delete_goal', 'id': goal.id});
    }
    if (mounted) {
      setState(() {
        _goals.removeWhere((g) => g.id == goal.id);
        _pendingCount = _storage.pendingCount;
      });
    }
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: Row(
          children: [
            const Text('NOUVEL OBJECTIF', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            if (_isOffline) ...[
              const SizedBox(width: 8),
              const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 16),
            ],
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isOffline)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('Mode hors-ligne — sera synchronisé plus tard',
                          style: TextStyle(color: Colors.orange, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(hintText: 'Titre de l\'objectif *'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(hintText: 'Description (Optionnel)'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ANNULER', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _addGoal(dialogContext),
            child: Text(_isOffline ? 'SAUVEGARDER OFFLINE' : 'AJOUTER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BORN TO SUCCESS'),
        actions: [
          if (_pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: '$_pendingCount action(s) en attente de sync',
                child: Stack(
                  children: [
                    const Icon(Icons.sync_rounded, color: Colors.orange),
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                        child: Text('$_pendingCount', style: const TextStyle(color: Colors.white, fontSize: 8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(onPressed: () => _fetchGoals(reset: true), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          // Bannière offline
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pendingCount > 0
                          ? 'Hors ligne — $_pendingCount action(s) en attente de synchronisation'
                          : 'Mode hors ligne — données en cache',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PERFORMANCE TRACKING',
                      style: TextStyle(color: AppColors.gold, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Architect Your\nDestiny',
                      style: TextStyle(color: AppColors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1.1)),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      _buildFilterTab(0, 'En cours', _goals.where((g) => g.status == 'pending').length.toString()),
                      const SizedBox(width: 12),
                      _buildFilterTab(1, 'Terminés', _goals.where((g) => g.status == 'completed').length.toString()),
                    ],
                  ),
                  const SizedBox(height: 30),

                  Builder(builder: (context) {
                    final filteredGoals = _goals.where((g) =>
                        _activeFilter == 0 ? g.status == 'pending' : g.status == 'completed').toList();

                    if (_isLoading) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ));
                    }
                    if (_errorMessage != null) {
                      return Center(child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.grey)),
                      ));
                    }
                    if (filteredGoals.isEmpty) {
                      return Center(child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Column(
                          children: [
                            Icon(Icons.emoji_events_outlined, color: AppColors.gold.withOpacity(0.3), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              _activeFilter == 0 ? 'Aucun objectif en cours' : 'Aucun objectif terminé',
                              style: const TextStyle(color: AppColors.grey),
                            ),
                          ],
                        ),
                      ));
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredGoals.length + (_hasMore && !_isOffline ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        if (index == filteredGoals.length) {
                          return Center(
                            child: _isLoadingMore
                                ? const CircularProgressIndicator(color: AppColors.gold)
                                : TextButton(
                                    onPressed: _fetchGoals,
                                    child: const Text('Charger plus', style: TextStyle(color: AppColors.gold)),
                                  ),
                          );
                        }
                        return _buildGoalCard(filteredGoals[index]);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.navy, size: 30),
      ),
    );
  }

  Widget _buildFilterTab(int index, String label, String count) {
    bool isActive = _activeFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: isActive ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? AppColors.navy.withOpacity(0.1) : AppColors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(count, style: TextStyle(
                color: isActive ? AppColors.navy : AppColors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    final bool isCompleted = goal.status == 'completed';
    final bool isPending = goal.id < 0; // ID temporaire = créé offline

    return Dismissible(
      key: Key('goal_${goal.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.navy,
            title: const Text('Supprimer ?', style: TextStyle(color: AppColors.white)),
            content: const Text('Voulez-vous vraiment supprimer cet objectif ?', style: TextStyle(color: AppColors.grey)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SUPPRIMER')),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _deleteGoal(goal),
      child: Container(
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.darkBlue.withOpacity(0.5) : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? Colors.orange.withOpacity(0.4)
                : isCompleted
                    ? Colors.green.withOpacity(0.3)
                    : AppColors.white.withOpacity(0.05),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: isCompleted ? null : () => _markGoalCompleted(goal),
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.transparent,
                      border: Border.all(color: isCompleted ? Colors.green : AppColors.gold, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    goal.title,
                    style: TextStyle(
                      color: isCompleted ? AppColors.grey : AppColors.white,
                      fontSize: 18, fontWeight: FontWeight.bold,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_rounded, color: Colors.orange, size: 10),
                        SizedBox(width: 3),
                        Text('EN ATTENTE', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.withOpacity(0.1) : AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCompleted ? 'TERMINÉ' : 'EN COURS',
                      style: TextStyle(color: isCompleted ? Colors.green : AppColors.gold, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            if (goal.description != null && goal.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(goal.description!, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.grey, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    goal.dueDate != null
                        ? 'Échéance: ${goal.dueDate!.day}/${goal.dueDate!.month}/${goal.dueDate!.year}'
                        : 'Créé le ${goal.createdAt.day}/${goal.createdAt.month}/${goal.createdAt.year}',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
