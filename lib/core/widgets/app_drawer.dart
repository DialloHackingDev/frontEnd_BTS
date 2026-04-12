import 'package:flutter/material.dart';
import '../res/styles.dart';
import '../network/api_service.dart';
import '../storage/local_storage_service.dart';
import 'dart:convert';

class AppDrawer extends StatefulWidget {
  final Function(int)? onNavigate;
  final int currentIndex;
  
  const AppDrawer({
    super.key,
    this.onNavigate,
    this.currentIndex = -1,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = '';
  String _userEmail = '';
  String? _avatarUrl;
  String _userRole = 'USER';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = LocalStorageService().getUser();
    setState(() {
      _userName = user?['name'] ?? 'Utilisateur';
      _userEmail = user?['email'] ?? '';
      _avatarUrl = user?['avatarUrl'] ?? user?['avatar_url'];
      _userRole = user?['role']?.toString().toUpperCase() ?? 'USER';
    });
  }

  String _buildAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiService.baseUrl}$url';
  }

  void _navigateTo(int index) {
    Navigator.pop(context);
    if (widget.onNavigate != null && index != widget.currentIndex) {
      widget.onNavigate!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.navy,
      child: SafeArea(
        child: Column(
          children: [
            // Header avec profil utilisateur
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 35,
                        backgroundColor: AppColors.gold,
                        backgroundImage: NetworkImage(_buildAvatarUrl(_avatarUrl)),
                      )
                    : CircleAvatar(
                        radius: 35,
                        backgroundColor: AppColors.gold,
                        child: const Icon(Icons.person, color: Colors.white, size: 36),
                      ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
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
                            Expanded(
                              child: Text(
                                _userEmail,
                                style: TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (_userRole == 'ADMIN') ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: AppColors.darkBlue, height: 1),
            
            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildMenuItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    index: 0,
                  ),
                  _buildMenuItem(
                    icon: Icons.emoji_events_rounded,
                    label: 'Goals',
                    index: 1,
                  ),
                  _buildMenuItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Planning',
                    index: 2,
                  ),
                  _buildMenuItem(
                    icon: Icons.people_alt_rounded,
                    label: 'Conferences',
                    index: 3,
                  ),
                  const Divider(color: AppColors.darkBlue, indent: 20, endIndent: 20, height: 24),
                  _buildMenuItem(
                    icon: Icons.person_rounded,
                    label: 'Mon Profil',
                    index: -1,
                    onTap: () => _navigateToProfile(),
                  ),
                  if (_userRole == 'ADMIN')
                    _buildMenuItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Panel Admin',
                      index: 4,
                      isSpecial: true,
                    ),
                  _buildMenuItem(
                    icon: Icons.settings_rounded,
                    label: 'Paramètres',
                    index: -1,
                    onTap: () => _navigateToSettings(),
                  ),
                ],
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Divider(color: AppColors.darkBlue, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: AppColors.gold, size: 8),
                      const SizedBox(width: 8),
                      Text(
                        'BORN TO SUCCESS',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 10,
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

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required int index,
    bool isSpecial = false,
    VoidCallback? onTap,
  }) {
    final isSelected = index == widget.currentIndex;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppColors.gold.withOpacity(0.2) 
            : isSpecial
              ? AppColors.gold.withOpacity(0.1)
              : AppColors.darkBlue.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon, 
          color: isSelected || isSpecial ? AppColors.gold : AppColors.white,
          size: 22,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected || isSpecial ? AppColors.gold : AppColors.white,
          fontWeight: isSelected || isSpecial ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      trailing: isSelected 
        ? const Icon(Icons.arrow_forward_ios, color: AppColors.gold, size: 14)
        : null,
      onTap: onTap ?? () => _navigateTo(index),
    );
  }

  void _navigateToProfile() {
    Navigator.pop(context);
    // Navigation vers profil via le popup menu index 4
    if (widget.onNavigate != null) {
      widget.onNavigate!(4);
    }
  }

  void _navigateToSettings() {
    Navigator.pop(context);
    // Navigation vers paramètres via le popup menu index 5
    if (widget.onNavigate != null) {
      widget.onNavigate!(5);
    }
  }
}
