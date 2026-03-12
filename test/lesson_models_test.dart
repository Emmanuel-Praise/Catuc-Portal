import 'package:flutter_test/flutter_test.dart';
import 'package:catuc_portal/student/screens/ai/lesson_models.dart';

void main() {
  group('Lesson Models Test', () {
    test('Lesson model should support progressive loading states', () {
      final lesson = Lesson(
        title: 'Test Lesson',
        description: 'Test Description',
        duration: '30 minutes',
        difficulty: 'Beginner',
        objectives: ['Test objective'],
        exercises: [],
      );

      // Test initial state
      expect(lesson.isContentGenerated, isFalse);
      expect(lesson.isLoading, isFalse);

      // Test copyWith for loading state
      final loadingLesson = lesson.copyWith(isLoading: true);
      expect(loadingLesson.isLoading, isTrue);
      expect(loadingLesson.isContentGenerated, isFalse);

      // Test copyWith for content generated state
      final generatedLesson = lesson.copyWith(
        isContentGenerated: true,
        explanation: 'Test explanation',
        example: 'Test example',
      );
      expect(generatedLesson.isContentGenerated, isTrue);
      expect(generatedLesson.explanation, equals('Test explanation'));
      expect(generatedLesson.example, equals('Test example'));
    });

    test('LearningTopic model should handle lessons with different states', () {
      final lessons = [
        Lesson(
          title: 'Lesson 1',
          description: 'Description 1',
          duration: '30 minutes',
          difficulty: 'Beginner',
          objectives: ['Objective 1'],
          exercises: [],
          isContentGenerated: true,
        ),
        Lesson(
          title: 'Lesson 2',
          description: 'Description 2',
          duration: '45 minutes',
          difficulty: 'Intermediate',
          objectives: ['Objective 2'],
          exercises: [],
          isContentGenerated: false,
        ),
        Lesson(
          title: 'Lesson 3',
          description: 'Description 3',
          duration: '60 minutes',
          difficulty: 'Advanced',
          objectives: ['Objective 3'],
          exercises: [],
          isLoading: true,
        ),
      ];

      final topic = LearningTopic(
        title: 'Test Topic',
        description: 'Test Description',
        lessons: lessons,
        timestamp: DateTime.now(),
      );

      // Test that topic contains lessons with different states
      expect(topic.lessons.length, equals(3));
      expect(topic.lessons[0].isContentGenerated, isTrue);
      expect(topic.lessons[1].isContentGenerated, isFalse);
      expect(topic.lessons[2].isLoading, isTrue);

      // Test progress calculation
      expect(topic.progress, equals(0.0)); // No lessons completed

      // Mark first lesson as completed
      final completedLessons = [
        lessons[0].copyWith(isCompleted: true),
        lessons[1],
        lessons[2],
      ];
      final completedTopic = LearningTopic(
        title: 'Test Topic',
        description: 'Test Description',
        lessons: completedLessons,
        timestamp: DateTime.now(),
      );
      expect(completedTopic.progress, equals(1.0 / 3.0));
    });

    test('Lesson JSON serialization should include new fields', () {
      final lesson = Lesson(
        title: 'Test Lesson',
        description: 'Test Description',
        duration: '30 minutes',
        difficulty: 'Beginner',
        objectives: ['Test objective'],
        exercises: [],
        isContentGenerated: true,
        isLoading: false,
      );

      final json = lesson.toJson();
      expect(json['isContentGenerated'], isTrue);
      expect(json['isLoading'], isFalse);
      expect(json['title'], equals('Test Lesson'));

      final deserializedLesson = Lesson.fromJson(json);
      expect(deserializedLesson.isContentGenerated, isTrue);
      expect(deserializedLesson.isLoading, isFalse);
      expect(deserializedLesson.title, equals('Test Lesson'));
    });

    test('Exercise model should serialize correctly', () {
      final exercise = Exercise(
        question: 'What is 2+2?',
        type: 'multiple_choice',
        options: ['3', '4', '5'],
        answer: '4',
        explanation: '2+2 equals 4',
      );

      final json = exercise.toJson();
      expect(json['question'], equals('What is 2+2?'));
      expect(json['type'], equals('multiple_choice'));
      expect(json['options'], equals(['3', '4', '5']));
      expect(json['answer'], equals('4'));
      expect(json['explanation'], equals('2+2 equals 4'));

      final deserializedExercise = Exercise.fromJson(json);
      expect(deserializedExercise.question, equals('What is 2+2?'));
      expect(deserializedExercise.type, equals('multiple_choice'));
      expect(deserializedExercise.options, equals(['3', '4', '5']));
      expect(deserializedExercise.answer, equals('4'));
      expect(deserializedExercise.explanation, equals('2+2 equals 4'));
    });
  });
}
