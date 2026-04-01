import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../network/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../res/styles.dart';
import '../network/api_service.dart';
import '../storage/local_storage_service.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/conference/screens/conference_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';

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
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      setState(() {
        _isOffline = result.contains(ConnectivityResult.none);
      });
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
        await LocalStorageService().saveUser(data['user']);
        if (mounted) {
          setState(() {
            _userName = data['user']['name'] ?? 'Utilisateur BTS';
            _userEmail = data['user']['email'] ?? '';
            _userRole = data['user']['role'] ?? 'USER';
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expiré ou invalide → déconnexion forcée
        await AuthService().logout();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint('Erreur profil: $e');
      // Mode hors-ligne : charger depuis le cache
      final cached = LocalStorageService().getUser();
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
      const DashboardScreen(),
      const GoalsScreen(),
      const LibraryScreen(),
      const ConferenceScreen(),
    ];
    if (_userRole == 'ADMIN') {
      pages.add(const AdminDashboardScreen());
    }
    return pages;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                  Navigator.pop(context); // close drawer
                  // Navigate to admin tab
                  final adminIndex = 4;
                  setState(() => _selectedIndex = adminIndex);
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
      body: _pages[_selectedIndex],
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
            const BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
            const BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Conferences'),
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
