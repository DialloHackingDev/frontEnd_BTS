import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _targetAll = true;
  List<dynamic> _users = [];
  Set<int> _selectedUserIds = {};
  bool _isSending = false;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchHistory();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await _apiService.get('/admin/users');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _users = data['users'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await _apiService.get('/notifications');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _history = data['notifications'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _sendNotification() async {
    if (_titleCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titre et message requis.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!_targetAll && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un destinataire.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final response = await _apiService.post('/notifications/send', {
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'targetAll': _targetAll,
        if (!_targetAll) 'targetIds': _selectedUserIds.toList(),
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (mounted) {
          _titleCtrl.clear();
          _messageCtrl.clear();
          setState(() => _selectedUserIds = {});
          _fetchHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notification envoyée à ${data['sentTo']} membre(s) ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatDate(String dateStr) {
    final d = DateTime.parse(dateStr);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NOTIFICATIONS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Formulaire envoi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ENVOYER UNE NOTIFICATION',
                      style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppColors.white),
                    decoration: const InputDecoration(hintText: 'Titre de la notification *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageCtrl,
                    style: const TextStyle(color: AppColors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Message...'),
                  ),
                  const SizedBox(height: 16),

                  // Destinataires
                  const Text('Destinataires', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTargetChip(true, Icons.groups_rounded, 'Tous les membres'),
                      const SizedBox(width: 10),
                      _buildTargetChip(false, Icons.person_search_rounded, 'Personnalisé'),
                    ],
                  ),

                  // Sélection individuelle
                  if (!_targetAll) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _users.length,
                        itemBuilder: (_, i) {
                          final user = _users[i];
                          final isSelected = _selectedUserIds.contains(user['id']);
                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            activeColor: AppColors.gold,
                            checkColor: AppColors.navy,
                            title: Text(user['name'] ?? '', style: const TextStyle(color: AppColors.white, fontSize: 13)),
                            subtitle: Text(user['email'] ?? '', style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedUserIds.add(user['id']);
                                } else {
                                  _selectedUserIds.remove(user['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    if (_selectedUserIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${_selectedUserIds.length} membre(s) sélectionné(s)',
                            style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                      ),
                  ],

                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendNotification,
                    icon: _isSending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: AppColors.navy),
                    label: Text(
                      _isSending ? 'Envoi...' : 'ENVOYER',
                      style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Historique
            const Text('HISTORIQUE', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 12),

            if (_history.isEmpty)
              const Center(child: Text('Aucune notification envoyée.', style: TextStyle(color: AppColors.grey)))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final n = _history[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_rounded, color: AppColors.gold, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(n['title'] ?? '', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (n['targetAll'] == true ? Colors.green : Colors.blueAccent).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                n['targetAll'] == true ? 'TOUS' : 'CIBLÉ',
                                style: TextStyle(
                                  color: n['targetAll'] == true ? Colors.green : Colors.blueAccent,
                                  fontSize: 9, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(n['message'] ?? '', style: const TextStyle(color: AppColors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(_formatDate(n['createdAt'] ?? n['created_at'] ?? DateTime.now().toIso8601String()),
                            style: const TextStyle(color: AppColors.grey, fontSize: 10)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetChip(bool value, IconData icon, String label) {
    final isActive = _targetAll == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _targetAll = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.gold : AppColors.navy,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? AppColors.gold : AppColors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? AppColors.navy : AppColors.grey, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: isActive ? AppColors.navy : AppColors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
