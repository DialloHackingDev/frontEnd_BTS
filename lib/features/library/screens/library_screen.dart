import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _activeFilter = 0; // 0: Tous, 1: PDF, 2: Audio, 3: Vidéo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: NetworkImage('https://via.placeholder.com/150'),
          ),
        ),
        title: const Text('BORN TO SUCCESS'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher une ressource...',
                  prefixIcon: Icon(Icons.search, color: AppColors.grey),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
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
            
            const Text(
              'Ressources à la une',
              style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Featured Resource Card (Masterclass)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1557804506-669a67965ba0?auto=format&fit=crop&q=80&w=1074'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('MASTERCLASS', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Psychologie de\nl\'Investissement',
                      style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 35),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ma Bibliothèque',
                  style: TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('VOIR TOUT >', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Library List
            _buildLibraryCard(
              title: 'Négociation de...',
              subtitle: 'Série Audio • 12 MB',
              type: 'audio',
              isAction: true,
              actionLabel: 'LECTURE',
            ),
            const SizedBox(height: 15),
            _buildLibraryCard(
              title: 'Guide de la Performance 2...',
              subtitle: 'TÉLÉCHARGÉ',
              type: 'pdf',
              isStatus: true,
            ),
            const SizedBox(height: 15),
            _buildLibraryCard(
              title: 'Modèle de Business Plan',
              subtitle: 'Document • 450 KB',
              type: 'pdf',
              isDownload: true,
            ),
          ],
        ),
      ),
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
          style: TextStyle(
            color: isActive ? AppColors.navy : AppColors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryCard({
    required String title,
    required String subtitle,
    required String type,
    bool isAction = false,
    String actionLabel = '',
    bool isStatus = false,
    bool isDownload = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.audiotrack_rounded,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isStatus ? AppColors.gold : AppColors.grey,
                    fontSize: 12,
                    fontWeight: isStatus ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isAction)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          if (isDownload)
            const Icon(Icons.download_for_offline_rounded, color: AppColors.grey),
          if (isStatus)
            const Icon(Icons.more_vert_rounded, color: AppColors.grey),
        ],
      ),
    );
  }
}
