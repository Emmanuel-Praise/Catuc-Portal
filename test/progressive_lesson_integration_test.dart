import 'package:flutter_test/flutter_test.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';
import 'package:catuc_portal/student/screens/ai/lesson_models.dart';

void main() {
  group('Progressive Lesson Integration Tests', () {
    const StudentApiService apiService = StudentApiService();

    test('API service should generate lesson outline', () async {
      // Test that the API can generate lesson outline
      final lessons = await apiService.generateLearningLessons(
        studentId: 'test_student',
        topic: 'Python Programming',
        studentProfile: null,
        role: 'student',
        contextLabel: 'Computer Science',
        generateOutlineOnly: true,
      );

      expect(lessons.isNotEmpty, isTrue, reason: 'Should generate lesson outline');
      
      // All lessons should initially have isContentGenerated = false
      for (final lesson in lessons) {
        expect(lesson.isContentGenerated, isFalse, 
               reason: 'All lessons should start without content');
        expect(lesson.title.isNotEmpty, isTrue, 
               reason: 'Each lesson should have a title');
        expect(lesson.description.isNotEmpty, isTrue, 
               reason: 'Each lesson should have a description');
      }
    });

    test('API service should generate specific lesson content', () async {
      // Create a lesson outline
      final lessonOutline = Lesson(
        title: 'Python Variables and Data Types',
        description: 'Understanding variables and data types in Python',
        duration: '30 minutes',
        difficulty: 'Beginner',
        objectives: ['Understand variables', 'Learn data types'],
        exercises: [],
        isContentGenerated: false,
      );

      // Generate content for this specific lesson
      final lessonWithContent = await apiService.generateSpecificLesson(
        studentId: 'test_student',
        topic: 'Python Programming',
        lessonTitle: lessonOutline.title,
        lessonDescription: lessonOutline.description,
        studentProfile: null,
        role: 'student',
        contextLabel: 'Computer Science',
      );

      expect(lessonWithContent.explanation?.isNotEmpty ?? false, isTrue,
             reason: 'Lesson should have explanation');
      expect(lessonWithContent.example?.isNotEmpty ?? false, isTrue,
             reason: 'Lesson should have example');
      expect(lessonWithContent.exercises.isNotEmpty, isTrue,
             reason: 'Lesson should have exercises');
    });

    test('Topic suggestions should work with user query', () async {
      final topics = await apiService.fetchSuggestedTopics(
        'Computer Science',
        studentId: 'test_student',
        role: 'student',
        userQuery: 'machine learning',
      );

      expect(topics.isNotEmpty, isTrue, reason: 'Should generate topics based on user query');
      
      // Topics should be relevant to machine learning
      for (final topic in topics) {
        expect(topic.toLowerCase().contains('machine') || 
               topic.toLowerCase().contains('learning') ||
               topic.toLowerCase().contains('ai') ||
               topic.toLowerCase().contains('data'), isTrue,
               reason: 'Topics should be relevant to machine learning');
      }
    });
  });
}
