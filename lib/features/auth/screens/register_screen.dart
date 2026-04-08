import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';
import '../../../core/widgets/main_layout.dart';
import '../../../core/network/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs !')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas !'), backgroundColor: Colors.red),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.register(email, password, name);
      if (result['success']) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? 'Échec de l\'inscription'), backgroundColor: Colors.red),
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
              const SizedBox(height: 50),
              _buildLogo(),
              const SizedBox(height: 30),
              const Text(
                'BORN TO SUCCESS',
                style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join the community of achievers.',
                style: TextStyle(color: AppColors.grey, fontSize: 14),
              ),
              const SizedBox(height: 40),

              _buildTextField(controller: _nameController, label: 'FULL NAME', hint: 'John Doe', icon: Icons.person_outline),
              const SizedBox(height: 20),
              _buildTextField(controller: _emailController, label: 'EMAIL ADDRESS', hint: 'votre@email.com', icon: Icons.email_outlined),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: 'PASSWORD',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                isVisible: _isPasswordVisible,
                onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _confirmPasswordController,
                label: 'CONFIRM PASSWORD',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                isVisible: _isConfirmVisible,
                onToggle: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: AppColors.navy)
                  : const Text('CREATE ACCOUNT', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16)),
              ),

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?', style: TextStyle(color: AppColors.grey)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('SIGN IN', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // Logo en bas de page
              _buildBottomLogo(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/img/logo.png',
          fit: BoxFit.cover,
          width: 120,
          height: 120,
        ),
      ),
    );
  }

  // Logo en bas de page - version discrète
  Widget _buildBottomLogo() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Opacity(
          opacity: 0.8,
          child: ClipOval(
            child: Image.asset(
              'assets/img/logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'BORN TO SUCCESS',
          style: TextStyle(
            color: AppColors.gold.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggle,
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
            obscureText: isPassword && !isVisible,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.grey.withOpacity(0.5)),
              prefixIcon: Icon(icon, color: AppColors.grey, size: 20),
              suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.grey),
                    onPressed: onToggle,
                  )
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
