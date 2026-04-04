import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/storage/local_storage_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _users = [];
  String _searchQuery = '';
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorageService().getUser()?['id'];
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/admin/users');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() { _users = data['users']; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Créer un utilisateur ─────────────────────────────────
  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'USER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.navy,
          title: const Text('NOUVEL UTILISATEUR', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Nom complet', Icons.person_outline),
                const SizedBox(height: 12),
                _dialogField(emailCtrl, 'Email', Icons.email_outlined),
                const SizedBox(height: 12),
                _dialogField(passCtrl, 'Mot de passe', Icons.lock_outline, obscure: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Rôle :', style: TextStyle(color: AppColors.grey)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('USER'),
                      selected: role == 'USER',
                      onSelected: (_) => setS(() => role = 'USER'),
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(color: role == 'USER' ? AppColors.navy : AppColors.grey),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ADMIN'),
                      selected: role == 'ADMIN',
                      onSelected: (_) => setS(() => role = 'ADMIN'),
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(color: role == 'ADMIN' ? AppColors.navy : AppColors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _createUser(nameCtrl.text.trim(), emailCtrl.text.trim(), passCtrl.text.trim(), role);
              },
              child: const Text('CRÉER'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser(String name, String email, String password, String role) async {
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Email et mot de passe requis.', Colors.red);
      return;
    }
    try {
      final response = await _apiService.post('/admin/users', {
        'name': name, 'email': email, 'password': password, 'role': role
      });
      if (response.statusCode == 201) {
        _showSnack('Utilisateur créé avec succès ✅', Colors.green);
        _fetchUsers();
      } else {
        final data = jsonDecode(response.body);
        _showSnack(data['error'] ?? 'Erreur', Colors.red);
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  // ── Modifier un utilisateur ──────────────────────────────
  void _showEditDialog(dynamic user) {
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final passCtrl = TextEditingController();
    String role = user['role'] ?? 'USER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.navy,
          title: const Text('MODIFIER UTILISATEUR', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Nom complet', Icons.person_outline),
                const SizedBox(height: 12),
                _dialogField(emailCtrl, 'Email', Icons.email_outlined),
                const SizedBox(height: 12),
                _dialogField(passCtrl, 'Nouveau mot de passe (optionnel)', Icons.lock_outline, obscure: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Rôle :', style: TextStyle(color: AppColors.grey)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('USER'),
                      selected: role == 'USER',
                      onSelected: (_) => setS(() => role = 'USER'),
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(color: role == 'USER' ? AppColors.navy : AppColors.grey),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ADMIN'),
                      selected: role == 'ADMIN',
                      onSelected: (_) => setS(() => role = 'ADMIN'),
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(color: role == 'ADMIN' ? AppColors.navy : AppColors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final body = <String, dynamic>{
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'role': role,
                };
                if (passCtrl.text.trim().isNotEmpty) body['password'] = passCtrl.text.trim();
                await _updateUser(user['id'], body);
              },
              child: const Text('SAUVEGARDER'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/admin/users/$id', data);
      if (response.statusCode == 200) {
        _showSnack('Utilisateur mis à jour ✅', Colors.green);
        _fetchUsers();
      } else {
        final d = jsonDecode(response.body);
        _showSnack(d['error'] ?? 'Erreur', Colors.red);
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  // ── Supprimer un utilisateur ─────────────────────────────
  Future<void> _deleteUser(dynamic user) async {
    if (user['id'] == _currentUserId) {
      _showSnack('Vous ne pouvez pas supprimer votre propre compte.', Colors.orange);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('SUPPRIMER ?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Supprimer ${user['name']} ? Cette action est irréversible.', style: const TextStyle(color: AppColors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;
    try {
      final response = await _apiService.delete('/admin/users/${user['id']}');
      if (response.statusCode == 200) {
        _showSnack('Utilisateur supprimé.', Colors.green);
        _fetchUsers();
      } else {
        final d = jsonDecode(response.body);
        _showSnack(d['error'] ?? 'Erreur', Colors.red);
      }
    } catch (e) {
      _showSnack('Erreur réseau', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.grey, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
    }).toList();

    final adminCount = _users.where((u) => u['role'] == 'ADMIN').length;

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('GESTION UTILISATEURS'),
        actions: [
          IconButton(onPressed: _fetchUsers, icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: const TextStyle(color: AppColors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.darkBlue,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.person_add_rounded, color: AppColors.navy),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Column(
              children: [
                // Compteurs
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      _buildCounter('Total', _users.length.toString(), AppColors.white),
                      const SizedBox(width: 12),
                      _buildCounter('Admins', adminCount.toString(), AppColors.gold),
                      const SizedBox(width: 12),
                      _buildCounter('Membres', (_users.length - adminCount).toString(), AppColors.grey),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildUserCard(filtered[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final bool isAdmin = user['role'] == 'ADMIN';
    final bool isMe = user['id'] == _currentUserId;
    final String? avatarUrl = user['avatarUrl'];
    final String avatarFullUrl = avatarUrl != null
        ? (avatarUrl.startsWith('http') ? avatarUrl : '${ApiService.baseUrl}$avatarUrl')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isAdmin ? AppColors.gold.withOpacity(0.3) : AppColors.white.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isAdmin ? AppColors.gold.withOpacity(0.15) : AppColors.grey.withOpacity(0.1),
          backgroundImage: avatarFullUrl.isNotEmpty ? NetworkImage(avatarFullUrl) : null,
          onBackgroundImageError: avatarFullUrl.isNotEmpty ? (_, __) {} : null,
          child: avatarFullUrl.isEmpty
              ? Icon(isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                  color: isAdmin ? AppColors.gold : AppColors.grey)
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${user['name'] ?? 'Inconnu'}${isMe ? ' (moi)' : ''}',
                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                ),
                child: const Text('ADMIN', style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text(user['email'] ?? '', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.grey),
          color: AppColors.darkBlue,
          onSelected: (value) {
            if (value == 'edit') _showEditDialog(user);
            if (value == 'delete') _deleteUser(user);
            if (value == 'promote') _updateUser(user['id'], {'role': 'ADMIN'});
            if (value == 'demote') _updateUser(user['id'], {'role': 'USER'});
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text('Modifier', style: TextStyle(color: AppColors.white)),
            ])),
            if (!isAdmin) const PopupMenuItem(value: 'promote', child: Row(children: [
              Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text('Promouvoir Admin', style: TextStyle(color: AppColors.white)),
            ])),
            if (isAdmin && !isMe) const PopupMenuItem(value: 'demote', child: Row(children: [
              Icon(Icons.person_rounded, color: Colors.orangeAccent, size: 18),
              SizedBox(width: 8),
              Text('Rétrograder', style: TextStyle(color: AppColors.white)),
            ])),
            if (!isMe) const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
              SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
