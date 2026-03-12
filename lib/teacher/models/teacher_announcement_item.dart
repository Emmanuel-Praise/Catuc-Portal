class TeacherAnnouncementItem {
  final String announcementId;
  final String title;
  final String content;
  final String scope; // general | course
  final String? courseId;
  final String createdAt;
  final bool isPublished;
  final String source; // mine | admin | other

  const TeacherAnnouncementItem({
    required this.announcementId,
    required this.title,
    required this.content,
    required this.scope,
    this.courseId,
    required this.createdAt,
    required this.isPublished,
    required this.source,
  });

  factory TeacherAnnouncementItem.fromJson(Map<String, dynamic> json) {
    return TeacherAnnouncementItem(
      announcementId: (json['announcement_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      scope: (json['scope'] ?? 'general').toString(),
      courseId: json['course_id']?.toString() ?? json['courseId']?.toString(),
      createdAt: (json['created_at'] ?? json['posted_at'] ?? '').toString(),
      isPublished: (json['is_published'] ?? 1).toString() == '1',
      source: (json['source'] ?? '').toString().isEmpty
          ? 'mine'
          : (json['source'] ?? 'mine').toString(),
    );
  }
}
