class EventItem {
  final int id;
  final String title;
  final String? description;
  final String type; // general, reunion, formation, conference
  final DateTime startDate;
  final DateTime endDate;
  final int? conferenceId;
  final int createdBy;
  final DateTime createdAt;

  EventItem({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.conferenceId,
    required this.createdBy,
    required this.createdAt,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: json['type'] ?? 'general',
      startDate: DateTime.parse(json['start_date'] ?? json['startDate']),
      endDate: DateTime.parse(json['end_date'] ?? json['endDate']),
      conferenceId: json['conference_id'] ?? json['conferenceId'],
      createdBy: json['created_by'] ?? json['createdBy'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Couleur selon le type
  static const Map<String, int> typeColors = {
    'general': 0xFFD4AF37,    // gold
    'reunion': 0xFF4FC3F7,    // bleu clair
    'formation': 0xFF81C784,  // vert
    'conference': 0xFFFF8A65, // orange
  };

  int get color => typeColors[type] ?? typeColors['general']!;

  String get typeLabel {
    switch (type) {
      case 'reunion': return 'Réunion';
      case 'formation': return 'Formation';
      case 'conference': return 'Conférence';
      default: return 'Général';
    }
  }

  String get typeIcon {
    switch (type) {
      case 'reunion': return '👥';
      case 'formation': return '🎓';
      case 'conference': return '🎥';
      default: return '📅';
    }
  }

  Duration get duration => endDate.difference(startDate);

  String get durationLabel {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  bool get isPast => endDate.isBefore(DateTime.now());
  bool get isOngoing => startDate.isBefore(DateTime.now()) && endDate.isAfter(DateTime.now());
}
