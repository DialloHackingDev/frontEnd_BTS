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
                _buildFilterTab(0, 'En cours', '12'),
                const SizedBox(width: 12),
                _buildFilterTab(1, 'Terminés', '48'),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Goals List
            _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.grey)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _goals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final goal = _goals[index];
                        return _buildGoalCard(goal);
                      },
                    ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // Add Goal Dialog
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

  Widget _buildGoalCard(Goal goal) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('HIGH PRIORITY', style: TextStyle(color: AppColors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.description ?? 'No description provided.',
                  style: const TextStyle(color: AppColors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.grey, size: 14),
                    const SizedBox(width: 8),
                    const Text('Sept 24, 2024', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                    const Spacer(),
                    const CircleAvatar(radius: 10, child: Text('JD', style: TextStyle(fontSize: 8))),
                    const SizedBox(width: -4),
                    const CircleAvatar(radius: 10, backgroundColor: AppColors.gold, child: Text('+2', style: TextStyle(fontSize: 8, color: AppColors.navy))),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.65,
                    backgroundColor: AppColors.navy,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
