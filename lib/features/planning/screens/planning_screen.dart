import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../models/event_item.dart';
import '../../../models/goal.dart';
import './event_form_screen.dart';

class PlanningScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const PlanningScreen({super.key, this.onNavigate});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final ApiService _apiService = ApiService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<EventItem>> _events = {};
  Map<DateTime, List<Goal>> _personalGoals = {};
  bool _isLoading = false;
  String _userRole = 'USER';
  DateTime? _lastFetchTime; // Pour éviter les appels trop fréquents

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _userRole = LocalStorageService().getUserRole();
    _fetchData();
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchEvents(), _fetchGoals()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchEvents() async {
    // Protection anti-spam: max un appel toutes les 2 secondes
    if (_lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff.inSeconds < 2) return;
    }
    _lastFetchTime = DateTime.now();
    
    try {
      final response = await _apiService.get('/events', queryParams: {
        'month': '${_focusedDay.month}',
        'year': '${_focusedDay.year}',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['events'] ?? [];
        final Map<DateTime, List<EventItem>> map = {};
        for (final json in raw) {
          final event = EventItem.fromJson(json);
          final key = _normalizeDate(event.startDate);
          map[key] = [...(map[key] ?? []), event];
        }
        if (mounted) setState(() => _events = map);
      }
    } catch (_) {}
  }

  Future<void> _fetchGoals() async {
    try {
      final response = await _apiService.get('/goals', queryParams: {'limit': '100'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> raw = data['data'] ?? data;
        final Map<DateTime, List<Goal>> map = {};
        for (final json in raw) {
          final goal = Goal.fromJson(json);
          if (goal.dueDate != null) {
            final key = _normalizeDate(goal.dueDate!);
            map[key] = [...(map[key] ?? []), goal];
          }
        }
        if (mounted) setState(() => _personalGoals = map);
      }
    } catch (_) {}
  }

  List<EventItem> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
  }

  List<Goal> _getGoalsForDay(DateTime day) {
    return _personalGoals[_normalizeDate(day)] ?? [];
  }

  bool _hasItems(DateTime day) {
    return _getEventsForDay(day).isNotEmpty || _getGoalsForDay(day).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : <EventItem>[];
    final selectedGoals = _selectedDay != null ? _getGoalsForDay(_selectedDay!) : <Goal>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BORN TO SUCCESS'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (_userRole.toUpperCase() == 'ADMIN')
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.gold),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventFormScreen(selectedDate: _selectedDay)),
                );
                if (result == true) _fetchData();
              },
            ),
          // Menu trois points avec navigation
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            tooltip: 'Navigation',
            color: AppColors.navy,
            onSelected: (index) {
              if (index != 2 && widget.onNavigate != null) {
                widget.onNavigate!(index);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Dashboard', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 1, child: Text('Goals', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 2, child: Text('Library', style: TextStyle(color: AppColors.grey)), enabled: false),
              const PopupMenuItem(value: 3, child: Text('Conferences', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 4, child: Text('Profil', style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 5, child: Text('Admin', style: TextStyle(color: AppColors.gold))),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: AppColors.gold,
                      child: const Icon(Icons.person, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ousmane Diallo',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'diallo.dev45@gmail.com',
                                style: TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.darkBlue, height: 1),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.dashboard, color: AppColors.gold),
                title: const Text('Dashboard', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events, color: AppColors.white),
                title: const Text('Goals', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: AppColors.gold),
                title: const Text('Planning', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.people, color: AppColors.gold),
                title: const Text('Conferences', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(3);
                },
              ),
              const Spacer(),
              const Divider(color: AppColors.darkBlue, height: 1),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person, color: AppColors.white),
                title: const Text('Mon Profil', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: AppColors.gold),
                title: const Text('Panel Admin', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate?.call(5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: AppColors.white),
                title: const Text('Paramètres', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.gold,
        backgroundColor: AppColors.darkBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // Calendrier
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                color: AppColors.darkBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TableCalendar<Object>(
                firstDay: DateTime(2024, 1, 1),
                lastDay: DateTime(2027, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                locale: 'fr_FR',
                eventLoader: (day) {
                  return [..._getEventsForDay(day), ..._getGoalsForDay(day)];
                },
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onPageChanged: (focused) {
                  _focusedDay = focused;
                  _fetchEvents();
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  defaultTextStyle: const TextStyle(color: AppColors.white),
                  weekendTextStyle: const TextStyle(color: AppColors.grey),
                  selectedDecoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  selectedTextStyle: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
                  todayDecoration: BoxDecoration(color: AppColors.gold.withOpacity(0.3), shape: BoxShape.circle),
                  todayTextStyle: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                  markerDecoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  markersMaxCount: 3,
                  markerSize: 5,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppColors.gold),
                  rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
                  headerPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AppColors.grey, fontSize: 12),
                  weekendStyle: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ),
            ),
          ),

          // Header jour sélectionné
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    _selectedDay != null
                        ? '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                        : 'Sélectionnez un jour',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                  ),
                  const Spacer(),
                  if (selectedEvents.isNotEmpty || selectedGoals.isNotEmpty)
                    Text('${selectedEvents.length + selectedGoals.length} élément(s)',
                        style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),

          // Contenu du jour
          if (_isLoading)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (selectedEvents.isEmpty && selectedGoals.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available_rounded, color: AppColors.grey.withOpacity(0.3), size: 60),
                    const SizedBox(height: 12),
                    const Text('Aucun événement ce jour', style: TextStyle(color: AppColors.grey)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (selectedEvents.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('ÉVÉNEMENTS', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    ...selectedEvents.map((e) => _buildEventCard(e)),
                  ],
                  if (selectedGoals.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('MES OBJECTIFS', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    ...selectedGoals.map((g) => _buildGoalCard(g)),
                  ],
                ]),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildEventCard(EventItem event) {
    final color = Color(event.color);
    final now = DateTime.now();
    String status = 'À venir';
    Color statusColor = AppColors.grey;
    if (event.isOngoing) { status = 'En cours'; statusColor = Colors.green; }
    else if (event.isPast) { status = 'Terminé'; statusColor = AppColors.grey; }

    return GestureDetector(
      onLongPress: _userRole.toUpperCase() == 'ADMIN' ? () => _showEventOptions(event) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            Text(event.typeIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(event.title,
                            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(event.description!, style: const TextStyle(color: AppColors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.grey, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatTime(event.startDate)} → ${_formatTime(event.endDate)} (${event.durationLabel})',
                        style: const TextStyle(color: AppColors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    final isCompleted = goal.status == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: isCompleted ? Colors.green : Colors.blueAccent, width: 4)),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? Colors.green : Colors.blueAccent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: TextStyle(
                    color: isCompleted ? AppColors.grey : AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (goal.description != null && goal.description!.isNotEmpty)
                  Text(goal.description!, style: const TextStyle(color: AppColors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isCompleted ? 'TERMINÉ' : 'OBJECTIF',
              style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventOptions(EventItem event) {
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
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.gold),
              title: const Text('Modifier', style: TextStyle(color: AppColors.white)),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EventFormScreen(event: event)));
                if (result == true) _fetchData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              title: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await _deleteEvent(event);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(EventItem event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Supprimer "${event.title}" ?', style: const TextStyle(color: AppColors.grey)),
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
      await _apiService.delete('/events/${event.id}');
      _fetchData();
    } catch (_) {}
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
