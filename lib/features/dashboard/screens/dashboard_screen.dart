import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _MainDashboard {
  final int total;
  final int completed;
  final int percentage;

  _MainDashboard({required this.total, required this.completed, required this.percentage});
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  _MainDashboard? _stats;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/dashboard/stats');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats = _MainDashboard(
            total: data['total'],
            completed: data['completed'],
            percentage: data['percentage'],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.gold,
            child: Icon(Icons.person, color: AppColors.navy),
          ),
        ),
        title: const Text('BORN TO SUCCESS'),
        actions: [
          IconButton(
            onPressed: _fetchStats,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bonjour, Leader',
                        style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Prêt pour une nouvelle étape vers l\'excellence ?',
                        style: TextStyle(color: AppColors.grey, fontSize: 14),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Progress Card
                      _buildProgressCard(),
                      
                      const SizedBox(height: 40),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Objectifs de la semaine',
                            style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Voir tout', style: TextStyle(color: AppColors.grey)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildGoalItem(
                        title: 'Analyse de Performance',
                        dateLabel: 'DANS 2 JOURS',
                        icon: Icons.psychology_rounded,
                      ),
                      const SizedBox(height: 15),
                      _buildGoalItem(
                        title: 'Réunion Stratégique',
                        dateLabel: 'AUJOURD\'HUI',
                        icon: Icons.groups_rounded,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROGRÈS HEBDO',
                    style: TextStyle(color: AppColors.gold, letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_stats?.completed ?? 0} / ${_stats?.total ?? 0}',
                    style: const TextStyle(color: AppColors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_stats?.percentage ?? 0}% COMPLÉTÉ',
                  style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_stats?.percentage ?? 0) / 100,
              minHeight: 10,
              backgroundColor: AppColors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem({required String title, required String dateLabel, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.gold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
