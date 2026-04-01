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

class _ConferenceScreenState extends State<ConferenceScreen> {
  final ApiService _apiService = ApiService();
  List<ConferenceItem> _conferences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConferences();
  }

  Future<void> _fetchConferences() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/conferences/active');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _conferences = data.map((json) => ConferenceItem.fromJson(json)).toList();
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
        title: const Text('BORN TO SUCCESS'),
        actions: [
          IconButton(onPressed: _fetchConferences, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Salles de Conférence',
                  style: TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rejoignez des sessions en direct ou créez votre espace.',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ),
                
                const SizedBox(height: 30),
                
                // Create Room Button
                _buildCreateRoomAction(),
                
                const SizedBox(height: 40),
                
                // Live Status Row
                const Text(
                  'En direct maintenant',
                  style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                if (_conferences.isEmpty && !_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: Text('Aucune session en cours.', style: TextStyle(color: AppColors.grey)),
                    ),
                  ),

                // Real Conference List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _conferences.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final conference = _conferences[index];
                    return _buildLiveRoom(conference);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _createRoom() async {
    final titleController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('CRÉER UNE SALLE', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(hintText: 'Nom de la conférence *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('ANNULER', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('CRÉER'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed || titleController.text.trim().isEmpty) return;

    try {
      final response = await _apiService.post('/conferences', {
        'title': titleController.text.trim(),
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final roomId = data['roomId'];
        final Uri url = Uri.parse('https://meet.jit.si/$roomId');
        if (mounted) {
          _fetchConferences();
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

  Widget _buildLiveRoom(ConferenceItem conference) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conference.title,
            style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Animé par ${conference.trainerName ?? "Leader BTS"}',
            style: const TextStyle(color: AppColors.grey, fontSize: 14),
          ),
          const SizedBox(height: 20),
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
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('REJOINDRE', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
