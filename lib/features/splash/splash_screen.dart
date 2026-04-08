import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/res/styles.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/storage/database_service.dart';
import '../../core/network/api_service.dart';
import '../../core/widgets/main_layout.dart';
import '../auth/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Vérification authentification après l'animation
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _checkAuth();
      }
    });
  }

  Future<void> _checkAuth() async {
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
      // Hors ligne : on fait confiance au cache
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A1628),
              AppColors.navy,
              const Color(0xFF0D1F35),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo avec animation - format circulaire plein
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.4),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/img/logo.png',
                          fit: BoxFit.cover,
                          width: 160,
                          height: 160,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Texte "BORN TO SUCCESS"
                Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          'BORN TO SUCCESS',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(
                                color: AppColors.gold.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Message inspirant
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Rêvons grand et réussissons ensemble',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.gold.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Indicateur de chargement élégant
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.gold.withOpacity(0.7),
                      ),
                      backgroundColor: AppColors.gold.withOpacity(0.1),
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
