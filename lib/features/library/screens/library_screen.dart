import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:open_filex/open_filex.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/services/download_service.dart';
import '../../../models/library_item.dart';
import './pdf_viewer_screen.dart';
import './audio_player_screen.dart';
import './video_player_screen.dart';
import './cache_management_screen.dart';
import '../../admin/screens/library_upload_screen.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/services/cache_service.dart';

class LibraryScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const LibraryScreen({super.key, this.onNavigate});

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
  
  /// Controller pour la recherche
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  /// ScrollController pour l'infinite scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _userRole = LocalStorageService().getUserRole();
    debugPrint('📚 LibraryScreen - Role loaded: "$_userRole" | isAdmin: ${_userRole.toUpperCase() == 'ADMIN'}');
    _initCacheService();
    _fetchLibrary(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Détecte quand on arrive en bas de la liste pour charger plus
  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = 200.0; // Déclenche 200px avant la fin
    
    if (maxScroll - currentScroll <= delta) {
      _fetchLibrary();
    }
  }

  Future<void> _initCacheService() async {
    try {
      await CacheService.clearExpired(); // Nettoyer les fichiers expirés au démarrage
    } catch (e) {
      print('Erreur init cache service: $e');
    }
  }

  Future<void> _checkLocalFiles(List<LibraryItem> items) async {
    // Collecter tous les chemins d'abord, puis un seul setState
    final Map<int, String?> paths = {};
    for (final item in items) {
      final path = await _downloadService.getLocalPath(item.id, item.type);
      paths[item.id] = path;
    }
    // Un seul setState pour toutes les mises à jour
    if (mounted) {
      setState(() => _localPaths.addAll(paths));
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
    debugPrint('📚 _fetchLibrary called - reset: $reset, page: $_page');
    
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
      debugPrint('🌐 Calling API: /library?page=$_page&limit=10');
      final response = await _apiService.get('/library', queryParams: {'page': '$_page', 'limit': '10'});
      debugPrint('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['data'] ?? data;
        debugPrint('📦 Received ${raw.length} items');
        
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
      } else {
        debugPrint('❌ Error response: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage = 'Erreur serveur: ${response.statusCode}';
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception in _fetchLibrary: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Erreur: $e';
        });
      }
    }
  }

  List<LibraryItem> get _filteredItems {
    List<LibraryItem> result = _items;
    
    // Filtre par type
    if (_activeFilter != 0) {
      String typeFilter = _activeFilter == 1 ? 'pdf' : (_activeFilter == 2 ? 'audio' : 'video');
      result = result.where((item) => item.type == typeFilter).toList();
    }
    
    // Filtre par recherche texte
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) => 
        item.title.toLowerCase().contains(query) ||
        (item.description?.toLowerCase().contains(query) ?? false) ||
        (item.category?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    return result;
  }
  
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BORN TO SUCCESS ($_userRole)'),
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
              if (index != 2 && widget.onNavigate != null) {
                widget.onNavigate!(index);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Dashboard', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 1, child: Text('Goals', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 2, child: Text('Library', style: TextStyle(color: AppColors.grey)), enabled: false),
              const PopupMenuItem(value: 3, child: Text('Conferences', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 4, child: Text('Profil', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 5, child: Text('Admin', style: TextStyle(color: AppColors.gold))),
            ],
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CacheManagementScreen()),
              );
              _fetchLibrary(reset: true);
            },
            icon: const Icon(Icons.storage_rounded),
            tooltip: 'Gestion du cache',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchLibrary(reset: true),
        color: AppColors.gold,
        backgroundColor: AppColors.darkBlue,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(), // Nécessaire pour RefreshIndicator
              slivers: [
              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.darkBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: AppColors.white),
                          decoration: InputDecoration(
                            hintText: 'Rechercher une ressource...',
                            hintStyle: const TextStyle(color: AppColors.grey),
                            prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                            suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: AppColors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
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
                            child: Column(
                              children: [
                                Text(_errorMessage!, style: const TextStyle(color: AppColors.grey)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _fetchLibrary(reset: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: AppColors.navy,
                                  ),
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_filteredItems.isEmpty && !_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 50),
                            child: Text('Aucune ressource trouvée.', style: TextStyle(color: AppColors.grey)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Liste avec infinite scroll
              if (_errorMessage == null && _filteredItems.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _filteredItems.length) {
                          // Loader en fin de liste
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _isLoadingMore
                                ? const CircularProgressIndicator(color: AppColors.gold)
                                : _hasMore
                                  ? const Text(
                                      'Chargement...',
                                      style: TextStyle(color: AppColors.grey),
                                    )
                                  : const Text(
                                      'Fin de la liste',
                                      style: TextStyle(color: AppColors.grey),
                                    ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: _buildLibraryCard(_filteredItems[index]),
                        );
                      },
                      childCount: _filteredItems.length + 1,
                    ),
                  ),
                ),
              ],
            ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: SafeArea(
          child: Column(
            children: [
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
                            'Utilisateur',
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
                                'En ligne',
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
              ListTile(
                leading: const Icon(Icons.dashboard, color: AppColors.white),
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
                leading: const Icon(Icons.library_books, color: AppColors.gold),
                title: const Text('Library', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people, color: AppColors.white),
                title: const Text('Conferences', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(3);
                },
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
              if (_userRole.toUpperCase() == 'ADMIN')
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: AppColors.gold),
                  title: const Text('PANEL ADMIN', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigate?.call(5);
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: _userRole.toUpperCase() == 'ADMIN' 
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
    final fileUrl = item.url.startsWith('http') 
        ? item.url 
        : '${ApiService.baseUrl}${item.url.startsWith('/') ? '' : '/'}${item.url}';
    final isVideo = item.type == 'video';

    IconData typeIcon = isVideo
        ? Icons.play_circle_fill_rounded
        : item.type == 'pdf'
            ? Icons.picture_as_pdf_rounded
            : Icons.audiotrack_rounded;

    Color iconColor = isVideo ? Colors.blueAccent : AppColors.gold;

    return GestureDetector(
      onTap: () async {
        if (isVideo) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(title: item.title, url: fileUrl),
          ));
          return;
        }
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
          border: isVideo
              ? Border.all(color: Colors.blueAccent.withOpacity(0.3))
              : isDownloaded
                  ? Border.all(color: AppColors.gold.withOpacity(0.3))
                  : null,
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
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon, color: iconColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isVideo ? 'CONFÉRENCE' : item.type.toUpperCase(),
                                style: TextStyle(color: iconColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isVideo && item.category != null) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.access_time_rounded, color: AppColors.grey, size: 11),
                              const SizedBox(width: 2),
                              Text(item.category!, style: const TextStyle(color: AppColors.grey, fontSize: 10)),
                            ],
                            if (!isVideo && isDownloaded) ...[
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
                  // Actions
                  if (isVideo)
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.blueAccent, size: 28)
                  else if (isDownloading)
                    SizedBox(
                      width: 30, height: 30,
                      child: CircularProgressIndicator(value: progress, color: AppColors.gold, strokeWidth: 2.5),
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
