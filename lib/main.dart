import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'core/res/styles.dart';
import 'core/storage/local_storage_service.dart';
import 'core/network/api_service.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalStorageService().init();
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
    final storage = LocalStorageService();
    final token = storage.getToken();

    if (token == null) {
      _goToLogin();
      return;
    }

    try {
      // Valide le token côté serveur
      final response = await ApiService().get('/auth/profile');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Met à jour le cache utilisateur avec les données fraîches
        await storage.saveUser(data['user']);
        _goToMain();
      } else {
        // Token invalide ou expiré
        await storage.clearAll();
        _goToLogin();
      }
    } catch (e) {
      // Hors ligne : on fait confiance au cache local
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
