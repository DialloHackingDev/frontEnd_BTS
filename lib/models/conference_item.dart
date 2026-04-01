class ConferenceItem {
  final int id;
  final String title;
  final String roomId;
  final String? videoUrl;
  final String? trainerName;
  final DateTime createdAt;

  ConferenceItem({
    required this.id,
    required this.title,
    required this.roomId,
    this.videoUrl,
    this.trainerName,
    required this.createdAt,
  });

  factory ConferenceItem.fromJson(Map<String, dynamic> json) {
    return ConferenceItem(
      id: json['id'],
      title: json['title'],
      roomId: json['roomId'] ?? json['room_id'] ?? '',
      videoUrl: json['videoUrl'] ?? json['video_url'],
      trainerName: json['user']?['name'],
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
