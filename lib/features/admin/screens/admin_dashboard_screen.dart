import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import './user_management_screen.dart';
import './library_upload_screen.dart';
import './conference_videos_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<double>? _newUsersData;
  List<double>? _retentionData;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    setState(() => _isLoading = true);
    try {
      final statsRes = await _apiService.get('/admin/stats');
      final engageRes = await _apiService.get('/admin/engagement');

      if (statsRes.statusCode == 200 && engageRes.statusCode == 200) {
        final statsData = jsonDecode(statsRes.body);
        final engageData = jsonDecode(engageRes.body);

        setState(() {
          _stats = statsData;
          _newUsersData = (engageData['newUsers'] as List).map((e) => (e as num).toDouble()).toList();
          _retentionData = (engageData['retention'] as List).map((e) => (e as num).toDouble()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('ADMIN PANEL', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _fetchAdminData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 30),
                  _buildStatsGrid(),
                  const SizedBox(height: 40),
                  const Text(
                    'ENGAGEMENT UTILISATEURS',
                    style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 20),
                  _buildLineChart(),
                  const SizedBox(height: 40),
                  _buildPortfolioSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Statistiques Globales', style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        const Text('Vue d\'ensemble de la croissance BTS', style: TextStyle(color: AppColors.grey, fontSize: 14)),
        SizedBox(height: 10),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
          icon: const Icon(Icons.manage_accounts_rounded, size: 18),
          label: const Text('Gérer Utilisateurs'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold, foregroundColor: AppColors.navy,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryUploadScreen())),
          icon: const Icon(Icons.library_add_rounded, size: 18),
          label: const Text('Ajouter Contenu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkBlue, foregroundColor: AppColors.gold,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: AppColors.gold, width: 1),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConferenceVideosScreen())),
          icon: const Icon(Icons.videocam_rounded, size: 18),
          label: const Text('Vidéos Conférences'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkBlue, foregroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: Colors.blueAccent, width: 1),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('UTILISATEURS', _stats?['totalUsers']['value'].toString() ?? '0', _stats?['totalUsers']['growth'] ?? '+0%', Icons.people_rounded),
        _buildStatCard('COURS ACTIFS', _stats?['activeCourses']['value'].toString() ?? '0', _stats?['activeCourses']['growth'] ?? '+0', Icons.auto_stories_rounded),
        _buildStatCard('BIBLIOTHÈQUE', _stats?['libraryDownloads']['value'] ?? '0', _stats?['libraryDownloads']['growth'] ?? '0', Icons.download_rounded),
        _buildStatCard('CONFÉRENCES', _stats?['conferenceHours']['value'].toString() ?? '0', 'Live', Icons.video_call_rounded),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String growth, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.gold, size: 20),
              Text(growth, style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: AppColors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    if (_newUsersData == null) return const SizedBox();
    
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _newUsersData!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: AppColors.gold,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.gold.withOpacity(0.1)),
            ),
            LineChartBarData(
              spots: _retentionData!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: AppColors.grey,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Portfolio Contenu', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                _buildLegendItem('Vidéos', AppColors.gold, '65%'),
                _buildLegendItem('Audio', AppColors.grey, '20%'),
                _buildLegendItem('PDF', Colors.blueGrey, '15%'),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 100,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(color: AppColors.gold, value: 65, radius: 10, showTitle: false),
                    PieChartSectionData(color: AppColors.grey, value: 20, radius: 10, showTitle: false),
                    PieChartSectionData(color: Colors.blueGrey, value: 15, radius: 10, showTitle: false),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
