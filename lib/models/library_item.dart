class LibraryItem {
  final int id;
  final String title;
  final String type; // 'pdf', 'audio', 'video'
  final String url;
  final String? category;
  final String? description;
  final DateTime createdAt;

  // Extrait l'id de conférence depuis description "conference:ID"
  int? get conferenceId {
    if (description != null && description!.startsWith('conference:')) {
      return int.tryParse(description!.split(':').last);
    }
    return null;
  }

  bool get isConferenceVideo => conferenceId != null;

  LibraryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    this.category,
    this.description,
    required this.createdAt,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      url: json['url'],
      category: json['category'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'url': url,
      'category': category,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
