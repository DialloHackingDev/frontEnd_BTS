import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/res/styles.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/database_service.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const SettingsScreen({super.key, this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'fr';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Charger la langue sauvegardée
    final savedLang = LocalStorageService.cachedUser?['language'] ?? 'fr';
    setState(() {
      _selectedLanguage = savedLang;
      _isLoading = false;
    });
  }

  Future<void> _saveLanguage(String lang) async {
    setState(() => _selectedLanguage = lang);
    // Sauvegarder dans le cache utilisateur et SQLite
    if (LocalStorageService.cachedUser != null) {
      LocalStorageService.cachedUser!['language'] = lang;
      // Sauvegarder en base locale
      final db = await DatabaseService.db;
      await db.insert('auth', {
        'key': 'language',
        'value': lang,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang == 'fr' ? 'Langue changée en Français' : 'Language changed to English',
          style: const TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.darkBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text(
          'PARAMÈTRES',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.navy,
        elevation: 0,
        actions: [
          // Menu trois points avec navigation
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Navigation',
            onSelected: (index) {
              if (index != 7 && widget.onNavigate != null) {
                widget.onNavigate!(index);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Dashboard')),
              const PopupMenuItem(value: 1, child: Text('Goals')),
              const PopupMenuItem(value: 2, child: Text('Planning')),
              const PopupMenuItem(value: 3, child: Text('Library')),
              const PopupMenuItem(value: 4, child: Text('Conferences')),
              const PopupMenuItem(value: 5, child: Text('Profil')),
              const PopupMenuItem(value: 6, child: Text('Admin')),
              const PopupMenuItem(value: 7, child: Text('Paramètres'), enabled: false),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              onRefresh: _loadSettings,
              color: AppColors.gold,
              backgroundColor: AppColors.darkBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    _buildHeader(),
                    const SizedBox(height: 30),
                    
                    // Section Langue
                    _buildSectionTitle('LANGUE'),
                    const SizedBox(height: 15),
                    _buildLanguageCard(),
                    
                    const SizedBox(height: 40),
                    
                    // Section Informations
                    _buildSectionTitle('INFORMATIONS'),
                    const SizedBox(height: 15),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withOpacity(0.1),
            AppColors.gold.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.settings,
              color: AppColors.gold,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paramètres',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Personnalisez votre expérience',
                  style: TextStyle(
                    color: AppColors.grey.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildLanguageCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildLanguageOption(
            'fr',
            'Français',
            'Langue par défaut',
            Icons.flag,
          ),
          Divider(
            color: AppColors.white.withOpacity(0.1),
            height: 1,
            indent: 20,
            endIndent: 20,
          ),
          _buildLanguageOption(
            'en',
            'English',
            'English language',
            Icons.language,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    String code,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedLanguage == code;
    
    return InkWell(
      onTap: () => _saveLanguage(code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.gold.withOpacity(0.2)
                    : AppColors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? AppColors.gold.withOpacity(0.5)
                      : AppColors.white.withOpacity(0.1),
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.gold : AppColors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.grey.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.info_outline, 'Version', '1.0.0'),
          const SizedBox(height: 15),
          _buildInfoRow(Icons.copyright, 'BTS App', '2024'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.grey.withOpacity(0.7),
          size: 20,
        ),
        const SizedBox(width: 15),
        Text(
          label,
          style: TextStyle(
            color: AppColors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
