class TeacherCourseMaterial {
  final String materialId;
  final String sectionId;
  final String courseId;
  final String title;
  final String description;
  final String materialType;
  final String externalUrl;
  final String fileName;
  final String filePath;
  final String downloadUrl;
  final String uploadDate;

  const TeacherCourseMaterial({
    required this.materialId,
    required this.sectionId,
    required this.courseId,
    required this.title,
    required this.description,
    required this.materialType,
    required this.externalUrl,
    required this.fileName,
    required this.filePath,
    required this.downloadUrl,
    required this.uploadDate,
  });

  factory TeacherCourseMaterial.fromJson(Map<String, dynamic> json) {
    return TeacherCourseMaterial(
      materialId: (json['material_id'] ?? '').toString(),
      sectionId: (json['section_id'] ?? '').toString(),
      courseId: (json['course_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      materialType: (json['material_type'] ?? 'document').toString(),
      externalUrl: (json['external_url'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      filePath: (json['file_path'] ?? '').toString(),
      downloadUrl: (json['download_url'] ?? '').toString(),
      uploadDate: (json['upload_date'] ?? '').toString(),
    );
  }
}
