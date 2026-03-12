class NoteCourse {
  final String courseId;
  final String courseCode;
  final String courseName;
  final int materialCount;

  const NoteCourse({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.materialCount,
  });

  factory NoteCourse.fromJson(Map<String, dynamic> json) {
    return NoteCourse(
      courseId: (json['course_id'] ?? '').toString(),
      courseCode: (json['course_code'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      materialCount:
          int.tryParse((json['material_count'] ?? '0').toString()) ?? 0,
    );
  }
}

class NoteMaterial {
  final String materialType;
  final String title;
  final String description;
  final String fileName;
  final String uploadDate;
  final String downloadUrl;

  const NoteMaterial({
    required this.materialType,
    required this.title,
    required this.description,
    required this.fileName,
    required this.uploadDate,
    required this.downloadUrl,
  });

  factory NoteMaterial.fromJson(Map<String, dynamic> json) {
    return NoteMaterial(
      materialType: (json['material_type'] ?? 'document').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      uploadDate: (json['upload_date'] ?? '').toString(),
      downloadUrl: (json['download_url'] ?? '').toString(),
    );
  }
}
