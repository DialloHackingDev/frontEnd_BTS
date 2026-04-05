import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';
import 'core/res/styles.dart';
import 'core/storage/local_storage_service.dart';
import 'core/storage/database_service.dart';
import 'core/network/api_service.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  try {
    await DatabaseService.db;
    await LocalStorageService.loadCache();
  } catch (e) {
    debugPrint('DB init error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BTS Mobile App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

/// Vérifie si le token est valide côté serveur avant de décider de la page initiale.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    // Lire le token depuis le cache mémoire (chargé au démarrage)
    final token = LocalStorageService.cachedToken;

    if (token == null) {
      _goToLogin();
      return;
    }

    try {
      final response = await ApiService().get('/auth/profile');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await DatabaseService.saveAuth('user', jsonEncode(data['user']));
        LocalStorageService.cachedUser = data['user'];
        _goToMain();
      } else {
        await DatabaseService.clearAll();
        LocalStorageService.cachedToken = null;
        LocalStorageService.cachedUser = null;
        _goToLogin();
      }
    } catch (e) {
      // Hors ligne : on fait confiance au cache SQLite
      _goToMain();
    }
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainLayout()),
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Écran de chargement pendant la vérification du token
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'BTS',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'BORN TO SUCCESS',
              style: TextStyle(color: AppColors.grey, fontSize: 14, letterSpacing: 2),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
