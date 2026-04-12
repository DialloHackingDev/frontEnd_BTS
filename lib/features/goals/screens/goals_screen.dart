import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import 'dart:convert';

class GoalsScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const GoalsScreen({super.key, this.onNavigate});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _filteredGoals = [];
  bool _isLoading = true;
  int _activeFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/goals?limit=100');
      debugPrint('Goals API Response: ${response.statusCode} - ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _goals = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _filterGoals();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement goals: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterGoals() {
    setState(() {
      if (_activeFilter == 0) {
        _filteredGoals = _goals;
      } else if (_activeFilter == 1) {
        _filteredGoals = _goals.where((g) => g['status'] != 'completed').toList();
      } else {
        _filteredGoals = _goals.where((g) => g['status'] == 'completed').toList();
      }
    });
  }

  Future<void> _toggleGoalStatus(Map<String, dynamic> goal) async {
    final newStatus = goal['status'] == 'completed' ? 'pending' : 'completed';
    try {
      await _apiService.put('/goals/${goal['id']}', {'status': newStatus});
      setState(() {
        goal['status'] = newStatus;
        _filterGoals();
      });
    } catch (e) {
      debugPrint('Erreur toggle goal: $e');
    }
  }

  Future<void> _deleteGoal(int id) async {
    try {
      await _apiService.delete('/goals/$id');
      setState(() {
        _goals.removeWhere((g) => g['id'] == id);
        _filterGoals();
      });
    } catch (e) {
      debugPrint('Erreur delete goal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('BORN TO SUCCESS'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            tooltip: 'Navigation',
            color: AppColors.navy,
            onSelected: (index) {
              if (index != 1 && widget.onNavigate != null) {
                widget.onNavigate!(index);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Dashboard', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 1, child: Text('Goals', style: TextStyle(color: AppColors.grey)), enabled: false),
              const PopupMenuItem(value: 2, child: Text('Library', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 3, child: Text('Conferences', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 4, child: Text('Profil', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 5, child: Text('Admin', style: TextStyle(color: AppColors.gold))),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: AppColors.gold,
                      child: const Icon(Icons.person, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ousmane Diallo',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'diallo.dev45@gmail.com',
                                style: TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.darkBlue, height: 1),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.dashboard, color: AppColors.gold),
                title: const Text('Dashboard', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events, color: AppColors.white),
                title: const Text('Goals', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.library_books, color: AppColors.white),
                title: const Text('Library', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people, color: AppColors.gold),
                title: const Text('Conferences', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(3);
                },
              ),
              const Spacer(),
              const Divider(color: AppColors.darkBlue, height: 1),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person, color: AppColors.white),
                title: const Text('Mon Profil', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: AppColors.gold),
                title: const Text('Panel Admin', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: AppColors.white),
                title: const Text('Paramètres', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildFilterChip(0, 'Tous', Icons.all_inclusive),
                    const SizedBox(width: 8),
                    _buildFilterChip(1, 'En cours', Icons.timelapse),
                    const SizedBox(width: 8),
                    _buildFilterChip(2, 'Terminés', Icons.check_circle),
                  ],
                ),
              ),
              Expanded(
                child: _filteredGoals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events, color: AppColors.grey.withOpacity(0.5), size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun objectif',
                            style: TextStyle(color: AppColors.grey, fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredGoals.length,
                      itemBuilder: (context, index) {
                        final goal = _filteredGoals[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildGoalCard(goal),
                        );
                      },
                    ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: AppColors.navy),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    bool isActive = _activeFilter == index;
    return GestureDetector(
      onTap: () => setState(() {
        _activeFilter = index;
        _filterGoals();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? AppColors.navy : AppColors.grey, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.navy : AppColors.grey,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('NOUVEL OBJECTIF', style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Titre de l\'objectif',
                  hintStyle: TextStyle(color: AppColors.grey.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppColors.darkBlue,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppColors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Description (optionnelle)',
                  hintStyle: TextStyle(color: AppColors.grey.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppColors.darkBlue,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty) {
                      await _addGoal(titleController.text, descController.text);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('CRÉER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addGoal(String title, String description) async {
    try {
      final response = await _apiService.post('/goals', {
        'title': title,
        'description': description.isEmpty ? null : description,
      });
      if (response.statusCode == 201) {
        await _loadGoals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Objectif créé avec succès'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur add goal: $e');
    }
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final isCompleted = goal['status'] == 'completed';
    return Dismissible(
      key: Key(goal['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteGoal(goal['id']),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleGoalStatus(goal),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.gold : Colors.transparent,
                  border: Border.all(color: isCompleted ? AppColors.gold : AppColors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isCompleted ? const Icon(Icons.check, color: AppColors.navy, size: 18) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal['title'] ?? '',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.grey,
                    ),
                  ),
                  if (goal['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      goal['description']!,
                      style: TextStyle(color: AppColors.grey, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(DateTime.tryParse(goal['createdAt'] ?? '') ?? DateTime.now()),
                    style: TextStyle(color: AppColors.grey.withOpacity(0.6), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
