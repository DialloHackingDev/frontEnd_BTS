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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await DatabaseService.saveAuth('user', jsonEncode(data['user']));
        LocalStorageService.cachedUser = data['user'];
        if (mounted) {
          setState(() {
            _userName = data['user']['name'] ?? 'Utilisateur BTS';
            _userEmail = data['user']['email'] ?? '';
            _userRole = data['user']['role'] ?? 'USER';
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
      debugPrint('Erreur profil: $e');
      // Mode hors-ligne : charger depuis SQLite
      final cached = LocalStorageService.cachedUser;
      if (cached != null && mounted) {
        setState(() {
          _userName = cached['name'] ?? 'Utilisateur BTS';
          _userEmail = cached['email'] ?? '';
          _userRole = cached['role'] ?? 'USER';
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
    if (_userRole == 'ADMIN') {
      pages.add(AdminDashboardScreen(onNavigate: _onItemTapped));
    }
    return pages;
  }

  void _onItemTapped(int index) {
    // Paramètres (index 7) est géré séparément
    if (index == 7) {
      _openSettings();
      return;
    }
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
            if (_userRole == 'ADMIN')
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
            child: _pages[_selectedIndex],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.white.withOpacity(0.05), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            const BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Goals'),
            const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Planning'),
            const BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
            const BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Conferences'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
            if (_userRole == 'ADMIN')
              const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Admin'),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.darkBlue,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.grey.withOpacity(0.5),
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
        ),
      ),
    );
  }
}
