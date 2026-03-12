import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/ai/lesson_models.dart';

class AiLearningStore {
  static Database? _db;
  static SharedPreferences? _prefs;
  static bool _usePrefs = false;

  const AiLearningStore();

  static Future<void> init() async {
    if (kIsWeb) {
      _prefs = await SharedPreferences.getInstance();
      _usePrefs = true;
      return;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_learning.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE learning_paths (
            id TEXT PRIMARY KEY,
            student_id TEXT NOT NULL,
            request_text TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE learning_topics (
            id TEXT PRIMARY KEY,
            path_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            last_opened_lesson_index INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(path_id) REFERENCES learning_paths(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE learning_lessons (
            topic_id TEXT NOT NULL,
            lesson_index INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            duration TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            objectives_json TEXT NOT NULL,
            explanation_md TEXT,
            example_md TEXT,
            exercises_json TEXT,
            is_completed INTEGER NOT NULL DEFAULT 0,
            is_content_generated INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY(topic_id, lesson_index),
            FOREIGN KEY(topic_id) REFERENCES learning_topics(id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
            'CREATE INDEX idx_learning_paths_student ON learning_paths(student_id)');
        await db.execute(
            'CREATE INDEX idx_learning_topics_path ON learning_topics(path_id)');
        await db.execute(
            'CREATE INDEX idx_learning_lessons_topic ON learning_lessons(topic_id)');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  bool get isAvailable => _db != null || _usePrefs;

  Future<void> createPath({
    required String pathId,
    required String studentId,
    required String requestText,
    required List<Map<String, String>> topics,
  }) async {
    if (_usePrefs) {
      await _prefsCreatePath(
        pathId: pathId,
        studentId: studentId,
        requestText: requestText,
        topics: topics,
      );
      return;
    }
    if (_db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.transaction((txn) async {
      await txn.insert(
        'learning_paths',
        {
          'id': pathId,
          'student_id': studentId,
          'request_text': requestText,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (int i = 0; i < topics.length; i++) {
        final t = topics[i];
        await txn.insert(
          'learning_topics',
          {
            'id': _topicId(pathId, i),
            'path_id': pathId,
            'title': (t['topic'] ?? '').trim(),
            'description': (t['description'] ?? '').trim(),
            'sort_order': i,
            'created_at': now,
            'updated_at': now,
            'last_opened_lesson_index': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> listPaths(String studentId) async {
    if (_usePrefs) return _prefsListPaths(studentId);
    if (_db == null) return [];

    // Summary: path row + total lessons + completed lessons
    final rows = await _db!.rawQuery('''
      SELECT
        p.id,
        p.request_text,
        p.created_at,
        p.updated_at,
        (SELECT COUNT(*) FROM learning_topics t WHERE t.path_id = p.id) AS topic_count,
        (SELECT COUNT(*) FROM learning_lessons l
          JOIN learning_topics t ON t.id = l.topic_id
          WHERE t.path_id = p.id) AS total_lessons,
        (SELECT COUNT(*) FROM learning_lessons l
          JOIN learning_topics t ON t.id = l.topic_id
          WHERE t.path_id = p.id AND l.is_completed = 1) AS completed_lessons
      FROM learning_paths p
      WHERE p.student_id = ?
      ORDER BY p.updated_at DESC
      LIMIT 25
    ''', [studentId]);

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>?> getPath(String pathId) async {
    if (_usePrefs) return _prefsGetPath(pathId);
    if (_db == null) return null;
    final rows = await _db!.query(
      'learning_paths',
      where: 'id = ?',
      whereArgs: [pathId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> listTopics(String pathId) async {
    if (_usePrefs) return _prefsListTopics(pathId);
    if (_db == null) return [];
    final rows = await _db!.rawQuery('''
      SELECT
        t.*,
        (SELECT COUNT(*) FROM learning_lessons l WHERE l.topic_id = t.id) AS total_lessons,
        (SELECT COUNT(*) FROM learning_lessons l WHERE l.topic_id = t.id AND l.is_completed = 1) AS completed_lessons
      FROM learning_topics t
      WHERE t.path_id = ?
      ORDER BY t.sort_order ASC
    ''', [pathId]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> upsertLessonsOutline({
    required String topicId,
    required List<Lesson> lessons,
  }) async {
    if (_usePrefs) {
      await _prefsUpsertLessonsOutline(topicId: topicId, lessons: lessons);
      return;
    }
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db!.transaction((txn) async {
      for (int i = 0; i < lessons.length; i++) {
        final l = lessons[i];
        await txn.insert(
          'learning_lessons',
          {
            'topic_id': topicId,
            'lesson_index': i,
            'title': l.title,
            'description': l.description,
            'duration': l.duration,
            'difficulty': l.difficulty,
            'objectives_json': jsonEncode(l.objectives),
            'explanation_md': l.explanation,
            'example_md': l.example,
            'exercises_json': jsonEncode(l.exercises.map((e) => e.toJson()).toList()),
            'is_completed': l.isCompleted ? 1 : 0,
            'is_content_generated': l.isContentGenerated ? 1 : 0,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.update(
        'learning_topics',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [topicId],
      );
    });
  }

  Future<List<Lesson>> getLessons(String topicId) async {
    if (_usePrefs) return _prefsGetLessons(topicId);
    if (_db == null) return [];
    final rows = await _db!.query(
      'learning_lessons',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'lesson_index ASC',
    );
    return rows.map(_lessonFromRow).toList();
  }

  Future<Lesson?> getLesson(String topicId, int lessonIndex) async {
    if (_usePrefs) return _prefsGetLesson(topicId, lessonIndex);
    if (_db == null) return null;
    final rows = await _db!.query(
      'learning_lessons',
      where: 'topic_id = ? AND lesson_index = ?',
      whereArgs: [topicId, lessonIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _lessonFromRow(rows.first);
  }

  Future<void> saveLessonContent({
    required String topicId,
    required int lessonIndex,
    required String explanation,
    required String example,
    required List<Exercise> exercises,
  }) async {
    if (_usePrefs) {
      await _prefsSaveLessonContent(
        topicId: topicId,
        lessonIndex: lessonIndex,
        explanation: explanation,
        example: example,
        exercises: exercises,
      );
      return;
    }
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.update(
      'learning_lessons',
      {
        'explanation_md': explanation,
        'example_md': example,
        'exercises_json': jsonEncode(exercises.map((e) => e.toJson()).toList()),
        'is_content_generated': 1,
        'updated_at': now,
      },
      where: 'topic_id = ? AND lesson_index = ?',
      whereArgs: [topicId, lessonIndex],
    );
  }

  Future<void> markLessonCompleted({
    required String topicId,
    required int lessonIndex,
    required bool completed,
  }) async {
    if (_usePrefs) {
      await _prefsMarkLessonCompleted(
        topicId: topicId,
        lessonIndex: lessonIndex,
        completed: completed,
      );
      return;
    }
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.update(
      'learning_lessons',
      {
        'is_completed': completed ? 1 : 0,
        'updated_at': now,
      },
      where: 'topic_id = ? AND lesson_index = ?',
      whereArgs: [topicId, lessonIndex],
    );
    await _touchPathForTopic(topicId);
  }

  Future<void> setLastOpenedLessonIndex({
    required String topicId,
    required int lessonIndex,
  }) async {
    if (_usePrefs) {
      await _prefsSetLastOpenedLessonIndex(
        topicId: topicId,
        lessonIndex: lessonIndex,
      );
      return;
    }
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.update(
      'learning_topics',
      {
        'last_opened_lesson_index': lessonIndex,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
    await _touchPathForTopic(topicId);
  }

  Future<int> getResumeLessonIndex(String topicId) async {
    if (_usePrefs) return _prefsGetResumeLessonIndex(topicId);
    if (_db == null) return 0;

    final topicRows = await _db!.query(
      'learning_topics',
      columns: ['last_opened_lesson_index'],
      where: 'id = ?',
      whereArgs: [topicId],
      limit: 1,
    );
    final lastOpened =
        topicRows.isEmpty ? 0 : (topicRows.first['last_opened_lesson_index'] as int?) ?? 0;

    // Prefer resuming from the last opened lesson if it's still incomplete.
    final lastOpenedStatus = await _db!.rawQuery('''
      SELECT is_completed
      FROM learning_lessons
      WHERE topic_id = ? AND lesson_index = ?
      LIMIT 1
    ''', [topicId, lastOpened]);
    if (lastOpenedStatus.isNotEmpty) {
      final isCompleted = (lastOpenedStatus.first['is_completed'] as int?) ?? 0;
      if (isCompleted == 0) return lastOpened;
    }

    // Otherwise, resume from the first incomplete lesson (or 0 if all done).
    final firstIncomplete = await _db!.rawQuery('''
      SELECT lesson_index
      FROM learning_lessons
      WHERE topic_id = ? AND is_completed = 0
      ORDER BY lesson_index ASC
      LIMIT 1
    ''', [topicId]);

    if (firstIncomplete.isNotEmpty) {
      return (firstIncomplete.first['lesson_index'] as int?) ?? 0;
    }

    return lastOpened;
  }

  Future<void> deletePath(String pathId) async {
    if (_usePrefs) {
      await _prefsDeletePath(pathId);
      return;
    }
    if (_db == null) return;
    await _db!.transaction((txn) async {
      final topicRows = await txn.query(
        'learning_topics',
        columns: ['id'],
        where: 'path_id = ?',
        whereArgs: [pathId],
      );
      for (final r in topicRows) {
        await txn.delete(
          'learning_lessons',
          where: 'topic_id = ?',
          whereArgs: [r['id']],
        );
      }
      await txn.delete('learning_topics', where: 'path_id = ?', whereArgs: [pathId]);
      await txn.delete('learning_paths', where: 'id = ?', whereArgs: [pathId]);
    });
  }

  Lesson _lessonFromRow(Map<String, Object?> row) {
    final objectives = _decodeStringList(row['objectives_json'] as String?);
    final exercises = _decodeExercises(row['exercises_json'] as String?);

    return Lesson(
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      duration: (row['duration'] as String?) ?? '',
      difficulty: (row['difficulty'] as String?) ?? '',
      objectives: objectives,
      exercises: exercises,
      isCompleted: ((row['is_completed'] as int?) ?? 0) == 1,
      explanation: row['explanation_md'] as String?,
      example: row['example_md'] as String?,
      isContentGenerated: ((row['is_content_generated'] as int?) ?? 0) == 1,
    );
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<Exercise> _decodeExercises(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _touchPathForTopic(String topicId) async {
    if (_db == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db!.rawQuery(
      'SELECT path_id FROM learning_topics WHERE id = ? LIMIT 1',
      [topicId],
    );
    if (rows.isEmpty) return;
    final pathId = (rows.first['path_id'] as String?) ?? '';
    if (pathId.isEmpty) return;
    await _db!.update(
      'learning_paths',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [pathId],
    );
  }

  String _topicId(String pathId, int index) => '$pathId:$index';

  // -------------------------
  // Web fallback (SharedPreferences)
  // -------------------------

  String _prefsStudentKey(String studentId) => 'ai_learning_web_$studentId';

  Future<Map<String, dynamic>> _prefsLoadStudent(String studentId) async {
    final raw = _prefs?.getString(_prefsStudentKey(studentId));
    if (raw == null || raw.trim().isEmpty) return {'paths': {}};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'paths': {}};
    } catch (_) {
      return {'paths': {}};
    }
  }

  Future<void> _prefsSaveStudent(String studentId, Map<String, dynamic> data) async {
    await _prefs?.setString(_prefsStudentKey(studentId), jsonEncode(data));
  }

  Future<void> _prefsCreatePath({
    required String pathId,
    required String studentId,
    required String requestText,
    required List<Map<String, String>> topics,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final root = await _prefsLoadStudent(studentId);
    final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});

    final topicObjs = <Map<String, dynamic>>[];
    for (int i = 0; i < topics.length; i++) {
      final t = topics[i];
      topicObjs.add({
        'id': _topicId(pathId, i),
        'path_id': pathId,
        'title': (t['topic'] ?? '').trim(),
        'description': (t['description'] ?? '').trim(),
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
        'last_opened_lesson_index': 0,
        'lessons': <dynamic>[],
      });
    }

    paths[pathId] = {
      'id': pathId,
      'student_id': studentId,
      'request_text': requestText,
      'created_at': now,
      'updated_at': now,
      'topics': topicObjs,
    };

    root['paths'] = paths;
    await _prefsSaveStudent(studentId, root);
    await _prefsEnsureIndex(studentId, pathId);
  }

  Future<List<Map<String, dynamic>>> _prefsListPaths(String studentId) async {
    final root = await _prefsLoadStudent(studentId);
    final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});

    final out = <Map<String, dynamic>>[];
    for (final entry in paths.entries) {
      final p = Map<String, dynamic>.from(entry.value as Map);
      final topics = (p['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      int totalLessons = 0;
      int completedLessons = 0;
      for (final t in topics) {
        final lessons = (t['lessons'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        totalLessons += lessons.length;
        completedLessons += lessons.where((l) => (l['isCompleted'] ?? false) == true).length;
      }

      out.add({
        'id': p['id'],
        'request_text': p['request_text'],
        'created_at': p['created_at'],
        'updated_at': p['updated_at'],
        'topic_count': topics.length,
        'total_lessons': totalLessons,
        'completed_lessons': completedLessons,
      });
    }

    out.sort((a, b) => (b['updated_at'] as int? ?? 0).compareTo(a['updated_at'] as int? ?? 0));
    return out.take(25).toList();
  }

  Future<Map<String, dynamic>?> _prefsGetPath(String pathId) async {
    if (_prefs == null) return null;
    // Search across students? Not possible without studentId. We store by student key,
    // so keep a lightweight global index for reverse lookup.
    final indexRaw = _prefs!.getString('ai_learning_web_index');
    if (indexRaw == null || indexRaw.trim().isEmpty) return null;
    try {
      final index = Map<String, dynamic>.from(jsonDecode(indexRaw) as Map);
      final studentId = (index[pathId] ?? '').toString();
      if (studentId.isEmpty) return null;
      final root = await _prefsLoadStudent(studentId);
      final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});
      final path = paths[pathId];
      if (path is Map) return Map<String, dynamic>.from(path);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _prefsEnsureIndex(String studentId, String pathId) async {
    if (_prefs == null) return;
    final raw = _prefs!.getString('ai_learning_web_index');
    Map<String, dynamic> index;
    try {
      index = raw == null || raw.trim().isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      index = {};
    }
    index[pathId] = studentId;
    await _prefs!.setString('ai_learning_web_index', jsonEncode(index));
  }

  Future<List<Map<String, dynamic>>> _prefsListTopics(String pathId) async {
    final path = await _prefsGetPath(pathId);
    if (path == null) return [];
    final studentId = (path['student_id'] ?? '').toString();
    if (studentId.isEmpty) return [];

    final topics = (path['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    topics.sort((a, b) => (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0));

    return topics.map((t) {
      final lessons = (t['lessons'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final total = lessons.length;
      final completed = lessons.where((l) => (l['isCompleted'] ?? false) == true).length;
      return {
        ...t,
        'total_lessons': total,
        'completed_lessons': completed,
      };
    }).toList();
  }

  Future<void> _prefsUpsertLessonsOutline({
    required String topicId,
    required List<Lesson> lessons,
  }) async {
    if (_prefs == null) return;
    final idxRaw = _prefs!.getString('ai_learning_web_index');
    if (idxRaw == null) return;
    final index = Map<String, dynamic>.from(jsonDecode(idxRaw) as Map);
    final pathId = topicId.split(':').first;
    final studentId = (index[pathId] ?? '').toString();
    if (studentId.isEmpty) return;

    final root = await _prefsLoadStudent(studentId);
    final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});
    final path = Map<String, dynamic>.from(paths[pathId] as Map? ?? {});
    final topics = (path['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final t in topics) {
      if ((t['id'] ?? '').toString() == topicId) {
        t['lessons'] = lessons.map((l) => l.toJson()).toList();
        t['updated_at'] = now;
        break;
      }
    }

    path['topics'] = topics;
    path['updated_at'] = now;
    paths[pathId] = path;
    root['paths'] = paths;
    await _prefsSaveStudent(studentId, root);
  }

  Future<List<Lesson>> _prefsGetLessons(String topicId) async {
    final lessonsJson = await _prefsFindTopicLessons(topicId);
    return lessonsJson.map((j) => Lesson.fromJson(j)).toList();
  }

  Future<Lesson?> _prefsGetLesson(String topicId, int lessonIndex) async {
    final lessons = await _prefsGetLessons(topicId);
    if (lessonIndex < 0 || lessonIndex >= lessons.length) return null;
    return lessons[lessonIndex];
  }

  Future<void> _prefsSaveLessonContent({
    required String topicId,
    required int lessonIndex,
    required String explanation,
    required String example,
    required List<Exercise> exercises,
  }) async {
    await _prefsMutateLesson(
      topicId: topicId,
      lessonIndex: lessonIndex,
      mutate: (lesson) {
        lesson['explanation'] = explanation;
        lesson['example'] = example;
        lesson['exercises'] = exercises.map((e) => e.toJson()).toList();
        lesson['isContentGenerated'] = true;
      },
    );
  }

  Future<void> _prefsMarkLessonCompleted({
    required String topicId,
    required int lessonIndex,
    required bool completed,
  }) async {
    await _prefsMutateLesson(
      topicId: topicId,
      lessonIndex: lessonIndex,
      mutate: (lesson) => lesson['isCompleted'] = completed,
    );
  }

  Future<void> _prefsSetLastOpenedLessonIndex({
    required String topicId,
    required int lessonIndex,
  }) async {
    if (_prefs == null) return;
    final pathId = topicId.split(':').first;
    final idxRaw = _prefs!.getString('ai_learning_web_index');
    if (idxRaw == null) return;
    final index = Map<String, dynamic>.from(jsonDecode(idxRaw) as Map);
    final studentId = (index[pathId] ?? '').toString();
    if (studentId.isEmpty) return;

    final root = await _prefsLoadStudent(studentId);
    final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});
    final path = Map<String, dynamic>.from(paths[pathId] as Map? ?? {});
    final topics = (path['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final t in topics) {
      if ((t['id'] ?? '').toString() == topicId) {
        t['last_opened_lesson_index'] = lessonIndex;
        t['updated_at'] = now;
        break;
      }
    }

    path['topics'] = topics;
    path['updated_at'] = now;
    paths[pathId] = path;
    root['paths'] = paths;
    await _prefsSaveStudent(studentId, root);
  }

  Future<int> _prefsGetResumeLessonIndex(String topicId) async {
    if (_prefs == null) return 0;
    final lessonsJson = await _prefsFindTopicLessons(topicId);
    if (lessonsJson.isEmpty) return 0;

    final pathId = topicId.split(':').first;
    final idxRaw = _prefs!.getString('ai_learning_web_index');
    if (idxRaw == null) return 0;
    final index = Map<String, dynamic>.from(jsonDecode(idxRaw) as Map);
    final studentId = (index[pathId] ?? '').toString();
    if (studentId.isEmpty) return 0;

    final root = await _prefsLoadStudent(studentId);
    final path = Map<String, dynamic>.from((Map<String, dynamic>.from(root['paths'] as Map? ?? {}))[pathId] as Map? ?? {});
    final topics = (path['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final topic = topics.firstWhere((t) => (t['id'] ?? '').toString() == topicId, orElse: () => {});
    final lastOpened = (topic['last_opened_lesson_index'] as int?) ?? 0;
    if (lastOpened >= 0 && lastOpened < lessonsJson.length) {
      final isCompleted = (lessonsJson[lastOpened]['isCompleted'] ?? false) == true;
      if (!isCompleted) return lastOpened;
    }

    final firstIncomplete = lessonsJson.indexWhere((l) => (l['isCompleted'] ?? false) != true);
    if (firstIncomplete >= 0) return firstIncomplete;
    return lastOpened.clamp(0, lessonsJson.length - 1);
  }

  Future<void> _prefsDeletePath(String pathId) async {
    if (_prefs == null) return;
    final idxRaw = _prefs!.getString('ai_learning_web_index');
    if (idxRaw == null) return;
    final index = Map<String, dynamic>.from(jsonDecode(idxRaw) as Map);
    final studentId = (index[pathId] ?? '').toString();
    if (studentId.isEmpty) return;

    final root = await _prefsLoadStudent(studentId);
    final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});
    paths.remove(pathId);
    root['paths'] = paths;
    await _prefsSaveStudent(studentId, root);

    index.remove(pathId);
    await _prefs!.setString('ai_learning_web_index', jsonEncode(index));
  }

  Future<List<Map<String, dynamic>>> _prefsFindTopicLessons(String topicId) async {
    if (_prefs == null) return [];
    final pathId = topicId.split(':').first;
    final idxRaw = _prefs!.getString('ai_learning_web_index');
    if (idxRaw == null) return [];
    final index = Map<String, dynamic>.from(jsonDecode(idxRaw) as Map);
    final studentId = (index[pathId] ?? '').toString();
    if (studentId.isEmpty) return [];

    final root = await _prefsLoadStudent(studentId);
    final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});
    final path = Map<String, dynamic>.from(paths[pathId] as Map? ?? {});
    final topics = (path['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final topic = topics.firstWhere((t) => (t['id'] ?? '').toString() == topicId, orElse: () => {});
    final lessons = (topic['lessons'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return lessons;
  }

  Future<void> _prefsMutateLesson({
    required String topicId,
    required int lessonIndex,
    required void Function(Map<String, dynamic> lessonJson) mutate,
  }) async {
    if (_prefs == null) return;
    final pathId = topicId.split(':').first;
    final idxRaw = _prefs!.getString('ai_learning_web_index');
    if (idxRaw == null) return;
    final index = Map<String, dynamic>.from(jsonDecode(idxRaw) as Map);
    final studentId = (index[pathId] ?? '').toString();
    if (studentId.isEmpty) return;

    final root = await _prefsLoadStudent(studentId);
    final paths = Map<String, dynamic>.from(root['paths'] as Map? ?? {});
    final path = Map<String, dynamic>.from(paths[pathId] as Map? ?? {});
    final topics = (path['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final t in topics) {
      if ((t['id'] ?? '').toString() != topicId) continue;
      final lessons = (t['lessons'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (lessonIndex < 0 || lessonIndex >= lessons.length) return;
      mutate(lessons[lessonIndex]);
      t['lessons'] = lessons;
      t['updated_at'] = now;
      break;
    }

    path['topics'] = topics;
    path['updated_at'] = now;
    paths[pathId] = path;
    root['paths'] = paths;
    await _prefsSaveStudent(studentId, root);
  }
}
