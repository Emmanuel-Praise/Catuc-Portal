class HomeData {
  final String programName;
  final int passedCount;
  final int totalRecent;
  final List<Map<String, dynamic>> recentResults;

  const HomeData({
    required this.programName,
    required this.passedCount,
    required this.totalRecent,
    required this.recentResults,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final student = (json['student'] as Map<String, dynamic>? ?? {});
    final academics = (json['academics'] as Map<String, dynamic>? ?? {});
    final recentResults = (academics['recent_results'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return HomeData(
      programName: (student['program_name'] ?? 'Program').toString(),
      passedCount: (academics['passed_count'] as num?)?.toInt() ?? 0,
      totalRecent: (academics['total_recent'] as num?)?.toInt() ?? 0,
      recentResults: recentResults,
    );
  }
}
