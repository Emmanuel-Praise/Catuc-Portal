import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:catuc_portal/student/screens/ai/lesson_models.dart'; // Source for Lesson and Exercise models

class LearnHistoryService {
  static const String _historyKeyPrefix = 'learn_history_';

  Future<void> saveTopic({
    required String studentId,
    required LearningTopic topic,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyMap = await _getHistoryMap(prefs, studentId);
      
      historyMap[topic.title] = topic.toJson();

      await prefs.setString('$_historyKeyPrefix$studentId', jsonEncode(historyMap));
    } catch (e) {
      debugPrint('Error saving topic: $e');
    }
  }

  /// Saves a list of generated lessons for a specific student and topic (legacy method, updated)
  Future<void> saveLessons({
    required String studentId,
    required String topic,
    required List<Lesson> lessons,
  }) async {
    final learningTopic = LearningTopic(
      title: topic,
      description: 'Structured course on $topic',
      lessons: lessons,
      timestamp: DateTime.now(),
    );
    await saveTopic(studentId: studentId, topic: learningTopic);
  }

  /// Retrieves the learning history list for a student, ordered by most recent first
  Future<List<Map<String, dynamic>>> getHistory(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyMap = await _getHistoryMap(prefs, studentId);
      
      final List<LearningTopic> historyList = historyMap.values
          .map((v) => LearningTopic.fromJson(v))
          .toList();
      
      // Sort by newest first
      historyList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return historyList.map((t) => t.toJson()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Retrieves cached lessons for a specific topic
  Future<List<Lesson>?> getLessonsForTopic(String studentId, String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyMap = await _getHistoryMap(prefs, studentId);
      
      if (!historyMap.containsKey(topic)) return null;
      
      final entry = historyMap[topic]!;
      final lessonsList = entry['lessons'] as List<dynamic>?;
      
      if (lessonsList == null) return null;
      
      return lessonsList.map((j) => Lesson.fromJson(Map<String, dynamic>.from(j as Map))).toList();
    } catch (e) {
      return null;
    }
  }

  /// Updates a specific lesson with its full AI-generated content and completion status
  Future<void> updateLessonProgress({
    required String studentId,
    required String topicTitle,
    required String lessonTitle,
    bool? isCompleted,
    String? explanation,
    String? example,
    List<Exercise>? exercises,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyMap = await _getHistoryMap(prefs, studentId);
      
      if (!historyMap.containsKey(topicTitle)) return;
      
      final topic = LearningTopic.fromJson(historyMap[topicTitle]!);
      
      for (final lesson in topic.lessons) {
        if (lesson.title == lessonTitle) {
          if (isCompleted != null) lesson.isCompleted = isCompleted;
          if (explanation != null) lesson.explanation = explanation;
          if (example != null) lesson.example = example;
          if (exercises != null) lesson.exercises = exercises;
          break;
        }
      }
      
      historyMap[topicTitle] = topic.toJson();
      await prefs.setString('$_historyKeyPrefix$studentId', jsonEncode(historyMap));
    } catch (e) {
      debugPrint('Error updating lesson progress: $e');
    }
  }

  /// Updates a specific lesson with its full AI-generated content (legacy method)
  Future<void> updateLessonContent({
    required String studentId,
    required String topic,
    required String lessonTitle,
    required String explanation,
    required String example,
    required List<Exercise> exercises,
  }) async {
    await updateLessonProgress(
      studentId: studentId,
      topicTitle: topic,
      lessonTitle: lessonTitle,
      explanation: explanation,
      example: example,
      exercises: exercises,
    );
  }

  /// Removes a specific topic from history
  Future<void> removeTopic(String studentId, String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyMap = await _getHistoryMap(prefs, studentId);
      
      if (historyMap.containsKey(topic)) {
        historyMap.remove(topic);
        await prefs.setString('$_historyKeyPrefix$studentId', jsonEncode(historyMap));
      }
    } catch (e) {}
  }

  /// Helper: Load history map strongly typed
  Future<Map<String, Map<String, dynamic>>> _getHistoryMap(SharedPreferences prefs, String studentId) async {
    final historyStr = prefs.getString('$_historyKeyPrefix$studentId');
    if (historyStr == null) return {};
    
    try {
      final rawMap = jsonDecode(historyStr) as Map<String, dynamic>;
      final Map<String, Map<String, dynamic>> typedMap = {};
      
      rawMap.forEach((key, value) {
        if (value is Map) {
          typedMap[key] = Map<String, dynamic>.from(value);
        }
      });
      
      return typedMap;
    } catch (e) {
      return {};
    }
  }

}
