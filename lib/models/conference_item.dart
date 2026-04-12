class ConferenceItem {
  final int id;
  final String title;
  final String roomId;
  final String? videoUrl;
  final String? trainerName;
  final DateTime createdAt;
  final bool? isRecording;
  final DateTime? endedAt;

  ConferenceItem({
    required this.id,
    required this.title,
    required this.roomId,
    this.videoUrl,
    this.trainerName,
    required this.createdAt,
    this.isRecording,
    this.endedAt,
  });

  factory ConferenceItem.fromJson(Map<String, dynamic> json) {
    return ConferenceItem(
      id: json['id'],
      title: json['title'],
      roomId: json['roomId'] ?? json['room_id'] ?? '',
      videoUrl: json['videoUrl'] ?? json['video_url'],
      trainerName: json['user']?['name'],
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
      isRecording: json['isRecording'] ?? json['is_recording'],
      endedAt: json['endedAt'] != null || json['ended_at'] != null
          ? DateTime.parse(json['endedAt'] ?? json['ended_at'])
          : null,
    );
  }
}
