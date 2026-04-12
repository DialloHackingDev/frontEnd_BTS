import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../models/conference_item.dart';
import './jitsi_room_screen.dart';
import '../../library/screens/video_player_screen.dart';

import '../../../core/storage/local_storage_service.dart';

class ConferenceScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const ConferenceScreen({super.key, this.onNavigate});

  @override
  State<ConferenceScreen> createState() => _ConferenceScreenState();
}

class _ConferenceScreenState extends State<ConferenceScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<ConferenceItem> _live = [];
  List<ConferenceItem> _history = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _historyFilter = 'all';
  String _userRole = 'USER';

  @override
  void initState() {
    super.initState();
    _userRole = LocalStorageService().getUserRole();
    debugPrint('📹 ConferenceScreen - Role loaded: "$_userRole" | isAdmin: ${_userRole.toUpperCase() == 'ADMIN'}');
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
      final response = await _apiService.get('/conferences/history', queryParams: {'filter': _historyFilter});
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // Le backend retourne {data: [], total, page} ou directement []
        final List<dynamic> data = decoded is List ? decoded : (decoded['data'] ?? []);
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

  void _joinRoom(ConferenceItem conference) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JitsiRoomScreen(
          roomId: conference.roomId,
          title: conference.title,
          conferenceId: conference.id,
        ),
      ),
    );
  }

  void _showConferenceSummary(ConferenceItem conference) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec titre
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        conference.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Animé par ${conference.trainerName ?? 'Formateur'}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${conference.createdAt.day}/${conference.createdAt.month}/${conference.createdAt.year}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 20),
                
                // Section vidéo replay
                if (conference.videoUrl != null && conference.videoUrl!.isNotEmpty) ...[
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 80,
                          color: AppColors.gold.withOpacity(0.7),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REPLAY DISPONIBLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _playReplayVideo(conference.videoUrl!, conference.title);
                      },
                      icon: const Icon(Icons.play_arrow, color: Colors.black),
                      label: const Text(
                        'REGARDER LE REPLAY',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Pas de vidéo disponible
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun replay disponible',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Informations
                const Text(
                  'INFORMATIONS',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cette conférence s\'est terminée. Vous pouvez consulter le replay si disponible.',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Stats
                Row(
                  children: [
                    _buildStatChip(Icons.video_call, 'Conférence terminée'),
                    const SizedBox(width: 12),
                    _buildStatChip(Icons.calendar_today, 'Archivée'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey[300], fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _playReplayVideo(String videoUrl, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          title: title,
          url: videoUrl,
        ),
      ),
    );
  }

  Future<void> _endConference(ConferenceItem conference) async {
    String? videoUrl;
    
    // Si l'enregistrement Agora est actif, arrêter automatiquement
    if (conference.isRecording == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.navy,
          title: const Text('TERMINER LA SESSION', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          content: const Text(
            'Voulez-vous terminer cette conférence ?\n\nL\'enregistrement Agora sera arrêté automatiquement.',
            style: TextStyle(color: AppColors.white),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('TERMINER')),
          ],
        ),
      ) ?? false;
      
      if (!confirmed) return;
      
      // Arrêter l'enregistrement Agora et récupérer l'URL
      try {
        final stopResponse = await _apiService.post('/agora/recording/stop', {
          'conferenceId': conference.id,
        });
        if (stopResponse.statusCode == 200) {
          final data = jsonDecode(stopResponse.body);
          videoUrl = data['videoUrl'];
          debugPrint('✅ Enregistrement arrêté, URL: $videoUrl');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur arrêt enregistrement: $e');
      }
    } else {
      // Mode manuel (lien YouTube/Drive)
      final videoController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.navy,
          title: const Text('TERMINER LA SESSION', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lien de l\'enregistrement vidéo', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Collez ici le lien de la vidéo enregistrée (YouTube, Drive, etc.)', style: TextStyle(color: AppColors.grey, fontSize: 11)),
              const SizedBox(height: 12),
              TextField(
                controller: videoController,
                style: const TextStyle(color: AppColors.white),
                decoration: const InputDecoration(
                  hintText: 'https://youtube.com/watch?v=...',
                  prefixIcon: Icon(Icons.link_rounded, color: AppColors.gold, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Laissez vide pour terminer sans enregistrement.', style: TextStyle(color: AppColors.grey, fontSize: 10)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('TERMINER')),
          ],
        ),
      ) ?? false;

      if (!confirmed) return;
      videoUrl = videoController.text.trim();
    }

    try {
      final response = await _apiService.put(
        '/conferences/${conference.id}/end',
        {'videoUrl': videoUrl},
      );
      if (mounted) {
        if (response.statusCode == 200) {
          // Retirer immédiatement de la liste locale sans attendre le serveur
          setState(() {
            _live.removeWhere((c) => c.id == conference.id);
          });
          // Puis recharger depuis le serveur pour mettre à jour l'historique aussi
          await _fetchLive();
          await _fetchHistory();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text((videoUrl?.isNotEmpty ?? false)
                    ? 'Session terminée et vidéo enregistrée ✅'
                    : 'Session terminée ✅'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Erreur lors de la terminaison'),
              backgroundColor: Colors.red,
            ),
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

  // ── ADMIN: Supprimer une vidéo de conférence ──
  Future<void> _deleteVideo(ConferenceItem conference) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('SUPPRIMER LA VIDÉO', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          'Voulez-vous vraiment supprimer la vidéo "${conference.title}" ?\n\nCette action est irréversible.',
          style: const TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final response = await _apiService.delete('/conferences/${conference.id}/video');
      if (mounted) {
        if (response.statusCode == 200) {
          _fetchHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vidéo supprimée ✅'), backgroundColor: Colors.green),
          );
        } else {
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Erreur lors de la suppression'), backgroundColor: Colors.red),
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

  // ── ADMIN: Modifier le lien vidéo ──
  Future<void> _editVideoLink(ConferenceItem conference) async {
    final videoController = TextEditingController(text: conference.videoUrl ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('MODIFIER LE LIEN VIDÉO', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: videoController,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                prefixIcon: Icon(Icons.link_rounded, color: AppColors.gold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('MODIFIER')),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final response = await _apiService.put(
        '/conferences/${conference.id}/end',
        {'videoUrl': videoController.text.trim()},
      );
      if (mounted) {
        if (response.statusCode == 200) {
          _fetchHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lien vidéo mis à jour ✅'), backgroundColor: Colors.green),
          );
        } else {
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Erreur lors de la modification'), backgroundColor: Colors.red),
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
        if (mounted) {
          _fetchLive();
          _joinRoom(ConferenceItem.fromJson(data));
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
      backgroundColor: AppColors.navy,
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: SafeArea(
          child: Column(
            children: [
              // Header avec profil
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
              // Menu items
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
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(1);
                },
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
                onTap: () => Navigator.pop(context),
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
                  widget.onNavigate?.call(4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: AppColors.white),
                title: const Text('Paramètres', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  // Paramètres
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('BORN TO SUCCESS'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Menu trois points avec navigation
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            tooltip: 'Navigation',
            color: AppColors.navy,
            onSelected: (index) {
              if (index != 3 && widget.onNavigate != null) {
                widget.onNavigate!(index);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Dashboard', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 1, child: Text('Goals', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 2, child: Text('Library', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 3, child: Text('Conferences', style: TextStyle(color: AppColors.grey)), enabled: false),
              const PopupMenuItem(value: 4, child: Text('Profil', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 5, child: Text('Admin', style: TextStyle(color: AppColors.gold))),
            ],
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
          const Text('Lancez votre propre salle de conférence vidéo', style: TextStyle(color: AppColors.grey, fontSize: 13)),
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
            onPressed: () {
              if (isLive) {
                _joinRoom(conference);
              } else {
                _showConferenceSummary(conference);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
              backgroundColor: isLive ? AppColors.gold : AppColors.darkBlue.withOpacity(0.5),
              side: isLive ? null : const BorderSide(color: AppColors.gold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isLive ? 'REJOINDRE' : 'VOIR LE RÉSUMÉ',
              style: TextStyle(color: isLive ? AppColors.navy : AppColors.gold, fontWeight: FontWeight.bold),
            ),
          ),
          if (isLive && _userRole.toUpperCase() == 'ADMIN') ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _endConference(conference),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'TERMINER',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          // ── ADMIN: Options pour les vidéos historiques ──
          if (!isLive && conference.videoUrl != null && _userRole.toUpperCase() == 'ADMIN') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editVideoLink(conference),
                    icon: const Icon(Icons.edit, size: 16, color: AppColors.gold),
                    label: const Text('MODIFIER', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteVideo(conference),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                    label: const Text('SUPPRIMER', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
