import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../models/event_item.dart';

class EventFormScreen extends StatefulWidget {
  final EventItem? event;
  final DateTime? selectedDate;

  const EventFormScreen({super.key, this.event, this.selectedDate});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final ApiService _apiService = ApiService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'general';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  int? _conferenceId;
  bool _isSaving = false;
  List<dynamic> _conferences = [];

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleCtrl.text = widget.event!.title;
      _descCtrl.text = widget.event!.description ?? '';
      _type = widget.event!.type;
      _startDate = widget.event!.startDate;
      _endDate = widget.event!.endDate;
      _conferenceId = widget.event!.conferenceId;
    } else if (widget.selectedDate != null) {
      final d = widget.selectedDate!;
      _startDate = DateTime(d.year, d.month, d.day, 9, 0);
      _endDate = DateTime(d.year, d.month, d.day, 10, 0);
    }
    _fetchConferences();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchConferences() async {
    try {
      final response = await _apiService.get('/conferences/active');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _conferences = data is List ? data : []);
      }
    } catch (_) {}
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, surface: AppColors.navy),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, surface: AppColors.navy),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startDate = dt;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = dt;
      }
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est requis.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La date de fin doit être après la date de début.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final body = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'type': _type,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        if (_conferenceId != null) 'conferenceId': _conferenceId,
      };

      final response = _isEditing
          ? await _apiService.put('/events/${widget.event!.id}', body)
          : await _apiService.post('/events', body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'Événement modifié ✅' : 'Événement créé ✅'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'MODIFIER L\'ÉVÉNEMENT' : 'NOUVEL ÉVÉNEMENT'),
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2))
          else
            TextButton(
              onPressed: _save,
              child: const Text('SAUVEGARDER', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type
            const Text('Type d\'événement', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTypeChip('general', '📅', 'Général'),
                const SizedBox(width: 8),
                _buildTypeChip('reunion', '👥', 'Réunion'),
                const SizedBox(width: 8),
                _buildTypeChip('formation', '🎓', 'Formation'),
                const SizedBox(width: 8),
                _buildTypeChip('conference', '🎥', 'Conf.'),
              ],
            ),
            const SizedBox(height: 24),

            // Titre
            const Text('Titre *', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(hintText: 'Ex: Réunion hebdomadaire BTS'),
            ),
            const SizedBox(height: 20),

            // Description
            const Text('Description', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: AppColors.white),
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Détails de l\'événement...'),
            ),
            const SizedBox(height: 24),

            // Dates
            const Text('Date et heure', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDateTimePicker('Début', _startDate, () => _pickDateTime(true)),
            const SizedBox(height: 10),
            _buildDateTimePicker('Fin', _endDate, () => _pickDateTime(false)),
            const SizedBox(height: 24),

            // Lier à une conférence
            if (_type == 'conference' && _conferences.isNotEmpty) ...[
              const Text('Lier à une conférence', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _conferenceId,
                    isExpanded: true,
                    dropdownColor: AppColors.darkBlue,
                    style: const TextStyle(color: AppColors.white),
                    hint: const Text('Sélectionner une conférence', style: TextStyle(color: AppColors.grey)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Aucune', style: TextStyle(color: AppColors.grey))),
                      ..._conferences.map((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['title'] ?? '', style: const TextStyle(color: AppColors.white)),
                      )),
                    ],
                    onChanged: (val) => setState(() => _conferenceId = val),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Bouton sauvegarder
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _isEditing ? 'MODIFIER L\'ÉVÉNEMENT' : 'CRÉER L\'ÉVÉNEMENT',
                style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String emoji, String label) {
    final isActive = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.gold : AppColors.darkBlue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? AppColors.gold : AppColors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: isActive ? AppColors.navy : AppColors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime dt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.darkBlue, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                Text(_formatDateTime(dt), style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_rounded, color: AppColors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}
