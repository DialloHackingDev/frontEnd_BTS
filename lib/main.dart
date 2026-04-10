import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';
import 'core/res/styles.dart';
import 'core/storage/local_storage_service.dart';
import 'core/storage/database_service.dart';
import 'core/network/api_service.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/splash/splash_screen.dart';
import 'core/services/data_persistence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  try {
    await DatabaseService.db;
    await LocalStorageService.loadCache();
    // Initialiser le service de persistance des données
    await DataPersistenceService().initialize();
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
    // Charger le token depuis la DB (au cas où le cache mémoire est vide)
    final token = await LocalStorageService().getTokenAsync();

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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token invalide, on efface tout
        await DatabaseService.clearAll();
        LocalStorageService.cachedToken = null;
        LocalStorageService.cachedUser = null;
        _goToLogin();
      } else {
        // Autre erreur serveur, on essaie le mode offline
        final cachedUser = await LocalStorageService().getUserAsync();
        if (cachedUser != null) {
          _goToMain();
        } else {
          _goToLogin();
        }
      }
    } catch (e) {
      // Hors ligne : on vérifie qu'on a un user en cache
      final cachedUser = await LocalStorageService().getUserAsync();
      if (cachedUser != null) {
        _goToMain();
      } else {
        _goToLogin();
      }
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
    // Splash screen professionnelle avec animation
    return const SplashScreen();
  }
}
