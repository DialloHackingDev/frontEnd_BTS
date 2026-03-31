class LibraryItem {
  final int id;
  final String title;
  final String type; // 'pdf', 'audio', 'video'
  final String url;
  final DateTime createdAt;

  LibraryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    required this.createdAt,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      url: json['url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'url': url,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
