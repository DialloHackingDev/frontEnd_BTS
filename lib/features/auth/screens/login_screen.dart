import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/network/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isLoginMode = true;
  final _authService = AuthService();

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLoginMode && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs !')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final result = _isLoginMode 
        ? await _authService.login(email, password)
        : await _authService.register(email, password, name);

      if (result['success']) {
        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const MainLayout())
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? 'Échec de l\'authentification'))
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: const BoxDecoration(color: AppColors.navy),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 80),
              _buildLogo(),
              const SizedBox(height: 30),
              const Text(
                'BORN TO SUCCESS',
                style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoginMode ? 'Architect your destiny today.' : 'Join the community of achievers.',
                style: const TextStyle(color: AppColors.grey, fontSize: 14),
              ),
              const SizedBox(height: 50),
              
              if (!_isLoginMode) ...[
                _buildTextField(
                  controller: _nameController,
                  label: 'FULL NAME',
                  hint: 'John Doe',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 20),
              ],

              _buildTextField(
                controller: _emailController,
                label: 'EMAIL ADDRESS',
                hint: 'votre@email.com',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),
              
              _buildTextField(
                controller: _passwordController,
                label: 'PASSWORD',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                isPasswordVisible: _isPasswordVisible,
                onToggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              const SizedBox(height: 30),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _handleAuth,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: AppColors.navy)
                  : Text(_isLoginMode ? 'SIGN IN' : 'CREATE ACCOUNT', 
                      style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isLoginMode ? 'Don\'t have an account?' : 'Already have an account?', 
                      style: const TextStyle(color: AppColors.grey)),
                  TextButton(
                    onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                    child: Text(_isLoginMode ? 'CREATE ONE' : 'SIGN IN', 
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: const Center(
        child: Text('BTS', style: TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !isPasswordVisible,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.grey.withOpacity(0.5)),
              prefixIcon: Icon(icon, color: AppColors.grey, size: 20),
              suffixIcon: isPassword 
                ? IconButton(icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.grey), onPressed: onToggleVisibility )
                : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}
