import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final _storage = LocalStorageService();
  List<dynamic> _activities = [];
  bool _isLoading = true;
  bool _isUploading = false;
  dynamic _user;

  @override
  void initState() {
    super.initState();
    _user = _storage.getUser();
    _fetchActivity();
  }

  Future<void> _fetchActivity() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/profile/activity');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _activities = data['activities'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Édition du nom ──────────────────────────────────────────
  void _showEditNameDialog() {
    final controller = TextEditingController(text: _user?['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('MODIFIER LE NOM', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(hintText: 'Votre nom complet'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateName(controller.text.trim());
            },
            child: const Text('SAUVEGARDER'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateName(String name) async {
    if (name.isEmpty) return;
    try {
      final response = await _apiService.put('/profile/update', {'name': name});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.saveUser(data['user']);
        if (mounted) setState(() => _user = data['user']);
      } else {
        _showError('Erreur lors de la mise à jour.');
      }
    } catch (e) {
      _showError('Erreur réseau.');
    }
  }

  // ── Upload avatar ───────────────────────────────────────────
  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.gold),
              title: const Text('Choisir depuis la galerie', style: TextStyle(color: AppColors.white)),
              onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.gold),
              title: const Text('Prendre une photo', style: TextStyle(color: AppColors.white)),
              onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.camera); },
            ),
            if (_user?['avatarUrl'] != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Supprimer la photo', style: TextStyle(color: Colors.redAccent)),
                onTap: () { Navigator.pop(context); _removeAvatar(); },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final response = await _apiService.uploadImage('/profile/avatar', picked.path, 'avatar');
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      if (response.statusCode == 200) {
        await _storage.saveUser(data['user']);
        if (mounted) setState(() => _user = data['user']);
      } else {
        _showError(data['error'] ?? 'Erreur upload.');
      }
    } catch (e) {
      _showError('Erreur réseau: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      final response = await _apiService.put('/profile/update', {'name': _user?['name'] ?? ''});
      // On envoie avatarUrl null via un appel dédié
      await _apiService.put('/profile/avatar/remove', {});
      if (response.statusCode == 200) {
        final updated = Map<String, dynamic>.from(_user);
        updated['avatarUrl'] = null;
        await _storage.saveUser(updated);
        if (mounted) setState(() => _user = updated);
      }
    } catch (_) {}
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ── Helpers ─────────────────────────────────────────────────
  String _avatarUrl(String? url) =>
      url != null ? (url.startsWith('http') ? url : '${ApiService.baseUrl}$url') : '';

  IconData _getIcon(String icon) {
    switch (icon) {
      case 'check_circle': return Icons.check_circle_rounded;
      case 'flag': return Icons.flag_rounded;
      case 'video_call': return Icons.video_call_rounded;
      default: return Icons.circle_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'goal': return AppColors.gold;
      case 'conference': return Colors.blueAccent;
      default: return AppColors.grey;
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    if (diff < 7) return 'Il y a $diff jours';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final avatarUrl = _user?['avatarUrl'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFIL'),
        actions: [
          IconButton(onPressed: _fetchActivity, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Card profil ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  // Avatar avec bouton caméra
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _showAvatarOptions,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.gold.withOpacity(0.15),
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(_avatarUrl(avatarUrl))
                              : null,
                          child: _isUploading
                              ? const CircularProgressIndicator(color: AppColors.gold)
                              : avatarUrl == null
                                  ? const Icon(Icons.person_rounded, color: AppColors.gold, size: 50)
                                  : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showAvatarOptions,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: AppColors.navy, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nom + bouton édition
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _user?['name'] ?? 'Utilisateur BTS',
                        style: const TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showEditNameDialog,
                        child: const Icon(Icons.edit_rounded, color: AppColors.gold, size: 18),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Text(_user?['email'] ?? '', style: const TextStyle(color: AppColors.grey, fontSize: 14)),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Text(
                      _user?['role'] ?? 'USER',
                      style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Historique ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Historique des activités', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${_activities.length} actions', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.gold))
            else if (_activities.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text('Aucune activité récente.', style: TextStyle(color: AppColors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activities.length,
                separatorBuilder: (_, __) => const Divider(color: AppColors.darkBlue, height: 1),
                itemBuilder: (_, i) {
                  final a = _activities[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getIconColor(a['type']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getIcon(a['icon']), color: _getIconColor(a['type']), size: 20),
                    ),
                    title: Text(a['title'], style: const TextStyle(color: AppColors.white, fontSize: 14)),
                    subtitle: Text(_formatDate(a['date']), style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                  );
                },
              ),

            const SizedBox(height: 30),

            // ── Déconnexion ──
            OutlinedButton.icon(
              onPressed: () async {
                await AuthService().logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: const Text('DÉCONNEXION', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
