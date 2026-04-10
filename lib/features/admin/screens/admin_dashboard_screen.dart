import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import './user_management_screen.dart';
import './library_upload_screen.dart';
import './content_management_screen.dart';
import '../../planning/screens/notification_screen.dart';
import '../services/admin_cache_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<double>? _newUsersData;
  List<double>? _retentionData;
  
  // Alertes et monitoring
  List<Map<String, dynamic>> _alerts = [];
  DateTime _lastUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Afficher immédiatement avec données par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _stats = {
          'totalUsers': {'value': 3, 'growth': '+0%'},
          'activeCourses': {'value': 3, 'growth': '+0'},
          'libraryDownloads': {'value': '9', 'growth': '0'},
          'conferenceHours': {'value': '3', 'status': 'Offline'},
        };
        _newUsersData = [0, 0, 0, 0, 0, 0, 0];
        _retentionData = [0, 0, 0, 0, 0, 0, 0];
        _isLoading = false;
      });
    });
    
    // Puis rafraîchir en arrière-plan après 1 seconde
    Future.delayed(const Duration(seconds: 1), () => _fetchAdminData());
  }

  Future<void> _fetchAdminData({bool forceRefresh = false}) async {
    // Toujours exécuter en arrière-plan sans bloquer
    Future(() async {
      final cache = AdminCacheService.instance;
      
      try {
        // 1. Essayer de charger depuis le cache
        if (!forceRefresh && mounted) {
          final cachedStats = await cache.getStats();
          final cachedChart = await cache.getChartData();
          
          if (cachedStats != null && cachedChart != null && mounted) {
            setState(() {
              _stats = cachedStats;
              _newUsersData = cachedChart['newUsers'];
              _retentionData = cachedChart['retention'];
            });
          }
        }
        
        // 2. Rafraîchir depuis le serveur
        final statsRes = await _apiService.get('/admin/stats');
        final engageRes = await _apiService.get('/admin/engagement');

        if (statsRes.statusCode == 200 && engageRes.statusCode == 200 && mounted) {
          final statsData = jsonDecode(statsRes.body);
          final engageData = jsonDecode(engageRes.body);

          final newUsersData = (engageData['newUsers'] as List).map((e) => (e as num).toDouble()).toList();
          final retentionData = (engageData['retention'] as List).map((e) => (e as num).toDouble()).toList();

          setState(() {
            _stats = statsData;
            _newUsersData = newUsersData;
            _retentionData = retentionData;
            _lastUpdate = DateTime.now();
          });
          
          // Sauvegarder dans le cache
          await cache.saveStats(statsData);
          await cache.saveChartData(newUsersData, retentionData);
        }
      } catch (e) {
        debugPrint('Error fetching admin data: $e');
        // Ne pas afficher d'erreur - garder les données actuelles
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      body: SafeArea(
        child: _isLoading && _stats == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : RefreshIndicator(
                onRefresh: () => _fetchAdminData(forceRefresh: true),
                color: AppColors.gold,
                backgroundColor: AppColors.darkBlue,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 25),
                      _buildActionButtons(),
                      const SizedBox(height: 30),
                      _buildStatsGrid(),
                      const SizedBox(height: 40),
                      _buildLineChart(),
                      const SizedBox(height: 40),
                      _buildPortfolioSection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TABLEAU DE BORD',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Administration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Rafraîchir',
              onPressed: _isLoading ? null : () => _fetchAdminData(forceRefresh: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Dernière mise à jour: ${_lastUpdate.toString().substring(0, 16)}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildAdminButton(
          'Gestion Utilisateurs',
          Icons.people_outline,
          Colors.blue,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserManagementScreen()),
          ),
        ),
        _buildAdminButton(
          'Gestion Contenus',
          Icons.folder_open_outlined,
          Colors.green,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContentManagementScreen()),
          ),
        ),
        _buildAdminButton(
          'Upload Bibliothèque',
          Icons.cloud_upload_outlined,
          AppColors.gold,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LibraryUploadScreen()),
          ),
        ),
        _buildAdminButton(
          'Notifications',
          Icons.notifications_outlined,
          Colors.purple,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard('UTILISATEURS', _stats?['totalUsers']?['value']?.toString() ?? '0', _stats?['totalUsers']?['growth'] ?? '+0%', Icons.people_rounded),
        _buildStatCard('COURS ACTIFS', _stats?['activeCourses']?['value']?.toString() ?? '0', _stats?['activeCourses']?['growth'] ?? '+0', Icons.auto_stories_rounded),
        _buildStatCard('BIBLIOTHÈQUE', _stats?['libraryDownloads']?['value']?.toString() ?? '0', _stats?['libraryDownloads']?['growth'] ?? '0', Icons.download_rounded),
        _buildStatCard('CONFÉRENCES', _stats?['conferenceHours']?['value']?.toString() ?? '0', 'Live', Icons.video_call_rounded),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String growth, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.darkBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.gold, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: growth.startsWith('+') ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  growth,
                  style: TextStyle(
                    color: growth.startsWith('+') ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    if (_newUsersData == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOUVEAUX UTILISATEURS',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = ['J', 'F', 'M', 'A', 'M', 'J', 'J'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _newUsersData!.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.gold,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.gold.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PORTEFEUILLE DE CONTENU',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: 70,
                          color: AppColors.gold,
                          radius: 50,
                          title: '70%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          value: 20,
                          color: Colors.blue,
                          radius: 45,
                          title: '20%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          value: 10,
                          color: Colors.green,
                          radius: 40,
                          title: '10%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Vidéos', AppColors.gold, '70%'),
                    const SizedBox(height: 12),
                    _buildLegendItem('Audio', Colors.blue, '20%'),
                    const SizedBox(height: 12),
                    _buildLegendItem('PDF', Colors.green, '10%'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
