import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:open_filex/open_filex.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/download_service.dart';
import '../../../models/library_item.dart';
import './pdf_viewer_screen.dart';
import './audio_player_screen.dart';
import '../../admin/screens/library_upload_screen.dart';
import '../../../core/storage/local_storage_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ApiService _apiService = ApiService();
  List<LibraryItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _activeFilter = 0;
  String _userRole = 'USER';
  final DownloadService _downloadService = DownloadService();
  final Map<int, double?> _downloadProgress = {};
  final Map<int, String?> _localPaths = {};
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _userRole = LocalStorageService().getUserRole();
    _fetchLibrary(reset: true);
  }

  Future<void> _checkLocalFiles(List<LibraryItem> items) async {
    for (final item in items) {
      final path = await _downloadService.getLocalPath(item.id, item.type);
      if (mounted) setState(() => _localPaths[item.id] = path);
    }
  }

  Future<void> _handleDownload(LibraryItem item) async {
    final url = item.url.startsWith('http') ? item.url : '${ApiService.baseUrl}${item.url}';
    setState(() => _downloadProgress[item.id] = 0.0);
    try {
      final path = await _downloadService.download(
        item.id, url, item.type,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress[item.id] = p);
        },
      );
      if (mounted) {
        setState(() {
          _downloadProgress.remove(item.id);
          _localPaths[item.id] = path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement terminé ✅'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(item.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDelete(LibraryItem item) async {
    await _downloadService.delete(item.id, item.type);
    if (mounted) setState(() => _localPaths[item.id] = null);
  }

  Future<void> _fetchLibrary({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _items = [];
    }
    if (!_hasMore) return;

    if (mounted) {
      setState(() => reset ? _isLoading = true : _isLoadingMore = true);
    }

    try {
      final response = await _apiService.get('/library', queryParams: {'page': '$_page', 'limit': '10'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['data'] ?? data;
        if (mounted) {
          final newItems = raw.map((json) => LibraryItem.fromJson(json)).toList();
          setState(() {
            _items.addAll(newItems);
            _hasMore = _page < (data['totalPages'] ?? 1);
            _page++;
            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage = null;
          });
          _checkLocalFiles(newItems);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          if (_items.isEmpty) _errorMessage = 'Connexion requise pour la première fois.';
        });
      }
    }
  }

  List<LibraryItem> get _filteredItems {
    if (_activeFilter == 0) return _items;
    String typeFilter = _activeFilter == 1 ? 'pdf' : (_activeFilter == 2 ? 'audio' : 'video');
    return _items.where((item) => item.type == typeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BORN TO SUCCESS'),
        actions: [
          IconButton(onPressed: () => _fetchLibrary(reset: true), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(16)),
                  child: const TextField(
                    style: TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une ressource...',
                      hintStyle: TextStyle(color: AppColors.grey),
                      prefixIcon: Icon(Icons.search, color: AppColors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(0, 'Tous'),
                      const SizedBox(width: 10),
                      _buildFilterChip(1, 'PDF'),
                      const SizedBox(width: 10),
                      _buildFilterChip(2, 'Audio'),
                      const SizedBox(width: 10),
                      _buildFilterChip(3, 'Vidéo'),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.grey)),
                    ),
                  )
                else if (_filteredItems.isEmpty && !_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 50),
                      child: Text('Aucune ressource trouvée.', style: TextStyle(color: AppColors.grey)),
                    ),
                  ),

                if (_errorMessage == null)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredItems.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      if (index == _filteredItems.length) {
                        return Center(
                          child: _isLoadingMore
                            ? const CircularProgressIndicator(color: AppColors.gold)
                            : TextButton(
                                onPressed: _fetchLibrary,
                                child: const Text('Charger plus', style: TextStyle(color: AppColors.gold)),
                              ),
                        );
                      }
                      return _buildLibraryCard(_filteredItems[index]);
                    },
                  ),
              ],
            ),
          ),
      floatingActionButton: _userRole == 'ADMIN' 
        ? FloatingActionButton(
            backgroundColor: AppColors.gold,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LibraryUploadScreen()),
              );
              if (result == true) _fetchLibrary(reset: true);
            },
            child: const Icon(Icons.add, color: AppColors.navy),
          )
        : null,
    );
  }

  Widget _buildFilterChip(int index, String label) {
    bool isActive = _activeFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(color: isActive ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLibraryCard(LibraryItem item) {
    final localPath = _localPaths[item.id];
    final isDownloaded = localPath != null;
    final progress = _downloadProgress[item.id];
    final isDownloading = progress != null;
    final fileUrl = item.url.startsWith('http') ? item.url : '${ApiService.baseUrl}${item.url}';

    return GestureDetector(
      onTap: () {
        if (isDownloaded) {
          OpenFilex.open(localPath);
          return;
        }
        if (item.type == 'pdf') {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PdfViewerScreen(title: item.title, url: fileUrl),
          ));
        } else if (item.type == 'audio') {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AudioPlayerScreen(title: item.title, url: fileUrl),
          ));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
          border: isDownloaded ? Border.all(color: AppColors.gold.withOpacity(0.3)) : null,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.audiotrack_rounded,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(item.type.toUpperCase(), style: const TextStyle(color: AppColors.grey, fontSize: 10)),
                            if (isDownloaded) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.offline_pin_rounded, color: AppColors.gold, size: 12),
                              const SizedBox(width: 2),
                              const Text('OFFLINE', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Bouton download / delete
                  if (isDownloading)
                    SizedBox(
                      width: 30, height: 30,
                      child: CircularProgressIndicator(
                        value: progress,
                        color: AppColors.gold,
                        strokeWidth: 2.5,
                      ),
                    )
                  else if (isDownloaded)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                      onPressed: () => _handleDelete(item),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: AppColors.gold, size: 22),
                      onPressed: () => _handleDownload(item),
                    ),
                ],
              ),
            ),
            // Barre de progression
            if (isDownloading)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: AppColors.white.withOpacity(0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
