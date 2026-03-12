import 'api_service.dart';

class ReportService extends ApiService {
  const ReportService();

  Future<void> submitReport({
    required String userId,
    required String role,
    required String issueType,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    final response = await postWithFallback(
      'submit_report.php',
      body: {
        'user_id': userId,
        'role': role,
        'issue_type': issueType,
        'description': description,
        'additional_data': additionalData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
      offlineActionType: 'submit_report',
    );
    
    parseResponse(response);
  }

  Future<void> reportError(String userId, String role, Object error, [StackTrace? stack]) async {
    await submitReport(
      userId: userId,
      role: role,
      issueType: 'Technical Error',
      description: 'An unexpected error occurred in the app.',
      additionalData: {
        'error': error.toString(),
        'stack_trace': stack?.toString(),
      },
    );
  }
}
