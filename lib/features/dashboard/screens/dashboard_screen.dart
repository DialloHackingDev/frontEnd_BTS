import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../models/goal.dart';
import '../../../models/library_item.dart';
import '../../../models/event_item.dart';
import '../../library/screens/pdf_viewer_screen.dart';
import '../../library/screens/audio_player_screen.dart';
import '../../library/screens/video_player_screen.dart';
import '../../profile/screens/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  int _total = 0, _completed = 0, _percentage = 0;
  List<Goal> _pendingGoals = [];
  List<EventItem> _upcomingEvents = [];
  List<LibraryItem> _pdfs = [];
  List<LibraryItem> _audios = [];
  List<LibraryItem> _videos = [];
  List<LibraryItem> _confVideos = [];

  bool _isLoading = true;
  String _userName = '';
  String? _avatarUrl;
  String _userEmail = '';

  /// Construit l'URL complète de l'avatar
  String _buildAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiService.baseUrl}$url';
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadUserProfile();
    _fetchAll();
  }

  void _loadUserProfile() async {
    final user = LocalStorageService().getUser();
    setState(() {
      _userName = user?['name'] ?? 'Leader';
      _userEmail = user?['email'] ?? '';
      _avatarUrl = user?['avatarUrl'] ?? user?['avatar_url'];
    });
    
    // Charger le profil complet depuis l'API
    try {
      final response = await ApiService().get('/auth/profile');
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        setState(() {
          _userName = userData['name'] ?? _userName;
          _userEmail = userData['email'] ?? _userEmail;
          _avatarUrl = userData['avatarUrl'] ?? userData['avatar_url'] ?? _avatarUrl;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchStats(), _fetchGoals(), _fetchEvents(), _fetchLibrary()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _animCtrl.forward(from: 0);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final r = await _api.get('/dashboard/stats');
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (mounted) setState(() {
          _total = d['total'] ?? 0;
          _completed = d['completed'] ?? 0;
          _percentage = d['percentage'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchGoals() async {
    try {
      final r = await _api.get('/goals', queryParams: {'limit': '5'});
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final List<dynamic> items = d['data'] ?? d;
        if (mounted) setState(() {
          _pendingGoals = items
              .map((j) => Goal.fromJson(j))
              .where((g) => g.status == 'pending')
              .take(3)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchEvents() async {
    try {
      final now = DateTime.now();
      final r = await _api.get('/events', queryParams: {'month': '${now.month}', 'year': '${now.year}'});
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final List<dynamic> raw = d['events'] ?? [];
        final today = DateTime(now.year, now.month, now.day);
        if (mounted) setState(() {
          _upcomingEvents = raw
              .map((j) => EventItem.fromJson(j))
              .where((e) {
                final eDay = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
                return !eDay.isBefore(today);
              })
              .take(3)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchLibrary() async {
    try {
      final r = await _api.get('/library', queryParams: {'limit': '20'});
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final List<dynamic> raw = d['data'] ?? d;
        final items = raw.map((j) => LibraryItem.fromJson(j)).toList();
        if (mounted) setState(() {
          _pdfs = items.where((i) => i.type == 'pdf').take(6).toList();
          _audios = items.where((i) => i.type == 'audio').take(6).toList();
          _videos = items.where((i) => i.type == 'video' &&
              (i.description == null || !i.description!.startsWith('conference:'))).take(6).toList();
          _confVideos = items.where((i) => i.type == 'video' &&
              i.description != null && i.description!.startsWith('conference:')).take(6).toList();
        });
      }
    } catch (_) {}
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  void _openItem(LibraryItem item) {
    final url = item.url.startsWith('http') ? item.url : '${ApiService.baseUrl}${item.url}';
    if (item.type == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(title: item.title, url: url)));
    } else if (item.type == 'audio') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AudioPlayerScreen(title: item.title, url: url)));
    } else if (item.type == 'video') {
      if (item.isConferenceVideo) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(title: item.title, url: url)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: Column(
          children: [
            // Header avec profil utilisateur
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Row(
                children: [
                  _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.gold,
                        backgroundImage: NetworkImage(_buildAvatarUrl(_avatarUrl)),
                        child: null,
                      )
                    : CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.gold,
                        child: const Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
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
                            Text(
                              _userEmail,
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
            const SizedBox(height: 20),
            // Profil utilisateur
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: AppColors.gold, size: 24),
              ),
              title: const Text(
                'MON PROFIL',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Modifier mes informations',
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(onNavigate: widget.onNavigate),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Panel Admin
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 24),
              ),
              title: const Text(
                'PANEL ADMIN',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onNavigate?.call(5); // Index Admin (dans main_layout)
              },
            ),
            const SizedBox(height: 8),
            // Paramètres
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings, color: AppColors.white, size: 24),
              ),
              title: const Text(
                'PARAMÈTRES',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // Paramètres
              },
            ),
            const Spacer(),
            const Divider(color: AppColors.darkBlue, height: 1),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('DÉCONNEXION', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                // Déconnexion
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.darkBlue,
                onRefresh: _fetchAll,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeroSection(),
                          const SizedBox(height: 28),
                          _buildProgressCard(),
                          if (_upcomingEvents.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('📅', 'ÉVÉNEMENTS À VENIR'),
                            const SizedBox(height: 14),
                            ..._upcomingEvents.map((e) => _buildEventCard(e)),
                          ],
                          if (_pendingGoals.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('✅', 'MES TÂCHES EN COURS'),
                            const SizedBox(height: 14),
                            ..._pendingGoals.map((g) => _buildGoalCard(g)),
                          ],
                          if (_pdfs.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('📄', 'PDF RÉCENTS'),
                            const SizedBox(height: 14),
                            _buildCarousel(_pdfs, Icons.picture_as_pdf_rounded, const Color(0xFFEF4444)),
                          ],
                          if (_audios.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('🎵', 'AUDIO RÉCENTS'),
                            const SizedBox(height: 14),
                            _buildCarousel(_audios, Icons.audiotrack_rounded, AppColors.gold),
                          ],
                          if (_videos.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('🎬', 'VIDÉOS'),
                            const SizedBox(height: 14),
                            _buildCarousel(_videos, Icons.videocam_rounded, const Color(0xFF3B82F6)),
                          ],
                          if (_confVideos.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('📹', 'VIDÉOS CONFÉRENCES'),
                            const SizedBox(height: 14),
                            _buildCarousel(_confVideos, Icons.video_library_rounded, const Color(0xFFA855F7)),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: AppColors.navy,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: AppColors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text('BORN TO SUCCESS',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
      actions: [
        // Menu trois points avec navigation
        PopupMenuButton<int>(
          icon: const Icon(Icons.more_vert, color: AppColors.white),
          tooltip: 'Navigation',
          onSelected: (index) {
            if (index != 0 && widget.onNavigate != null) {
              widget.onNavigate!(index);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 0, child: Text('Dashboard', style: TextStyle(color: AppColors.grey)), enabled: false),
            const PopupMenuItem(value: 1, child: Text('Goals', style: TextStyle(color: AppColors.white))),
            const PopupMenuItem(value: 2, child: Text('Library', style: TextStyle(color: AppColors.white))),
            const PopupMenuItem(value: 3, child: Text('Conferences', style: TextStyle(color: AppColors.white))),
            const PopupMenuItem(value: 4, child: Text('Profil', style: TextStyle(color: AppColors.white))),
            if (LocalStorageService().getUserRole().toUpperCase() == 'ADMIN')
              const PopupMenuItem(value: 5, child: Text('Admin', style: TextStyle(color: AppColors.gold))),
          ],
        ),
      ],
    );
  }

  // ── Hero Section ─────────────────────────────────────────
  Widget _buildHeroSection() {
    final now = DateTime.now();
    final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    final dateStr = '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateStr, style: const TextStyle(color: AppColors.grey, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$_greeting, ',
                style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w300),
              ),
              TextSpan(
                text: _userName,
                style: const TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('Prêt pour une nouvelle étape vers l\'excellence ?',
            style: TextStyle(color: AppColors.grey, fontSize: 13)),
      ],
    );
  }

  // ── Progress Card ────────────────────────────────────────
  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkBlue, AppColors.darkBlue.withBlue(60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PROGRÈS HEBDOMADAIRE',
                      style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_completed',
                          style: const TextStyle(color: AppColors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1)),
                      Text(' / $_total',
                          style: const TextStyle(color: AppColors.grey, fontSize: 20, fontWeight: FontWeight.w300)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('objectifs complétés', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72, height: 72,
                    child: CircularProgressIndicator(
                      value: _percentage / 100,
                      strokeWidth: 6,
                      backgroundColor: AppColors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                    ),
                  ),
                  Text('$_percentage%',
                      style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _percentage / 100,
              minHeight: 6,
              backgroundColor: AppColors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Title ────────────────────────────────────────
  Widget _buildSectionTitle(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppColors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.white.withOpacity(0.06))),
      ],
    );
  }

  // ── Event Card ───────────────────────────────────────────
  Widget _buildEventCard(EventItem event) {
    final color = Color(event.color);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eDay = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    final diff = eDay.difference(today).inDays;
    final timeStr = '${event.startDate.hour.toString().padLeft(2, '0')}:${event.startDate.minute.toString().padLeft(2, '0')}';
    String dayLabel = diff == 0 ? "Aujourd'hui" : diff == 1 ? 'Demain' : '${event.startDate.day}/${event.startDate.month}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Barre colorée gauche
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
            ),
            // Date block
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(timeStr, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(dayLabel, style: const TextStyle(color: AppColors.grey, fontSize: 10)),
                ],
              ),
            ),
            Container(width: 1, color: AppColors.white.withOpacity(0.05)),
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Text(event.typeIcon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title,
                              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text('${event.typeLabel} • ${event.durationLabel}',
                              style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (event.isOngoing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Goal Card ────────────────────────────────────────────
  Widget _buildGoalCard(Goal goal) {
    final daysLeft = goal.dueDate != null
        ? goal.dueDate!.difference(DateTime.now()).inDays
        : null;
    final isUrgent = daysLeft != null && daysLeft <= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUrgent ? Colors.orange.withOpacity(0.3) : AppColors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.title,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (daysLeft != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    daysLeft == 0 ? "Échéance aujourd'hui !" : daysLeft < 0 ? 'En retard de ${-daysLeft}j' : 'Dans $daysLeft jour(s)',
                    style: TextStyle(
                      color: isUrgent ? Colors.orange : AppColors.grey,
                      fontSize: 11,
                      fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('EN COURS', style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Carrousel ────────────────────────────────────────────
  Widget _buildCarousel(List<LibraryItem> items, IconData icon, Color color) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _buildCarouselCard(items[i], icon, color),
      ),
    );
  }

  Widget _buildCarouselCard(LibraryItem item, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              item.title,
              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 12, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, color: color, size: 14),
                const SizedBox(width: 4),
                Text('Ouvrir', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
