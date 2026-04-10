import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../network/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../res/styles.dart';
import '../network/api_service.dart';
import '../storage/local_storage_service.dart';
import '../storage/database_service.dart';
import '../services/offline_sync_service.dart';
import '../services/sync_service.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/conference/screens/conference_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/planning/screens/planning_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String _userName = 'Chargement...';
  String _userEmail = '';
  String _userRole = 'USER';
  bool _isOffline = false;
  bool _justReconnected = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final OfflineSyncService _syncService = OfflineSyncService();
  final SyncService _fullSyncService = SyncService();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) async {
      final wasOffline = _isOffline;
      final isNowOffline = result.contains(ConnectivityResult.none);

      if (mounted) setState(() => _isOffline = isNowOffline);

      // Retour du réseau → sync automatique
      if (wasOffline && !isNowOffline) {
        if (mounted) setState(() => _justReconnected = true);
        // Sync actions locales vers serveur
        final synced = await _syncService.syncPendingActions();
        // Sync données serveur vers SQLite
        await _fullSyncService.syncFromServer();
        if (mounted) {
          setState(() => _justReconnected = false);
          if (synced > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $synced action(s) synchronisée(s)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await ApiService().get('/auth/profile');
      debugPrint('📡 Profile response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];
        
        debugPrint('👤 User data: $user');
        debugPrint('🔑 Role from server: ${user['role']}');
        debugPrint('🔑 Role type: ${user['role']?.runtimeType}');
        
        await DatabaseService.saveAuth('user', jsonEncode(user));
        LocalStorageService.cachedUser = user;
        
        if (mounted) {
          final role = (user['role'] ?? 'USER').toString().toUpperCase();
          debugPrint('🎯 Role set to: $role');
          
          setState(() {
            _userName = user['name'] ?? 'Utilisateur BTS';
            _userEmail = user['email'] ?? '';
            _userRole = role;
            // Réinitialiser l'index si hors limites après changement de rôle
            final maxIndex = (role == 'ADMIN' ? 6 : 5);
            if (_selectedIndex > maxIndex) _selectedIndex = 0;
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        LocalStorageService.cachedToken = null;
        LocalStorageService.cachedUser = null;
        await DatabaseService.clearAll();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur profil: $e');
      // Mode hors-ligne : charger depuis SQLite
      final cached = LocalStorageService.cachedUser;
      debugPrint('📦 Cached user: $cached');
      
      if (cached != null && mounted) {
        final newRole = (cached['role'] ?? 'USER').toString().toUpperCase();
        debugPrint('🔑 Role from cache: $newRole');
        
        setState(() {
          _userName = cached['name'] ?? 'Utilisateur BTS';
          _userEmail = cached['email'] ?? '';
          _userRole = newRole;
          // Réinitialiser l'index si hors limites après changement de rôle
          final maxIndex = (newRole == 'ADMIN' ? 6 : 5);
          if (_selectedIndex > maxIndex) _selectedIndex = 0;
        });
      }
    }
  }

  List<Widget> get _pages {
    final pages = [
      DashboardScreen(onNavigate: _onItemTapped),
      GoalsScreen(onNavigate: _onItemTapped),
      PlanningScreen(onNavigate: _onItemTapped),
      LibraryScreen(onNavigate: _onItemTapped),
      ConferenceScreen(onNavigate: _onItemTapped),
      ProfileScreen(onNavigate: _onItemTapped),
    ];
    debugPrint('🔍 _pages getter - _userRole: $_userRole, isAdmin: ${_userRole.toUpperCase() == 'ADMIN'}');
    if (_userRole.toUpperCase() == 'ADMIN') {
      pages.add(AdminDashboardScreen(onNavigate: _onItemTapped));
      debugPrint('👑 Admin page ajoutée - Total pages: ${pages.length}');
    }
    return pages;
  }
  
  /// Récupère la page à l'index demandé avec vérification ADMIN
  Widget _getPageAt(int index) {
    final pages = _pages;
    
    // Log pour debug
    debugPrint('📱 getPageAt: index=$index, _userRole=$_userRole, totalPages=${pages.length}');
    
    // Sécurité: index hors limites
    if (index < 0 || index >= pages.length) {
      debugPrint('⚠️ Index hors limites, retour au Dashboard');
      return pages[0];
    }
    
    // Vérification spéciale pour Admin (index 6)
    if (index == 6 && _userRole.toUpperCase() != 'ADMIN') {
      debugPrint('🚫 Accès Admin refusé - rôle: $_userRole');
      return pages[0]; // Retour au Dashboard
    }
    
    return pages[index];
  }

  void _onItemTapped(int index) {
    debugPrint('👆 _onItemTapped called with index: $index, _userRole: $_userRole');
    
    // Paramètres (index 7) est géré séparément
    if (index == 7) {
      _openSettings();
      return;
    }
    
    // Vérifier l'accès Admin - index 6 est réservé aux ADMIN
    final isAdmin = _userRole.toUpperCase() == 'ADMIN';
    debugPrint('🔐 Checking access: index=$index, isAdmin=$isAdmin');
    
    if (index == 6 && !isAdmin) {
      debugPrint('🚫 Accès refusé - Rôle requis: ADMIN, Rôle actuel: $_userRole');
      return; // Ne rien faire si l'utilisateur n'est pas admin
    }
    
    debugPrint('✅ Navigation autorisée vers index: $index');
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.darkBlue),
              accountName: Row(
                children: [
                  Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isOffline ? Colors.red : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              accountEmail: Text(_isOffline ? 'Mode Hors-ligne' : _userEmail),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: AppColors.gold,
                child: Icon(Icons.person, color: AppColors.navy),
              ),
            ),
            if (_userRole.toUpperCase() == 'ADMIN')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold),
                title: const Text('PANEL ADMIN', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 6);
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.grey),
              title: const Text('PARAMÈTRES', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('DÉCONNEXION', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () async {
                await AuthService().logout();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginScreen())
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Bannière réseau globale
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: (_isOffline || _justReconnected) ? 36 : 0,
            color: _justReconnected ? Colors.green.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _justReconnected ? Icons.sync_rounded : Icons.wifi_off_rounded,
                  color: Colors.white, size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  _justReconnected
                      ? 'Reconnecté — synchronisation en cours...'
                      : 'Mode hors ligne — données en cache',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            child: _getPageAt(_selectedIndex),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.white.withOpacity(0.05), width: 1),
          ),
        ),
        child: Builder(
          builder: (context) {
            final items = [
              const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
              const BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Goals'),
              const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Planning'),
              const BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
              const BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Conferences'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
              if (_userRole.toUpperCase() == 'ADMIN')
                const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Admin'),
            ];
            // Protéger contre l'index hors limites
            final safeIndex = _selectedIndex.clamp(0, items.length - 1);
            return BottomNavigationBar(
              items: items,
              currentIndex: safeIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.darkBlue,
              selectedItemColor: AppColors.gold,
              unselectedItemColor: AppColors.grey.withOpacity(0.5),
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
            );
          },
        ),
      ),
    );
  }
}
