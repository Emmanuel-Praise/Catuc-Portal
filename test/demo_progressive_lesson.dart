import 'package:flutter_test/flutter_test.dart';
import 'package:catuc_portal/student/screens/ai/lesson_models.dart';

void main() {
  group('Progressive Lesson Demo', () {
    test('Demo: Progressive lesson generation workflow', () {
      print('\n=== PROGRESSIVE LESSON GENERATION DEMO ===\n');
      
      // Step 1: User selects a topic "Python Programming"
      const topic = 'Python Programming';
      print('📚 User selects topic: "$topic"');
      
      // Step 2: AI generates lesson outline (6-8 lessons without content)
      final lessonOutline = [
        Lesson(
          title: 'Python Basics: Variables & Data Types',
          description: 'Understanding variables and basic data types in Python',
          duration: '30 minutes',
          difficulty: 'Beginner',
          objectives: ['Understand variables', 'Learn basic data types'],
          exercises: [],
          isContentGenerated: false, // Initially no content
        ),
        Lesson(
          title: 'Python Control Flow: If Statements',
          description: 'Learn how to use conditional statements in Python',
          duration: '25 minutes',
          difficulty: 'Beginner',
          objectives: ['Master if statements', 'Learn conditional logic'],
          exercises: [],
          isContentGenerated: false, // Initially no content
        ),
        Lesson(
          title: 'Python Loops: For & While',
          description: 'Understanding iteration and loops in Python',
          duration: '35 minutes',
          difficulty: 'Intermediate',
          objectives: ['Learn for loops', 'Master while loops'],
          exercises: [],
          isContentGenerated: false, // Initially no content
        ),
        Lesson(
          title: 'Python Functions',
          description: 'Creating and using functions in Python',
          duration: '40 minutes',
          difficulty: 'Intermediate',
          objectives: ['Define functions', 'Understand parameters'],
          exercises: [],
          isContentGenerated: false, // Initially no content
        ),
        Lesson(
          title: 'Python Lists & Dictionaries',
          description: 'Working with collections in Python',
          duration: '45 minutes',
          difficulty: 'Intermediate',
          objectives: ['Master lists', 'Learn dictionaries'],
          exercises: [],
          isContentGenerated: false, // Initially no content
        ),
        Lesson(
          title: 'Python Error Handling',
          description: 'Handling exceptions and errors in Python',
          duration: '30 minutes',
          difficulty: 'Advanced',
          objectives: ['Try/except blocks', 'Error types'],
          exercises: [],
          isContentGenerated: false, // Initially no content
        ),
      ];
      
      print('🤖 AI generates ${lessonOutline.length} lesson outline');
      for (int i = 0; i < lessonOutline.length; i++) {
        final lesson = lessonOutline[i];
        final status = lesson.isContentGenerated ? '✅ Ready' : '🔒 Locked';
        print('   ${i + 1}. $status: ${lesson.title}');
      }
      
      // Step 3: Immediately generate content for first 2 lessons
      print('\n🚀 Generating content for first 2 lessons...');
      lessonOutline[0] = lessonOutline[0].copyWith(
        isContentGenerated: true,
        explanation: '# Python Basics: Variables & Data Types\n\nIn Python, variables are containers for storing data values...',
        example: '```python\n# Variable examples\nname = "John"\nage = 25\nheight = 5.8\nis_student = True\n```',
        exercises: [
          Exercise(
            question: 'What is the output of: x = 5; print(type(x))',
            type: 'multiple_choice',
            options: ['str', 'int', 'float', 'bool'],
            answer: 'int',
            explanation: 'x = 5 assigns an integer value, so type(x) returns <class \'int\'>',
          ),
        ],
      );
      
      lessonOutline[1] = lessonOutline[1].copyWith(
        isContentGenerated: true,
        explanation: '# Python Control Flow: If Statements\n\nConditional statements allow your program to make decisions...',
        example: '```python\n# If statement example\nage = 18\nif age >= 18:\n    print("You can vote!")\nelse:\n    print("Too young to vote")\n```',
        exercises: [
          Exercise(
            question: 'Write an if statement to check if a number is positive',
            type: 'text',
            answer: 'if number > 0:\n    print("Positive")',
            explanation: 'Use the > operator to check if the number is greater than 0',
          ),
        ],
      );
      
      print('✅ First 2 lessons are now ready!');
      for (int i = 0; i < lessonOutline.length; i++) {
        final lesson = lessonOutline[i];
        final status = lesson.isContentGenerated ? '✅ Ready' : '🔒 Locked';
        print('   ${i + 1}. $status: ${lesson.title}');
      }
      
      // Step 4: User starts lesson 1, system generates lesson 3
      print('\n👤 User opens Lesson 1: "${lessonOutline[0].title}"');
      print('🔄 System pre-generates Lesson 3...');
      
      lessonOutline[2] = lessonOutline[2].copyWith(
        isLoading: true,
      );
      
      print('   ⏳ Loading: ${lessonOutline[2].title}');
      
      // Simulate content generation completion
      lessonOutline[2] = lessonOutline[2].copyWith(
        isLoading: false,
        isContentGenerated: true,
        explanation: '# Python Loops: For & While\n\nLoops allow you to repeat code multiple times...',
        example: '```python\n# For loop example\nfor i in range(5):\n    print(i)\n\n# While loop example\ncount = 0\nwhile count < 5:\n    print(count)\n    count += 1\n```',
        exercises: [
          Exercise(
            question: 'Print numbers 1-10 using a for loop',
            type: 'text',
            answer: 'for i in range(1, 11):\n    print(i)',
            explanation: 'range(1, 11) generates numbers from 1 to 10',
          ),
        ],
      );
      
      print('✅ Lesson 3 is now ready!');
      
      // Step 5: Show current state
      print('\n📊 Current lesson state:');
      for (int i = 0; i < lessonOutline.length; i++) {
        final lesson = lessonOutline[i];
        String status;
        if (lesson.isLoading) {
          status = '⏳ Loading';
        } else if (lesson.isContentGenerated) {
          status = '✅ Ready';
        } else {
          status = '🔒 Locked';
        }
        print('   ${i + 1}. $status: ${lesson.title}');
      }
      
      // Step 6: User completes lesson 1 and moves to lesson 2
      print('\n👤 User completes Lesson 1 and opens Lesson 2');
      lessonOutline[0] = lessonOutline[0].copyWith(isCompleted: true);
      print('🔄 System pre-generates Lesson 4...');
      
      lessonOutline[3] = lessonOutline[3].copyWith(
        isLoading: true,
      );
      
      print('   ⏳ Loading: ${lessonOutline[3].title}');
      
      // Simulate completion
      lessonOutline[3] = lessonOutline[3].copyWith(
        isLoading: false,
        isContentGenerated: true,
        explanation: '# Python Functions\n\nFunctions are reusable blocks of code...',
        exercises: [
          Exercise(
            question: 'Define a function that adds two numbers',
            type: 'text',
            answer: 'def add(a, b):\n    return a + b',
            explanation: 'Functions are defined with def keyword and return values',
          ),
        ],
      );
      
      // Step 7: Final state
      print('\n🎉 Final lesson state:');
      for (int i = 0; i < lessonOutline.length; i++) {
        final lesson = lessonOutline[i];
        String status;
        if (lesson.isCompleted) {
          status = '✅ Done';
        } else if (lesson.isLoading) {
          status = '⏳ Loading';
        } else if (lesson.isContentGenerated) {
          status = '📖 Ready';
        } else {
          status = '🔒 Locked';
        }
        print('   ${i + 1}. $status: ${lesson.title}');
      }
      
      // Create LearningTopic to test progress calculation
      final learningTopic = LearningTopic(
        title: topic,
        description: 'Complete Python programming course',
        lessons: lessonOutline,
        timestamp: DateTime.now(),
      );
      
      print('\n📈 Progress: ${(learningTopic.progress * 100).toStringAsFixed(1)}%');
      print('   Completed: ${learningTopic.lessons.where((l) => l.isCompleted).length}/${learningTopic.lessons.length} lessons');
      print('   Ready: ${learningTopic.lessons.where((l) => l.isContentGenerated && !l.isCompleted).length} lessons');
      print('   Locked: ${learningTopic.lessons.where((l) => !l.isContentGenerated).length} lessons');
      
      print('\n✨ Progressive lesson generation demo completed successfully!');
    });
  });
}
