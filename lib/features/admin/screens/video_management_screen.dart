import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';

class VideoManagementScreen extends StatefulWidget {
  const VideoManagementScreen({super.key});

  @override
  State<VideoManagementScreen> createState() => _VideoManagementScreenState();
}

class _VideoManagementScreenState extends State<VideoManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _videos = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/admin/videos');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() { _videos = data['videos']; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Ajouter une vidéo ────────────────────────────────────
  Future<void> _showAddDialog() async {
    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.navy,
          title: const Text('AJOUTER UNE VIDÉO', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppColors.white),
                  decoration: const InputDecoration(hintText: 'Titre de la vidéo *'),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp4', 'mov', 'avi'],
                      withData: true,
                    );
                    if (result != null) setS(() => pickedFile = result.files.single);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pickedFile != null ? AppColors.gold : AppColors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.videocam_rounded,
                            color: pickedFile != null ? AppColors.gold : AppColors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickedFile?.name ?? 'Choisir un fichier MP4...',
                            style: TextStyle(
                              color: pickedFile != null ? AppColors.white : AppColors.grey,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || pickedFile == null) return;
                Navigator.pop(ctx);
                await _uploadVideo(titleCtrl.text.trim(), pickedFile!);
              },
              child: const Text('UPLOADER'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadVideo(String title, PlatformFile file) async {
    setState(() => _isUploading = true);
    try {
      http.StreamedResponse response;
      if (file.bytes != null) {
        response = await _apiService.uploadFileBytes('/admin/videos', file.bytes!, file.name, title);
      } else {
        response = await _apiService.uploadFile('/admin/videos', file.path!, title);
      }
      final body = await response.stream.bytesToString();
      if (response.statusCode == 201) {
        _showSnack('Vidéo uploadée sur Supabase ✅', Colors.green);
        _fetchVideos();
      } else {
        final data = jsonDecode(body);
        _showSnack(data['error'] ?? 'Erreur upload', Colors.red);
      }
    } catch (e) {
      _showSnack('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Modifier le titre ────────────────────────────────────
  void _showEditDialog(dynamic video) {
    final titleCtrl = TextEditingController(text: video['title'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('MODIFIER LA VIDÉO', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(hintText: 'Nouveau titre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateVideo(video['id'], titleCtrl.text.trim());
            },
            child: const Text('SAUVEGARDER'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateVideo(int id, String title) async {
    try {
      final response = await _apiService.put('/admin/videos/$id', {'title': title});
      if (response.statusCode == 200) {
        _showSnack('Titre mis à jour ✅', Colors.green);
        _fetchVideos();
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  // ── Supprimer ────────────────────────────────────────────
  Future<void> _deleteVideo(dynamic video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('SUPPRIMER ?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Supprimer "${video['title']}" ? Le fichier sera aussi supprimé de Supabase.',
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

    if (!confirmed) return;
    try {
      final response = await _apiService.delete('/admin/videos/${video['id']}');
      if (response.statusCode == 200) {
        _showSnack('Vidéo supprimée.', Colors.green);
        _fetchVideos();
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _formatDate(String dateStr) {
    final d = DateTime.parse(dateStr);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION VIDÉOS'),
        actions: [IconButton(onPressed: _fetchVideos, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _showAddDialog,
        backgroundColor: AppColors.gold,
        child: _isUploading
            ? const CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2)
            : const Icon(Icons.add_rounded, color: AppColors.navy),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _videos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off_rounded, color: AppColors.grey, size: 60),
                      SizedBox(height: 16),
                      Text('Aucune vidéo ajoutée.', style: TextStyle(color: AppColors.grey, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Appuyez sur + pour ajouter une vidéo.',
                          style: TextStyle(color: AppColors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  itemCount: _videos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final video = _videos[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkBlue,
                        borderRadius: BorderRadius.circular(16),
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
                            child: const Icon(Icons.videocam_rounded, color: Colors.blueAccent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(video['title'] ?? '',
                                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(video['createdAt'] ?? video['created_at'] ?? DateTime.now().toIso8601String()),
                                  style: const TextStyle(color: AppColors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
                            onPressed: () => _showEditDialog(video),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteVideo(video),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
