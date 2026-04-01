import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../models/conference_item.dart';

class ConferenceVideosScreen extends StatefulWidget {
  const ConferenceVideosScreen({super.key});

  @override
  State<ConferenceVideosScreen> createState() => _ConferenceVideosScreenState();
}

class _ConferenceVideosScreenState extends State<ConferenceVideosScreen> {
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
      final response = await _apiService.get('/conferences/history', queryParams: {'filter': 'all', 'limit': '50'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['data'] ?? data;
        if (mounted) {
          setState(() {
            // Afficher uniquement les conférences avec une vidéo enregistrée
            _conferences = raw
                .map((json) => ConferenceItem.fromJson(json))
                .where((c) => c.videoUrl != null && c.videoUrl!.isNotEmpty)
                .toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVideo(ConferenceItem conference) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('SUPPRIMER LA VIDÉO', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          'Supprimer l\'enregistrement de "${conference.title}" ?\nCette action supprimera aussi l\'entrée dans la bibliothèque.',
          style: const TextStyle(color: AppColors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final response = await _apiService.delete('/conferences/${conference.id}/video');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vidéo supprimée ✅'), backgroundColor: Colors.green),
          );
          _fetchConferences();
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Erreur'), backgroundColor: Colors.red),
          );
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIDÉOS CONFÉRENCES', style: TextStyle(letterSpacing: 1.2)),
        actions: [
          IconButton(onPressed: _fetchConferences, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _conferences.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off_rounded, color: AppColors.grey, size: 60),
                      SizedBox(height: 16),
                      Text('Aucune vidéo enregistrée.', style: TextStyle(color: AppColors.grey, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Les vidéos apparaissent après avoir terminé\nune conférence avec un lien d\'enregistrement.',
                          style: TextStyle(color: AppColors.grey, fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _conferences.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildVideoCard(_conferences[i]),
                ),
    );
  }

  Widget _buildVideoCard(ConferenceItem conference) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.videocam_rounded, color: Colors.blueAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conference.title,
                        style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: AppColors.grey, size: 12),
                        const SizedBox(width: 4),
                        Text(_formatDate(conference.createdAt),
                            style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                      ],
                    ),
                    if (conference.trainerName != null) ...[
                      const SizedBox(height: 2),
                      Text('Par ${conference.trainerName}',
                          style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                onPressed: () => _deleteVideo(conference),
                tooltip: 'Supprimer la vidéo',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: AppColors.gold, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    conference.videoUrl ?? '',
                    style: const TextStyle(color: AppColors.gold, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
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
