import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../models/conference_item.dart';
import './library_upload_screen.dart';

class ContentManagementScreen extends StatefulWidget {
  const ContentManagementScreen({super.key});

  @override
  State<ContentManagementScreen> createState() => _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // Données par type
  List<dynamic> _pdfs = [];
  List<dynamic> _audios = [];
  List<dynamic> _videos = [];
  List<ConferenceItem> _confVideos = [];

  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadCurrentTab();
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchLibrary(), _fetchConfVideos()]);
  }

  void _loadCurrentTab() {
    switch (_tabController.index) {
      case 0: case 1: case 2: _fetchLibrary(); break;
      case 3: _fetchConfVideos(); break;
    }
  }

  Future<void> _fetchLibrary() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/library', queryParams: {'limit': '100'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data'] ?? data;
        if (mounted) {
          setState(() {
            _pdfs = items.where((i) => i['type'] == 'pdf').toList();
            _audios = items.where((i) => i['type'] == 'audio').toList();
            _videos = items.where((i) => i['type'] == 'video' &&
                (i['description'] == null || !i['description'].toString().startsWith('conference:'))).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchConfVideos() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/conferences/history', queryParams: {'filter': 'all', 'limit': '50'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['data'] ?? data;
        if (mounted) {
          setState(() {
            _confVideos = raw
                .map((j) => ConferenceItem.fromJson(j))
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

  // ── Upload fichier ───────────────────────────────────────
  Future<void> _uploadContent(String type) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LibraryUploadScreen(initialType: type)),
    );
    if (result == true) _fetchLibrary();
  }

  // ── Modifier titre ───────────────────────────────────────
  void _showEditDialog(dynamic item) {
    final ctrl = TextEditingController(text: item['title'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('MODIFIER LE TITRE', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(hintText: 'Nouveau titre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateTitle(item['id'], ctrl.text.trim());
            },
            child: const Text('SAUVEGARDER'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTitle(int id, String title) async {
    if (title.isEmpty) return;
    try {
      final response = await _apiService.put('/library/$id', {'title': title});
      if (response.statusCode == 200) {
        _showSnack('Titre mis à jour ✅', Colors.green);
        _fetchLibrary();
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  // ── Supprimer contenu ────────────────────────────────────
  Future<void> _deleteItem(dynamic item) async {
    final confirmed = await _confirmDelete(item['title'] ?? '');
    if (!confirmed) return;
    try {
      final response = await _apiService.delete('/library/${item['id']}');
      if (response.statusCode == 200) {
        _showSnack('Supprimé ✅', Colors.green);
        _fetchLibrary();
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  // ── Supprimer vidéo conférence ───────────────────────────
  Future<void> _deleteConfVideo(ConferenceItem conf) async {
    final confirmed = await _confirmDelete(conf.title);
    if (!confirmed) return;
    try {
      final response = await _apiService.delete('/conferences/${conf.id}/video');
      if (response.statusCode == 200) {
        _showSnack('Vidéo supprimée ✅', Colors.green);
        _fetchConfVideos();
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  Future<bool> _confirmDelete(String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('SUPPRIMER ?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Supprimer "$name" ?\nLe fichier sera aussi supprimé de Supabase.',
            style: const TextStyle(color: AppColors.grey)),
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
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.parse(dateStr);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DU CONTENU'),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.grey,
          isScrollable: true,
          tabs: [
            Tab(text: '📄 PDF (${_pdfs.length})'),
            Tab(text: '🎵 Audio (${_audios.length})'),
            Tab(text: '🎬 Vidéo (${_videos.length})'),
            Tab(text: '📹 Conférences (${_confVideos.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildContentTab(_pdfs, 'pdf'),
                _buildContentTab(_audios, 'audio'),
                _buildContentTab(_videos, 'video'),
                _buildConfVideosTab(),
              ],
            ),
    );
  }

  Widget _buildContentTab(List<dynamic> items, String type) {
    final icons = {'pdf': Icons.picture_as_pdf_rounded, 'audio': Icons.audiotrack_rounded, 'video': Icons.videocam_rounded};
    final colors = {'pdf': Colors.redAccent, 'audio': AppColors.gold, 'video': Colors.blueAccent};
    final labels = {'pdf': 'PDF', 'audio': 'Audio', 'video': 'Vidéo'};

    return Column(
      children: [
        // Bouton ajouter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ElevatedButton.icon(
            onPressed: () => _uploadContent(type),
            icon: const Icon(Icons.add_rounded, color: AppColors.navy),
            label: Text('Ajouter un ${labels[type]}',
                style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Liste
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icons[type], color: AppColors.grey.withOpacity(0.3), size: 60),
                      const SizedBox(height: 12),
                      Text('Aucun ${labels[type]} ajouté.',
                          style: const TextStyle(color: AppColors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildItemCard(items[i], icons[type]!, colors[type]!),
                ),
        ),
      ],
    );
  }

  Widget _buildItemCard(dynamic item, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? '',
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(_formatDate(item['created_at'] ?? item['createdAt']),
                    style: const TextStyle(color: AppColors.grey, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
            onPressed: () => _showEditDialog(item),
            tooltip: 'Modifier',
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
            onPressed: () => _deleteItem(item),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }

  Widget _buildConfVideosTab() {
    return _confVideos.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off_rounded, color: AppColors.grey, size: 60),
                SizedBox(height: 12),
                Text('Aucune vidéo de conférence.', style: TextStyle(color: AppColors.grey)),
                SizedBox(height: 8),
                Text('Les vidéos apparaissent après avoir terminé\nune conférence avec un lien.',
                    style: TextStyle(color: AppColors.grey, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _confVideos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final conf = _confVideos[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                ),
                child: Row(
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
                          Text(conf.title,
                              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(
                            '${conf.createdAt.day.toString().padLeft(2, '0')}/${conf.createdAt.month.toString().padLeft(2, '0')}/${conf.createdAt.year}'
                            '${conf.trainerName != null ? ' • ${conf.trainerName}' : ''}',
                            style: const TextStyle(color: AppColors.grey, fontSize: 11),
                          ),
                          if (conf.videoUrl != null) ...[
                            const SizedBox(height: 3),
                            Text(conf.videoUrl!, style: const TextStyle(color: AppColors.gold, fontSize: 10),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteConfVideo(conf),
                      tooltip: 'Supprimer',
                    ),
                  ],
                ),
              );
            },
          );
  }
}
