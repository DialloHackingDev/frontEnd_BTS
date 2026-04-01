import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
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
  int _activeFilter = 0; // 0: Tous, 1: PDF, 2: Audio, 3: Vidéo
  String _userRole = 'USER';

  @override
  void initState() {
    super.initState();
    _userRole = LocalStorageService().getUserRole();
    _fetchLibrary();
  }

  Future<void> _fetchLibrary() async {
    if (mounted) setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _apiService.get('/library');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _items = data.map((json) => LibraryItem.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_items.isEmpty) {
            _errorMessage = 'Connexion requise pour la première fois.';
          }
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
          IconButton(onPressed: _fetchLibrary, icon: const Icon(Icons.refresh_rounded)),
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
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildLibraryCard(item);
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
              if (result == true) _fetchLibrary();
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
    return GestureDetector(
      onTap: () {
        if (item.type == 'pdf') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                title: item.title,
                url: item.url.startsWith('http') ? item.url : '${ApiService.baseUrl}${item.url}',
              ),
            ),
          );
        } else if (item.type == 'audio') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioPlayerScreen(
                title: item.title,
                url: item.url.startsWith('http') ? item.url : '${ApiService.baseUrl}${item.url}',
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
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
                  Text(item.type.toUpperCase(), style: const TextStyle(color: AppColors.grey, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded, color: AppColors.gold, size: 30),
          ],
        ),
      ),
    );
  }
}
