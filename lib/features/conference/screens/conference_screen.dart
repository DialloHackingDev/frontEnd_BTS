import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../models/conference_item.dart';

class ConferenceScreen extends StatefulWidget {
  const ConferenceScreen({super.key});

  @override
  State<ConferenceScreen> createState() => _ConferenceScreenState();
}

class _ConferenceScreenState extends State<ConferenceScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<ConferenceItem> _live = [];
  List<ConferenceItem> _history = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _historyFilter = 'all'; // 'week', 'month', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 1 && _history.isEmpty) {
          _fetchHistory();
        }
      }
    });
    _fetchLive();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLive() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/conferences/active');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _live = data.map((json) => ConferenceItem.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/conferences/history?filter=$_historyFilter');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _history = data.map((json) => ConferenceItem.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _endConference(ConferenceItem conference) async {
    final videoController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('TERMINER LA SESSION', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lien de l\'enregistrement (optionnel)', style: TextStyle(color: AppColors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: videoController,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(hintText: 'https://...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('TERMINER')),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;
    try {
      await _apiService.put('/conferences/${conference.id}/end', {'videoUrl': videoController.text.trim()});
      if (mounted) {
        _fetchLive();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session terminée et enregistrée ✅'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createRoom() async {
    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('CRÉER UNE SALLE', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(hintText: 'Nom de la conférence *'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CRÉER')),
        ],
      ),
    ) ?? false;

    if (!confirmed || titleController.text.trim().isEmpty) return;

    try {
      final response = await _apiService.post('/conferences', {'title': titleController.text.trim()});
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final Uri url = Uri.parse('https://meet.jit.si/${data['roomId']}');
        if (mounted) {
          _fetchLive();
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Impossible d\'ouvrir Jitsi Meet.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BORN TO SUCCESS'),
        actions: [
          IconButton(
            onPressed: () => _tabController.index == 0 ? _fetchLive() : _fetchHistory(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.grey,
          tabs: const [
            Tab(text: 'EN DIRECT'),
            Tab(text: 'HISTORIQUE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildLiveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _buildCreateRoomAction(),
          const SizedBox(height: 30),
          const Text('Sessions actives', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isLoading && _tabController.index == 0)
            const Center(child: CircularProgressIndicator(color: AppColors.gold))
          else if (_live.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 30),
                child: Text('Aucune session en cours.', style: TextStyle(color: AppColors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _live.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _buildConferenceCard(_live[i], isLive: true),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Filtres
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              _buildFilterChip('week', 'Cette semaine'),
              const SizedBox(width: 8),
              _buildFilterChip('month', 'Ce mois'),
              const SizedBox(width: 8),
              _buildFilterChip('all', 'Tout'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading && _tabController.index == 1
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _history.isEmpty
              ? const Center(child: Text('Aucune conférence dans l\'historique.', style: TextStyle(color: AppColors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildConferenceCard(_history[i], isLive: false),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isActive = _historyFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _historyFilter = value);
        _fetchHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.navy : AppColors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRoomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Icon(Icons.video_call_rounded, color: AppColors.gold, size: 40),
          const SizedBox(height: 16),
          const Text('Créer une Session', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Lancez votre propre salle Jitsi Meet', style: TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _createRoom,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CRÉER UNE SALLE', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildConferenceCard(ConferenceItem conference, {required bool isLive}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
        border: isLive ? Border.all(color: AppColors.gold.withOpacity(0.2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(conference.title, style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 8),
                      SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Animé par ${conference.trainerName ?? "Leader BTS"}',
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          ),
          Text(
            '${conference.createdAt.day}/${conference.createdAt.month}/${conference.createdAt.year}',
            style: const TextStyle(color: AppColors.grey, fontSize: 11),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final Uri url = Uri.parse('https://meet.jit.si/${conference.roomId}');
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impossible d\'ouvrir la conférence.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
              backgroundColor: isLive ? AppColors.gold : AppColors.darkBlue.withOpacity(0.5),
              side: isLive ? null : const BorderSide(color: AppColors.gold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isLive ? 'REJOINDRE' : 'REVOIR',
              style: TextStyle(color: isLive ? AppColors.navy : AppColors.gold, fontWeight: FontWeight.bold),
            ),
          ),
          if (isLive) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _endConference(conference),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('TERMINER & ENREGISTRER', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
