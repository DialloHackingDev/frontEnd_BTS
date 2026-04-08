import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';
import '../../../core/services/cache_service.dart';

class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> {
  Map<String, dynamic> _stats = {
    'totalFiles': 0,
    'totalSizeMB': '0.00',
    'pdfCount': 0,
    'audioCount': 0,
    'maxSizeMB': 100,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await CacheService.getCacheStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('Vider le cache?', style: TextStyle(color: AppColors.white)),
        content: const Text(
          'Tous les fichiers téléchargés seront supprimés. Ils devront être re-téléchargés pour être consultés hors ligne.',
          style: TextStyle(color: AppColors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('VIDER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await CacheService.clearCache();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache vidé avec succès'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _clearExpired() async {
    setState(() => _isLoading = true);
    final count = await CacheService.clearExpired();
    await _loadStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count fichier(s) expiré(s) supprimé(s)'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Gestion du cache', style: TextStyle(color: AppColors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte résumé
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.storage_rounded, color: AppColors.gold, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          '${_stats['totalSizeMB']} MB',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'sur ${_stats['maxSizeMB']} MB max',
                          style: const TextStyle(color: AppColors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        // Barre de progression
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (double.tryParse(_stats['totalSizeMB']) ?? 0) / (_stats['maxSizeMB'] as int),
                            backgroundColor: AppColors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Statistiques détaillées
                  const Text(
                    'FICHIERS',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildStatCard(
                    icon: Icons.picture_as_pdf,
                    iconColor: Colors.redAccent,
                    label: 'Documents PDF',
                    value: '${_stats['pdfCount']}',
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    icon: Icons.audiotrack,
                    iconColor: Colors.blueAccent,
                    label: 'Fichiers audio',
                    value: '${_stats['audioCount']}',
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    icon: Icons.folder,
                    iconColor: AppColors.gold,
                    label: 'Total fichiers',
                    value: '${_stats['totalFiles']}',
                  ),

                  const SizedBox(height: 40),

                  // Actions
                  const Text(
                    'ACTIONS',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildActionButton(
                    icon: Icons.delete_sweep,
                    label: 'Nettoyer les fichiers expirés',
                    subtitle: 'Supprime les fichiers de plus de 7 jours',
                    onTap: _clearExpired,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.delete_forever,
                    label: 'Vider tout le cache',
                    subtitle: 'Supprime tous les fichiers téléchargés',
                    onTap: _clearCache,
                    isDangerous: true,
                  ),

                  const SizedBox(height: 30),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Les fichiers en cache sont disponibles hors connexion. Le cache se nettoie automatiquement lorsqu\'il dépasse 100 MB.',
                            style: TextStyle(color: AppColors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDangerous ? Colors.redAccent.withOpacity(0.1) : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDangerous ? Colors.redAccent.withOpacity(0.3) : AppColors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDangerous ? Colors.redAccent : AppColors.gold,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDangerous ? Colors.redAccent : AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDangerous ? Colors.redAccent.withOpacity(0.5) : AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
