import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../models/goal.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final ApiService _apiService = ApiService();
  List<Goal> _goals = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _activeFilter = 0; // 0 for En cours, 1 for Terminés
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGoals();
  }

  Future<void> _fetchGoals() async {
    if (mounted) setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _apiService.get('/goals');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _goals = data.map((json) => Goal.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_goals.isEmpty) {
            _errorMessage = 'Connexion requise pour la première synchronisation.';
          }
        });
      }
    }
  }

  Future<void> _addGoal(BuildContext dialogContext) async {
    if (_titleController.text.trim().isEmpty) return;

    try {
      final response = await _apiService.post('/goals', {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
      });

      if (response.statusCode == 201) {
        _titleController.clear();
        _descController.clear();
        if (mounted) {
          Navigator.of(dialogContext).pop();
          _fetchGoals();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Objectif ajouté avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('Error adding goal: status ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la sauvegarde. Vérifiez votre connexion.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('NOUVEL OBJECTIF', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            child: const Text('AJOUTER'),
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
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PERFORMANCE TRACKING',
              style: TextStyle(color: AppColors.gold, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Architect Your\nDestiny',
              style: TextStyle(color: AppColors.white, fontSize: 36, fontWeight: FontWeight.bold, height: 1.1),
            ),
            const SizedBox(height: 30),
            
            // Filter Tabs
            Row(
              children: [
                _buildFilterTab(0, 'En cours', _goals.where((g) => g.status == 'pending').length.toString()),
                const SizedBox(width: 12),
                _buildFilterTab(1, 'Terminés', _goals.where((g) => g.status == 'completed').length.toString()),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Goals List
            Builder(builder: (context) {
              final filteredGoals = _goals.where((g) {
                return _activeFilter == 0 ? g.status == 'pending' : g.status == 'completed';
              }).toList();

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
                itemCount: filteredGoals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final goal = filteredGoals[index];
                  return _buildGoalCard(goal);
                },
              );
            }),
          ],
        ),
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
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.navy : AppColors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? AppColors.navy.withOpacity(0.1) : AppColors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count,
                style: TextStyle(
                  color: isActive ? AppColors.navy : AppColors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markGoalCompleted(int goalId) async {
    try {
      final response = await _apiService.put('/goals/$goalId', {'status': 'completed'});
      if (response.statusCode == 200) {
        _fetchGoals();
      }
    } catch (e) {
      debugPrint('Error updating goal: $e');
    }
  }

  Future<void> _deleteGoal(int goalId) async {
    try {
      final response = await _apiService.delete('/goals/$goalId');
      if (response.statusCode == 200) {
        _fetchGoals();
      }
    } catch (e) {
      debugPrint('Error deleting goal: $e');
    }
  }

  Widget _buildGoalCard(Goal goal) {
    final bool isCompleted = goal.status == 'completed';
    return Dismissible(
      key: Key('goal_${goal.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
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
      onDismissed: (_) => _deleteGoal(goal.id),
      child: Container(
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.darkBlue.withOpacity(0.5) : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? Colors.green.withOpacity(0.3) : AppColors.white.withOpacity(0.05),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: isCompleted ? null : () => _markGoalCompleted(goal.id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.transparent,
                      border: Border.all(
                        color: isCompleted ? Colors.green : AppColors.gold,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    goal.title,
                    style: TextStyle(
                      color: isCompleted ? AppColors.grey : AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.withOpacity(0.1) : AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCompleted ? 'TERMINÉ' : 'EN COURS',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : AppColors.gold,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (goal.description != null && goal.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(
                  goal.description!,
                  style: const TextStyle(color: AppColors.grey, fontSize: 14),
                ),
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
