import 'package:flutter_test/flutter_test.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';

void main() {
  group('Dynamic Topic Generation Tests', () {
    late StudentApiService apiService;

    setUp(() {
      apiService = const StudentApiService();
    });

    test('Default topics should be generated based on user query when AI fails', () {
      // Test Python-related query
      final pythonTopics = apiService.getDefaultTopics('student', 'Learn Python');
      expect(pythonTopics.length, equals(8));
      expect(pythonTopics.any((topic) => topic.contains('Python')), isTrue);
      expect(pythonTopics.any((topic) => topic.contains('Variables & Data Types')), isTrue);

      // Test Math-related query
      final mathTopics = apiService.getDefaultTopics('student', 'Calculus');
      expect(mathTopics.length, equals(8));
      expect(mathTopics.any((topic) => topic.contains('Calculus')), isTrue);
      expect(mathTopics.any((topic) => topic.contains('Integration')), isTrue);

      // Test Web-related query
      final webTopics = apiService.getDefaultTopics('student', 'Web Development');
      expect(webTopics.length, equals(8));
      expect(webTopics.any((topic) => topic.contains('HTML')), isTrue);
      expect(webTopics.any((topic) => topic.contains('CSS')), isTrue);

      // Test generic query
      final genericTopics = apiService.getDefaultTopics('student', 'Machine Learning');
      expect(genericTopics.length, equals(8));
      expect(genericTopics.every((topic) => topic.contains('Machine Learning')), isTrue);
    });

    test('Default topics should return original static topics when no user query', () {
      final studentTopics = apiService.getDefaultTopics('student', null);
      expect(studentTopics.length, equals(8));
      expect(studentTopics.contains('Data Structures & Algorithms'), isTrue);

      final teacherTopics = apiService.getDefaultTopics('teacher', null);
      expect(teacherTopics.length, equals(8));
      expect(teacherTopics.contains('Active Learning Strategies'), isTrue);
    });
  });
}
