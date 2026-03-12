class Lesson {
  bool isCompleted;
  String? explanation;
  String? example;
  final List<String> objectives;
  List<Exercise> exercises;
  final String title;
  final String description;
  final String duration;
  final String difficulty;
  bool isContentGenerated;
  bool isLoading;

  Lesson({
    required this.title,
    required this.description,
    required this.duration,
    required this.difficulty,
    required this.objectives,
    required this.exercises,
    this.isCompleted = false,
    this.explanation,
    this.example,
    this.isContentGenerated = false,
    this.isLoading = false,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      duration: json['duration'] ?? '',
      difficulty: json['difficulty'] ?? '',
      objectives: List<String>.from(json['objectives'] ?? []),
      exercises: (json['exercises'] as List?)
          ?.map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? [],
      isCompleted: json['isCompleted'] ?? false,
      explanation: json['explanation'],
      example: json['example'],
      isContentGenerated: json['isContentGenerated'] ?? false,
      isLoading: json['isLoading'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'duration': duration,
      'difficulty': difficulty,
      'objectives': objectives,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'isCompleted': isCompleted,
      'explanation': explanation,
      'example': example,
      'isContentGenerated': isContentGenerated,
      'isLoading': isLoading,
    };
  }

  Lesson copyWith({
    String? title,
    String? description,
    String? duration,
    String? difficulty,
    List<String>? objectives,
    List<Exercise>? exercises,
    bool? isCompleted,
    String? explanation,
    String? example,
    bool? isContentGenerated,
    bool? isLoading,
  }) {
    return Lesson(
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      difficulty: difficulty ?? this.difficulty,
      objectives: objectives ?? this.objectives,
      exercises: exercises ?? this.exercises,
      isCompleted: isCompleted ?? this.isCompleted,
      explanation: explanation ?? this.explanation,
      example: example ?? this.example,
      isContentGenerated: isContentGenerated ?? this.isContentGenerated,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LearningTopic {
  final String title;
  final String description;
  final List<Lesson> lessons;
  final DateTime timestamp;

  LearningTopic({
    required this.title,
    required this.description,
    required this.lessons,
    required this.timestamp,
  });

  double get progress {
    if (lessons.isEmpty) return 0.0;
    final completed = lessons.where((l) => l.isCompleted).length;
    return completed / lessons.length;
  }

  factory LearningTopic.fromJson(Map<String, dynamic> json) {
    return LearningTopic(
      title: json['topic'] ?? '',
      description: json['description'] ?? '',
      lessons: (json['lessons'] as List? ?? [])
          .map((l) => Lesson.fromJson(Map<String, dynamic>.from(l as Map)))
          .toList(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic': title,
      'description': description,
      'lessons': lessons.map((l) => l.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class Exercise {
  final String question;
  final String type;
  final List<String>? options;
  final String? answer;
  final String? explanation;

  Exercise({
    required this.question,
    required this.type,
    this.options,
    this.answer,
    this.explanation,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      question: json['question'] ?? '',
      type: json['type'] ?? '',
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      answer: json['answer'],
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'type': type,
      'options': options,
      'answer': answer,
      'explanation': explanation,
    };
  }
}
