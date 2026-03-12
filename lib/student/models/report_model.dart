class ReportModel {
  final String issueType;
  final String description;
  final String contactInfo;

  ReportModel({
    required this.issueType,
    required this.description,
    required this.contactInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'issue_type': issueType,
      'description': description,
      'contact_info': contactInfo,
    };
  }
}
