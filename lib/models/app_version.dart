class AppVersion {
  final int versionCode;
  final String versionName;
  final String? downloadUrl;
  final bool mandatory;

  AppVersion({
    required this.versionCode,
    required this.versionName,
    this.downloadUrl,
    this.mandatory = false,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      versionCode: json['versionCode'] ?? 0,
      versionName: json['versionName'] ?? '1.0.0',
      downloadUrl: json['downloadUrl'],
      mandatory: json['mandatory'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'versionCode': versionCode,
      'versionName': versionName,
      'downloadUrl': downloadUrl,
      'mandatory': mandatory,
    };
  }
}
