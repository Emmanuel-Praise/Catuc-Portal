import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:catuc_portal/student/models/student_session.dart';
import 'package:catuc_portal/student/models/student_profile.dart';
import 'package:catuc_portal/student/models/student_home_data.dart';
import 'package:catuc_portal/student/models/student_results_data.dart';
import 'package:catuc_portal/student/models/student_timetable_data.dart';
import 'package:catuc_portal/student/models/student_course.dart';
import 'package:catuc_portal/student/models/student_course_detail_data.dart';
import 'package:catuc_portal/student/models/student_notes_data.dart';
import 'package:catuc_portal/student/models/student_enrollment_data.dart';
import 'package:catuc_portal/student/models/ai_chat_models.dart';
import 'package:catuc_portal/student/screens/ai/lesson_models.dart';
import 'package:catuc_portal/services/api_service.dart';
import 'package:catuc_portal/config/app_config.dart';
import 'package:uuid/uuid.dart';

class AiLimitReachedException implements Exception {
  final String message;
  final String planName;
  final int usedToday;
  final int dailyLimit;

  const AiLimitReachedException({
    required this.message,
    required this.planName,
    required this.usedToday,
    required this.dailyLimit,
  });

  factory AiLimitReachedException.fromPayload(Map<String, dynamic> payload) {
    final currentPlan = payload['current_plan'];
    final plan = currentPlan is Map ? Map<String, dynamic>.from(currentPlan) : const <String, dynamic>{};
    return AiLimitReachedException(
      message: (payload['message'] ?? 'Daily AI limit reached').toString(),
      planName: (plan['name'] ?? 'Free').toString(),
      usedToday: (payload['used_today'] is int) ? payload['used_today'] as int : int.tryParse('${payload['used_today'] ?? 0}') ?? 0,
      dailyLimit: (plan['daily_limit'] is int) ? plan['daily_limit'] as int : int.tryParse('${plan['daily_limit'] ?? 0}') ?? 0,
    );
  }

  @override
  String toString() => message;
}

class StudentApiService extends ApiService {
  const StudentApiService();

  String _newSessionId(String prefix) => '${prefix}_${const Uuid().v4()}';

  T? _extractJson<T>(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final candidates = <String>[
      text,
      text
          .replaceAll('```json', '```')
          .replaceAll('```JSON', '```')
          .replaceAll('```', '')
          .trim(),
    ];

    for (final candidate in candidates) {
      final direct = _tryDecodeJson<T>(candidate);
      if (direct != null) return direct;

      final extracted = _tryExtractBalancedJson<T>(candidate);
      if (extracted != null) return extracted;
    }

    return null;
  }

  List<String> _parseBulletList(String raw, {int maxItems = 12}) {
    final lines = raw
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final items = <String>[];
    for (final line in lines) {
      var cleaned = line;
      cleaned = cleaned.replaceFirst(RegExp(r'^[-*•]+\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'^\d+[\).\s-]+\s*'), '');
      cleaned = cleaned.trim();

      if (cleaned.isEmpty) continue;
      if (cleaned.length < 3) continue;
      if (cleaned.toLowerCase().startsWith('json')) continue;
      if (cleaned.startsWith('{') || cleaned.startsWith('[')) continue;
      if (cleaned.startsWith('```')) continue;

      items.add(cleaned);
      if (items.length >= maxItems) break;
    }

    // De-dupe (preserve order)
    final seen = <String>{};
    return items.where((e) => seen.add(e.toLowerCase())).toList();
  }

  T? _tryDecodeJson<T>(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is T) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  T? _tryExtractBalancedJson<T>(String input) {
    final start = input.indexOf(RegExp(r'[\[\{]'));
    if (start < 0) return null;

    final open = input[start];
    final close = open == '[' ? ']' : '}';

    var depth = 0;
    var inString = false;
    var escape = false;

    for (int i = start; i < input.length; i++) {
      final ch = input[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == '\\\\') {
        if (inString) escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == open) depth++;
      if (ch == close) depth--;

      if (depth == 0) {
        final slice = input.substring(start, i + 1);
        return _tryDecodeJson<T>(slice);
      }
    }

    return null;
  }

  Future<StudentSession> login({
    required String identifier,
    required String password,
    String role = 'student',
  }) async {
    final response = await postWithFallback(
      'login.php',
      body: {'identifier': identifier, 'password': password, 'role': role},
    );

    final data = parseResponse(response);
    return StudentSession.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
  }

  Future<Map<String, dynamic>> verifyIdentity({
    required String matricule,
    required String email,
  }) async {
    final response = await postWithFallback(
      'student_verify_identity.php',
      body: {'matricule': matricule, 'email': email},
    );
    return parseResponse(response);
  }

  Future<String> activateAccount({
    required String activationToken,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await postWithFallback(
      'student_activate_account.php',
      body: {
        'activation_token': activationToken,
        'password': password,
        'confirm_password': confirmPassword,
      },
    );
    final data = parseResponse(response);
    return (data['message'] ?? 'Account activated').toString();
  }

  Future<StudentHomeData> fetchHome(String studentId) async {
    final dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final localDay = dayNames[DateTime.now().weekday - 1];

    final data = await getWithCache('home.php', query: {
      'student_id': studentId,
      'local_day': localDay,
    }, maxAge: const Duration(minutes: 5));
    return StudentHomeData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<StudentCourse>> fetchCourses(String studentId) async {
    final data = await getWithCache('courses.php', query: {
      'student_id': studentId,
    }, maxAge: const Duration(minutes: 15));
    final rows = (data['courses'] as List<dynamic>? ?? []);
    return rows
        .map((e) => StudentCourse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StudentCourseDetailData> fetchCourseDetail({
    required String studentId,
    required String courseId,
  }) async {
    final data = await getWithCache(
      'student_course_detail.php',
      query: {'student_id': studentId, 'course_id': courseId},
    );
    return StudentCourseDetailData.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<StudentProfile> fetchProfile(String studentId) async {
    final data = await getWithCache('profile.php', query: {
      'student_id': studentId,
    });
    return StudentProfile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
  }

  Future<StudentResultsData> fetchResults({
    required String studentId,
    String? year,
    String? semester,
  }) async {
    final query = <String, String>{'student_id': studentId};
    if (year != null && year.isNotEmpty) query['year'] = year;
    if (semester != null && semester.isNotEmpty) query['sem'] = semester;

    final data = await getWithCache(
      'student_results.php',
      query: query,
    );
    return StudentResultsData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<NoteCourse>> fetchNoteCourses(String studentId) async {
    final data = await getWithCache('student_notes.php', query: {
      'student_id': studentId,
    });
    final rows = (data['courses'] as List<dynamic>? ?? []);
    return rows
        .map((e) => NoteCourse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<NoteMaterial>> fetchCourseMaterials({
    required String studentId,
    required String courseId,
  }) async {
    final data = await getWithCache('student_notes.php', query: {
      'student_id': studentId,
      'course_id': courseId,
    });
    final rows = (data['materials'] as List<dynamic>? ?? []);
    return rows
        .map((e) => NoteMaterial.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<EnrollmentData> fetchEnrollment({
    required String studentId,
    String? year,
    String? semester,
    int? level,
  }) async {
    final query = <String, String>{'student_id': studentId};
    if (year != null && year.isNotEmpty) query['year'] = year;
    if (semester != null && semester.isNotEmpty) query['sem'] = semester;
    if (level != null) query['level'] = '$level';

    final data = await getWithCache(
      'student_enrollment.php',
      query: query,
    );
    return EnrollmentData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<String> enrollCourses({
    required String studentId,
    required List<String> courseIds,
    required String year,
    required String semester,
    required int level,
  }) async {
    final response = await postWithFallback(
      'student_enrollment.php',
      query: {
        'student_id': studentId,
        'year': year,
        'sem': semester,
        'level': '$level',
      },
      body: {'action': 'enroll', 'course_ids': courseIds},
      offlineActionType: 'enroll_courses',
    );
    final data = parseResponse(response);
    return (data['message'] ?? 'Enrollment updated').toString();
  }

  Future<String> removeEnrollment({
    required String studentId,
    required String enrollmentId,
    required String year,
    required String semester,
    required int level,
  }) async {
    final response = await postWithFallback(
      'student_enrollment.php',
      query: {
        'student_id': studentId,
        'year': year,
        'sem': semester,
        'level': '$level',
      },
      body: {'action': 'remove', 'enrollment_id': enrollmentId},
    );
    final data = parseResponse(response);
    return (data['message'] ?? 'Enrollment removed').toString();
  }

  Future<List<TimetableSlot>> fetchTimetable({
    required String studentId,
    required String type,
    String? year,
    String? semester,
    bool forceRefresh = false,
    Duration maxAge = const Duration(minutes: 2),
  }) async {
    final query = <String, String>{'student_id': studentId, 'type': type};
    if (year != null && year.isNotEmpty) query['year'] = year;
    if (semester != null && semester.isNotEmpty) query['sem'] = semester;
    final data = await getWithCache(
      'student_timetable.php',
      query: query,
      maxAge: maxAge,
      forceRefresh: forceRefresh,
    );
    final rows = (data['slots'] as List<dynamic>? ?? []);
    return rows
        .map((e) => TimetableSlot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<HomeAnnouncement>> fetchAllAnnouncements(String studentId) async {
    final data = await getWithCache('student_announcements.php', query: {
      'student_id': studentId,
    });
    final rows = (data['announcements'] as List<dynamic>? ?? []);
    return rows
        .map(
          (e) => HomeAnnouncement.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<String> updateProfile({
    required String studentId,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String phoneNumber,
    required String gender,
  }) async {
    final response = await postWithFallback(
      'student_profile_update.php',
      body: {
        'student_id': studentId,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'phone_number': phoneNumber,
        'gender': gender,
      },
      offlineActionType: 'update_profile_student',
    );
    final data = parseResponse(response);
    return (data['message'] ?? 'Profile updated').toString();
  }

  Future<http.Response> postMultipart({
    required String endpoint,
    required Map<String, String> fields,
    required Map<String, String> files,
  }) async {
    final multipartFiles = <http.MultipartFile>[];
    for (final entry in files.entries) {
      multipartFiles.add(await http.MultipartFile.fromPath(entry.key, entry.value));
    }
    return await postMultipartWithFallback(endpoint, fields: fields, files: multipartFiles);
  }

  Stream<String> streamAiMessage({
    required String studentId,
    required String sessionId,
    required String message,
    required String aiType,
    bool includeHistory = true,
  }) async* {
    final client = http.Client();
    try {
      final body = {
        'action': 'send_message',
        'student_id': studentId,
        'session_id': sessionId,
        'message': message,
        'ai_type': aiType,
        'stream': true,
        'include_history': includeHistory,
      };
      final bodyJson = jsonEncode(body);

      Future<http.StreamedResponse> sendWithRedirects(http.Request initialRequest) async {
        var request = initialRequest;
        request.followRedirects = false;
        request.maxRedirects = 0;

        for (var redirectCount = 0; redirectCount < 3; redirectCount++) {
          final response = await client.send(request).timeout(const Duration(seconds: 120));

          if (response.isRedirect) {
            final location = response.headers['location'];
            if (location == null || location.trim().isEmpty) {
              return response;
            }

            // Drain the response body before re-trying, to avoid keeping sockets open.
            try {
              await response.stream.drain<void>();
            } catch (_) {}

            final nextUri = request.url.resolve(location);
            final next = http.Request(request.method, nextUri)
              ..headers.addAll(request.headers)
              ..body = bodyJson
              ..followRedirects = false
              ..maxRedirects = 0;

            request = next;
            continue;
          }

          return response;
        }

        // Too many redirects; send the last request once and return.
        return await client.send(request).timeout(const Duration(seconds: 120));
      }

      // Try each base URL until we find one that works
      for (final base in AppConfig.baseUrls) {
        try {
          for (final endpoint in const ['ai_chat', 'ai_chat.php']) {
            final uri = Uri.parse('$base/$endpoint');
            final request = http.Request('POST', uri);
            request.headers['Content-Type'] = 'application/json';
            request.body = bodyJson;

            final streamedResponse = await sendWithRedirects(request);

            if (streamedResponse.statusCode == 200) {
              final stream = streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter());

              await for (final line in stream) {
                if (line.startsWith('data: ')) {
                  final jsonStr = line.substring(6).trim();
                  if (jsonStr == '[DONE]' || jsonStr.isEmpty) continue;

                  try {
                    final decoded = jsonDecode(jsonStr);
                    if (decoded is Map) {
                      // Check for limit_reached or error first
                      if (decoded.containsKey('limit_reached') && decoded['limit_reached'] == true) {
                        yield jsonEncode(decoded); // Send the raw JSON so the UI can handle it
                        client.close();
                        return;
                      }
                      if (decoded.containsKey('error')) {
                        yield 'Error: ${decoded['error']}';
                        client.close();
                        return;
                      }

                      // Handle different response formats
                      String content = '';
                      if (decoded['choices'] != null) {
                        content = decoded['choices'][0]?['delta']?['content'] ??
                            decoded['choices'][0]?['delta']?['reasoning'] ??
                            decoded['choices'][0]?['message']?['content'] ?? '';
                      } else if (decoded['content'] != null) {
                        content = decoded['content'].toString();
                      }

                      if (content.isNotEmpty) {
                        yield content;
                      }
                    }
                  } catch (_) {
                    // If JSON parsing fails, try to extract content directly
                    if (line.contains('"content":') && line.contains('":')) {
                      try {
                        final contentMatch = RegExp(r'"content":\s*"([^"]*)"').firstMatch(line);
                        if (contentMatch != null) {
                          yield contentMatch.group(1) ?? '';
                        }
                      } catch (_) {
                        // If all else fails, yield the raw line (minus data: prefix)
                        if (jsonStr.length > 2) {
                          yield jsonStr;
                        }
                      }
                    }
                  }
                }
              }
              client.close();
              return; // Success, exit URLs loop
            } else {
              // Non-200 responses (like 401/403/422) won't stream SSE; surface the server error.
              final status = streamedResponse.statusCode;
              String bodyText = '';
              try {
                bodyText = await streamedResponse.stream.bytesToString();
              } catch (_) {}

              // For "request is invalid" cases, don't keep trying other URLs.
              if (status == 401 || status == 403 || status == 422) {
                try {
                  final decoded = jsonDecode(bodyText);
                  if (decoded is Map && decoded['message'] != null) {
                    yield 'Error: ${decoded['message']}';
                    client.close();
                    return;
                  }
                } catch (_) {}

                if (bodyText.trim().isNotEmpty) {
                  yield 'Error: HTTP $status - ${bodyText.trim()}';
                } else {
                  yield 'Error: HTTP $status from $uri';
                }
                client.close();
                return;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('AI Stream Error on $base: $e');
          continue; // Try next URL
        }
      }
      
      // If we get here, all URLs failed
      yield 'Error: Unable to connect to AI service. Please try again.';
    } catch (e) {
      yield 'Error: $e';
    } finally {
      client.close();
    }
  }


  Future<String> generateVoiceResponseFlexible({
    required String studentId,
    required String message,
    required String voiceName,
    required String language,
    double pitch = 1.0,
    double rate = 1.0,
  }) async {
    try {
      // Enforce concise, complete answers to avoid trailing off / incomplete JSON responses
      final enhancedMessage = '''
[SYSTEM INSTRUCTION: You are a friendly, helpful voice assistant. 
Respond CONCISELY. Keep your answer under 3 sentences. 
Do NOT trail off. Make sure your response is a complete, well-formed thought.]

User message: $message
''';

      final body = {
        'action': 'send_message',
        'student_id': studentId,
        'session_id': 'voice_session_${DateTime.now().millisecondsSinceEpoch}',
        'message': enhancedMessage,
        'ai_type': 'voice',
        'stream': false,
        'voice_settings': {
          'name': voiceName,
          'language': language,
          'pitch': pitch,
          'rate': rate,
        },
      };

      final response = await postWithFallback(
        'ai_chat',
        body: body,
        timeout: const Duration(seconds: 45),
      );

      final responseData = jsonDecode(response.body);
      if (responseData is Map && responseData['limit_reached'] == true) {
        throw AiLimitReachedException.fromPayload(Map<String, dynamic>.from(responseData));
      }
      if (responseData is Map && responseData['ok'] == true) {
        final data = responseData['data'];
        if (data is Map && data['response'] != null) return data['response'].toString();
        if (responseData['response'] != null) return responseData['response'].toString();
      }
      if (responseData is Map) {
        throw Exception(responseData['message'] ?? 'Failed to generate voice response');
      }
      throw Exception('Failed to generate voice response');
    } catch (e) {
      throw Exception('Voice response error: $e');
    }
  }

  Future<String> summarizeReadContent({
    required String studentId,
    required String sessionId,
    required String message,
    String mode = 'summarize',
    String? quizType,
  }) async {
    try {
      final body = {
        'action': 'catus_suite',
        'student_id': studentId,
        'session_id': sessionId,
        'message': message,
        'mode': mode,
      };
      if (quizType != null) body['quiz_type'] = quizType;

      final response = await postWithFallback(
        'summarize_document.php',
        body: body,
        timeout: const Duration(seconds: 120),
      );

      final data = parseResponse(response);
      return data['summary']?.toString() ?? 'No response generated';
    } catch (e) {
      throw Exception('Catu AI error: $e');
    }
  }

  Future<String> generatePracticeQuestions({
    required String studentId,
    required String content,
    String type = 'mcq',
  }) async {
    try {
      final response = await postWithFallback(
        'summarize_document.php',
        body: {
          'action': 'catus_suite',
          'student_id': studentId,
          'mode': 'quiz',
          'quiz_type': type,
          'content': content,
        },
        timeout: const Duration(seconds: 90),
      );

      final data = parseResponse(response);
      return data['summary']?.toString() ?? 'No questions generated';
    } catch (e) {
      throw Exception('Question generation error: $e');
    }
  }

  Future<String> askQuestionsAboutNotes({
    required String studentId,
    required String sessionId,
    required String notes,
    required String question,
  }) async {
    try {
      final response = await postWithFallback(
        'summarize_document.php',
        body: {
          'action': 'catus_suite',
          'student_id': studentId,
          'session_id': sessionId,
          'mode': 'questions',
          'content': '''
STUDENT QUESTION:
$question

$notes
''',
        },
        timeout: const Duration(seconds: 90),
      );

      final data = parseResponse(response);
      return data['summary']?.toString() ?? 'No answer generated';
    } catch (e) {
      throw Exception('Question answering error: $e');
    }
  }

  Future<StudentProfile> getStudentProfile(String studentId) async {
    try {
      final response = await postWithFallback(
        'student_profile.php',
        body: {'student_id': studentId},
      );

      final responseData = jsonDecode(response.body);
      if (responseData['ok'] == true && responseData['profile'] != null) {
        return StudentProfile.fromJson(responseData['profile']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      // Return a default profile if API fails
      return StudentProfile(
        fullName: 'Student',
        email: 'student@example.com',
        studentNumber: 'N/A',
        program: 'General Studies',
        department: 'General',
        faculty: 'General',
        level: '1',
        gender: 'N/A',
        phone: 'N/A',
        dateOfBirth: 'N/A',
      );
    }
  }

  Future<List<String>> fetchSuggestedTopics(
    String contextId, {
    required String studentId,
    String role = 'student',
    String? faculty,
    String? department,
    String? level,
    String? userQuery,
  }) async {
    try {
      String prompt;
      if (userQuery != null && userQuery.trim().isNotEmpty) {
        // Generate topics based on what user specifically wants to learn
        final levelStr = level != null ? ', Level $level' : '';
        final facultyStr = faculty != null ? ' in the Faculty of $faculty' : '';
        final deptStr = department != null ? ', Department of $department' : '';
        final program = role == 'teacher' ? contextId : contextId;
        
        prompt = 'You are an AI learning assistant. A$levelStr '
            '${role == 'teacher' ? 'lecturer' : 'student'} '
            'in the "$program" program$facultyStr$deptStr wants to learn about: "$userQuery". '
            'Generate 8 specific, relevant learning topics that directly relate to their interest. '
            'Topics should be specific and actionable, breaking down their interest into learnable components. '
            'For example, if they want to learn "Python", suggest topics like "Python Basics: Variables & Data Types", '
            '"Python Control Flow: Loops & Conditionals", "Python Functions: Definition & Usage", etc. '
            'Return ONLY a JSON array of strings. No extra text.';
      } else if (role == 'teacher') {
        prompt = 'You are an AI assistant for university lecturers. '
            'Generate 8 specific, practical topics that a university lecturer '
            'teaching the following courses: "$contextId" might want to explore '
            'for professional development, lesson preparation, or deeper subject mastery. '
            'Topics should be directly relevant to these subjects and useful for teaching. '
            'Return ONLY a JSON array of strings. No extra text.';
      } else {
        final levelStr = level != null ? ', Level $level' : '';
        final facultyStr = faculty != null ? ' in the Faculty of $faculty' : '';
        final deptStr = department != null ? ', Department of $department' : '';
        prompt = 'You are an AI tutor for university students. '
            'Generate 8 specific, practical academic topics that a$levelStr '
            'student in the "$contextId" program$facultyStr$deptStr should learn. '
            'Topics should be specific course-related concepts or skills, '
            'NOT generic subjects like "Mathematics" or "Science". '
            'For example, instead of "Mathematics" suggest "Linear Algebra: Matrix Operations" '
            'or "Calculus: Integration Techniques". '
            'Return ONLY a JSON array of strings. No extra text.';
      }

      final raw = await sendAiMessage(
        studentId: studentId,
        sessionId: _newSessionId('learn_topics'),
        message: prompt,
        aiType: 'learn',
        timeout: const Duration(seconds: 45),
      );

      final parsed = _extractJson<List<dynamic>>(raw);
      if (parsed != null) {
        return parsed.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
      final fallbackLines = _parseBulletList(raw, maxItems: 8);
      if (fallbackLines.isNotEmpty) return fallbackLines;
      return _getDefaultTopics(role, userQuery);
    } catch (e) {
      return _getDefaultTopics(role, userQuery);
    }
  }

  List<String> getDefaultTopics(String role, String? userQuery) {
    if (userQuery != null && userQuery.trim().isNotEmpty) {
      // Generate some basic fallback topics based on user's query
      final query = userQuery.toLowerCase();
      if (query.contains('python') || query.contains('programming') || query.contains('coding')) {
        return [
          'Python Basics: Variables & Data Types',
          'Python Control Flow: Loops & Conditionals',
          'Python Functions: Definition & Usage',
          'Python Data Structures: Lists & Dictionaries',
          'Python Object-Oriented Programming',
          'Python File Handling & I/O Operations',
          'Python Error Handling & Debugging',
          'Python Libraries & Frameworks',
        ];
      } else if (query.contains('math') || query.contains('calculus') || query.contains('algebra')) {
        return [
          'Mathematical Foundations & Notation',
          'Linear Algebra: Matrix Operations',
          'Calculus: Derivatives & Integration',
          'Differential Equations Basics',
          'Probability Theory Fundamentals',
          'Statistical Analysis Methods',
          'Mathematical Proof Techniques',
          'Applied Mathematics in Engineering',
        ];
      } else if (query.contains('web') || query.contains('html') || query.contains('css') || query.contains('javascript')) {
        return [
          'HTML5 Fundamentals & Semantic Markup',
          'CSS3 Styling & Layout Techniques',
          'JavaScript Programming Basics',
          'Responsive Web Design Principles',
          'Frontend Frameworks: React/Vue/Angular',
          'Backend Development with Node.js',
          'Database Design & Management',
          'Web Security Best Practices',
        ];
      } else {
        // Generic fallback based on the query
        return [
          '$userQuery: Introduction & Basics',
          '$userQuery: Core Concepts & Theory',
          '$userQuery: Practical Applications',
          '$userQuery: Advanced Techniques',
          '$userQuery: Problem-Solving Strategies',
          '$userQuery: Real-World Projects',
          '$userQuery: Best Practices & Standards',
          '$userQuery: Future Trends & Developments',
        ];
      }
    }
    
    // Original fallback topics when no user query
    if (role == 'teacher') {
      return [
        'Active Learning Strategies',
        'Bloom\'s Taxonomy in Practice',
        'Assessment Design',
        'Student Engagement Techniques',
        'Curriculum Development',
        'Educational Technology',
        'Research Methodology',
        'Academic Writing',
      ];
    }
    return [
      'Data Structures & Algorithms',
      'Academic Writing Skills',
      'Research Methodology',
      'Critical Thinking',
      'Project Management Basics',
      'Communication Skills',
      'Digital Literacy',
      'Problem Solving Techniques',
    ];
  }

  List<String> _getDefaultTopics(String role, String? userQuery) {
    return getDefaultTopics(role, userQuery);
  }

  Future<List<Map<String, String>>> generateLearningTopics({
    required String studentId,
    required String broadSubject,
    StudentProfile? studentProfile,
    String role = 'student',
  }) async {
    try {
      final program = studentProfile?.program ?? 'General Studies';
      final level = studentProfile?.level ?? '1';
      final persona = role == 'teacher'
          ? 'You are an AI learning architect for a university lecturer.'
          : 'You are an AI learning architect for a Level $level university student in the "$program" program.';

      final prompt = """
$persona The user wants to: "$broadSubject".
Break this down into 6-8 structured learning topics.
Each topic must be specific and teachable (module-sized), and should progress from fundamentals to projects/applications.
Return ONLY a JSON array of objects with keys:
- 'topic' (string)
- 'description' (string, 1 sentence)
""";

      final raw = await sendAiMessage(
        studentId: studentId,
        sessionId: _newSessionId('learn_path'),
        message: prompt,
        aiType: 'learn',
        timeout: const Duration(seconds: 45),
      );

      final parsed = _extractJson<List<dynamic>>(raw);
      if (parsed != null) {
        return parsed
            .map((item) => Map<String, dynamic>.from(item as Map))
            .map((m) => {
                  'topic': (m['topic'] ?? '').toString(),
                  'description': (m['description'] ?? '').toString(),
                })
            .where((m) => m['topic']!.trim().isNotEmpty)
            .toList();
      }
      final lines = _parseBulletList(raw, maxItems: 8);
      if (lines.isNotEmpty) {
        return lines
            .map((t) => {'topic': t, 'description': 'A focused module on $t.'})
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error generating topics: $e');
      return [];
    }
  }

  Future<List<Lesson>> generateLearningLessons({
    required String studentId,
    required String topic,
    StudentProfile? studentProfile,
    String role = 'student',
    String? contextLabel,
    bool generateOutlineOnly = false,
  }) async {
    try {
      String prompt;
      if (role == 'teacher') {
        prompt = """
You are an AI course designer for a university lecturer who teaches: ${contextLabel ?? 'various courses'}.
Generate a structured learning module for the topic: "$topic".
Create exactly 6-8 well-organized lessons that progress from foundational concepts to advanced application.
Each lesson should have a clear, specific title (not vague), a detailed 2-3 sentence description, an estimated duration, a difficulty level, and 3-5 learning objectives.
Return ONLY a JSON array of objects with keys: 'title', 'description', 'duration', 'difficulty', 'objectives' (array of strings).
""";
      } else {
        final program = studentProfile?.program ?? 'General Studies';
        final level = studentProfile?.level ?? '1';
        prompt = """
You are an AI tutor for a Level $level university student in the "$program" program.
Generate a structured learning module for the topic: "$topic".
Create exactly 6-8 well-organized lessons that progress from foundational concepts to advanced application.
Each lesson should have a clear, specific title (not vague), a detailed 2-3 sentence description, an estimated duration, a difficulty level, and 3-5 learning objectives.
Return ONLY a JSON array of objects with keys: 'title', 'description', 'duration', 'difficulty', 'objectives' (array of strings).
""";
      }

      final raw = await sendAiMessage(
        studentId: studentId,
        sessionId: _newSessionId('learn_outline'),
        message: prompt,
        aiType: 'learn',
        timeout: const Duration(seconds: 60),
      );

      final parsed = _extractJson<List<dynamic>>(raw);
      if (parsed != null) {
        final lessons = parsed
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((m) {
              final objectives = (m['objectives'] is List)
                  ? List<String>.from((m['objectives'] as List).map((e) => e.toString()))
                  : const <String>[];
              return Lesson(
                title: (m['title'] ?? '').toString(),
                description: (m['description'] ?? '').toString(),
                duration: (m['duration'] ?? '30 minutes').toString(),
                difficulty: (m['difficulty'] ?? 'Beginner').toString(),
                objectives: objectives,
                exercises: const [],
                isContentGenerated: false,
              );
            })
            .where((l) => l.title.trim().isNotEmpty)
            .toList();
        if (lessons.isNotEmpty) return lessons;
      }

      final lines = _parseBulletList(raw, maxItems: 10);
      if (lines.isNotEmpty) {
        return lines
            .map((title) => Lesson(
                  title: title,
                  description: 'Learn $title with explanations, examples, and practice.',
                  duration: '30 minutes',
                  difficulty: 'Beginner',
                  objectives: const [],
                  exercises: const [],
                  isContentGenerated: false,
                ))
            .toList();
      }

      return _getDefaultLessons(topic);
    } catch (e) {
      debugPrint('Error generating lessons: $e');
      return _getDefaultLessons(topic);
    }
  }

  Future<Lesson> generateSpecificLesson({
    required String studentId,
    required String topic,
    required String lessonTitle,
    required String lessonDescription,
    StudentProfile? studentProfile,
    String role = 'student',
    String? contextLabel,
  }) async {
    try {
      String prompt;
      if (role == 'teacher') {
        prompt = """
You are an AI course designer for a university lecturer who teaches: ${contextLabel ?? 'various courses'}.
Generate comprehensive content for a lesson titled "$lessonTitle" under the topic "$topic".
The lesson description is: "$lessonDescription".

Create detailed content including:
1. A comprehensive explanation in Markdown format
2. Practical real-world examples in Markdown format  
3. 5 interactive exercises with different types (multiple choice, text, code)

Return ONLY a JSON object with keys:
- 'explanation': Detailed explanation in Markdown
- 'example': Practical examples in Markdown
- 'exercises': Array of exercise objects with keys: 'question', 'type', 'options', 'answer', 'explanation'
""";
      } else {
        final program = studentProfile?.program ?? 'General Studies';
        final level = studentProfile?.level ?? '1';
        prompt = """
You are an AI tutor for a Level $level university student in the "$program" program.
Generate comprehensive content for a lesson titled "$lessonTitle" under the topic "$topic".
The lesson description is: "$lessonDescription".

Create detailed content including:
1. A comprehensive explanation in Markdown format with clear concepts and theories
2. Practical real-world examples in Markdown format that demonstrate the concepts
3. 5 interactive exercises with different types (multiple choice, text, code) to test understanding

Return ONLY a JSON object with keys:
- 'explanation': Detailed explanation in Markdown
- 'example': Practical examples in Markdown
- 'exercises': Array of exercise objects with keys: 'question', 'type', 'options', 'answer', 'explanation'
""";
      }

      final raw = await sendAiMessage(
        studentId: studentId,
        sessionId: _newSessionId('learn_lesson'),
        message: prompt,
        aiType: 'learn',
        timeout: const Duration(seconds: 90),
      );

      final lessonData = _extractJson<Map<String, dynamic>>(raw);
      if (lessonData != null) {
        
        // Create exercises from the response
        final exercisesList = lessonData['exercises'] as List? ?? [];
        final exercises = exercisesList.map((ex) => Exercise.fromJson(Map<String, dynamic>.from(ex as Map))).toList();
        
        return Lesson(
          title: lessonTitle,
          description: lessonDescription,
          duration: '30 minutes', // Default duration
          difficulty: 'Intermediate', // Default difficulty
          objectives: [], // Will be populated later if needed
          exercises: exercises,
          explanation: lessonData['explanation']?.toString(),
          example: lessonData['example']?.toString(),
          isContentGenerated: true,
        );
      } else {
        final markdown = raw.trim().isEmpty
            ? '# $lessonTitle\n\nThis lesson covers important concepts related to $topic.'
            : raw.trim();
        return Lesson(
          title: lessonTitle,
          description: lessonDescription,
          duration: '30 minutes',
          difficulty: 'Intermediate',
          objectives: ['Understand $lessonTitle', 'Practice with examples'],
          exercises: [
            Exercise(
              question: 'Summarize the key idea of "$lessonTitle" in your own words.',
              type: 'text',
              answer: 'Your summary should mention the core concept and why it matters.',
              explanation: 'Focus on the main concept and one practical use-case.',
            ),
          ],
          explanation: markdown,
          example: 'Try applying "$lessonTitle" to a real-world scenario you know.',
          isContentGenerated: true,
        );
      }
    } catch (e) {
      debugPrint('Error generating specific lesson: $e');
      // Return a basic fallback lesson
      return Lesson(
        title: lessonTitle,
        description: lessonDescription,
        duration: '30 minutes',
        difficulty: 'Intermediate',
        objectives: ['Understand the basic concepts', 'Apply practical examples'],
        exercises: [
          Exercise(
            question: 'What did you learn from this lesson?',
            type: 'text',
            answer: 'Your answer here',
          ),
        ],
        explanation: '# $lessonTitle\n\nThis lesson covers important concepts related to $topic. Please review the material and complete the exercises.',
        example: 'Example: A practical application of $lessonTitle in real-world scenarios.',
        isContentGenerated: true,
      );
    }
  }

  Future<Map<String, dynamic>> getFullLessonContent({
    required String studentId,
    required String lessonTitle,
    required String topic,
  }) async {
    try {
      final prompt = """
Generate comprehensive content for a lesson titled "$lessonTitle" under the topic "$topic".
Format the response as a JSON object with these keys:
- 'explanation': Extensive detailed explanation in Markdown.
- 'example': Practical real-world examples in Markdown.
- 'exercises': A list of 5 interactive exercises. Each exercise object should have:
  - 'question': The question text.
  - 'type': 'multiple_choice', 'text', or 'code'.
  - 'options': (For multiple_choice) a list of 4 options.
  - 'answer': The correct answer.
  - 'explanation': A short explanation of the solution.
""";

      final raw = await sendAiMessage(
        studentId: studentId,
        sessionId: _newSessionId('learn_lesson'),
        message: prompt,
        aiType: 'learn',
        timeout: const Duration(seconds: 90),
      );

      final parsed = _extractJson<Map<String, dynamic>>(raw);
      if (parsed != null) return parsed;
      return {
        'explanation': raw.trim().isEmpty
            ? '# $lessonTitle\n\nThis lesson covers important concepts related to $topic.'
            : raw.trim(),
        'example': '',
        'exercises': [],
      };
    } catch (e) {
      throw Exception('AI content error: $e');
    }
  }

  Future<Map<String, dynamic>> verifyExercises({
    required String studentId,
    required String lessonTitle,
    required List<Map<String, String>> userAnswers,
  }) async {
    try {
      final body = {
        'action': 'verify_exercises',
        'student_id': studentId,
        'lesson_title': lessonTitle,
        'user_answers': userAnswers,
        'ai_type': 'learn',
      };

      final response = await postWithFallback(
        'ai_chat',
        body: body,
        timeout: const Duration(seconds: 60),
      );

      final data = parseResponse(response);
      return Map<String, dynamic>.from(data['verification'] as Map);
    } catch (e) {
      // Return a basic fallback if AI verify fails
      return {
        'score': 0,
        'feedback': 'We could not connect to Catu AI to verify your answers at this time. Please check your connection and try again.',
        'detailed_feedback': [],
      };
    }
  }

  List<Lesson> _getDefaultLessons(String topic) {
    return [
      Lesson(
        title: 'Introduction to $topic',
        description: 'Learn the fundamental concepts and basics of $topic.',
        duration: '30 minutes',
        difficulty: 'Beginner',
        objectives: [
          'Understand the basic concepts of $topic',
          'Learn key terminology',
          'Identify main components',
        ],
        exercises: [
          Exercise(
            question: 'What is $topic?',
            type: 'text',
            answer: 'A fundamental concept in this field',
          ),
          Exercise(
            question: 'Which of the following are key components of $topic?',
            type: 'multiple_choice',
            options: ['Option A', 'Option B', 'Option C', 'Option D'],
            answer: 'Option A',
          ),
        ],
      ),
      Lesson(
        title: 'Advanced $topic Concepts',
        description: 'Explore advanced topics and practical applications of $topic.',
        duration: '45 minutes',
        difficulty: 'Intermediate',
        objectives: [
          'Apply $topic concepts to real problems',
          'Analyze complex scenarios',
          'Develop practical skills',
        ],
        exercises: [
          Exercise(
            question: 'Write a simple example demonstrating $topic:',
            type: 'code',
            answer: 'Example code solution',
          ),
          Exercise(
            question: 'How would you apply $topic in a real-world scenario?',
            type: 'text',
            answer: 'Real-world application explanation',
          ),
        ],
      ),
      Lesson(
        title: 'Practical Applications of $topic',
        description: 'Hands-on exercises and projects using $topic.',
        duration: '60 minutes',
        difficulty: 'Advanced',
        objectives: [
          'Create complete projects',
          'Solve complex problems',
          'Master advanced techniques',
        ],
        exercises: [
          Exercise(
            question: 'Build a complete project using $topic concepts:',
            type: 'code',
            answer: 'Complete project solution',
          ),
        ],
      ),
    ];
  }

  String _getDefaultLessonContent(String title, List<String> objectives) {
    return '''
# $title

## Learning Objectives
${objectives.map((obj) => '- $obj').join('\n')}

## Introduction
Welcome to this lesson on $title. This comprehensive guide will help you master the key concepts and practical applications.

## Main Content

### Section 1: Understanding the Basics
In this section, we'll cover the fundamental concepts that form the foundation of this topic. Pay close attention as these basics will be crucial for understanding more advanced topics later.

### Section 2: Core Concepts
Here we dive deeper into the main concepts. Each concept is explained with clear examples and practical applications.

### Section 3: Practical Examples
Theory is important, but practice makes perfect. Let's explore some real-world examples that demonstrate how these concepts work in practice.

### Section 4: Best Practices
Learn the industry best practices and common patterns that professionals use in real-world scenarios.

## Summary
You've now covered the essential content of this lesson. Take a moment to review what you've learned before proceeding to the exercises.

## Key Takeaways
- Understanding the fundamental concepts is crucial
- Practical application reinforces theoretical knowledge
- Best practices help in professional development
- Continuous practice leads to mastery

## Next Steps
After completing this lesson, consider:
1. Reviewing the material periodically
2. Practicing with additional examples
3. Exploring advanced topics
4. Applying concepts to personal projects

Good luck with your exercises!
''';
  }

  Future<String> changePassword({
    required String studentId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await postWithFallback(
      'student_change_password.php',
      body: {
        'student_id': studentId,
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    final data = parseResponse(response);
    return (data['message'] ?? 'Password updated').toString();
  }

  Future<void> submitReport(Map<String, dynamic> reportData) async {
    final response = await postWithFallback(
      'submit_report.php',
      body: reportData,
      offlineActionType: 'submit_report',
    );
    parseResponse(response);
  }

  // --- AI FEATURES ---

  Future<String> sendAiMessage({
    required String studentId,
    required String sessionId,
    required String message,
    required String aiType,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final response = await postWithFallback(
      'ai_chat',
      body: {
        'action': 'send_message',
        'student_id': studentId,
        'session_id': sessionId,
        'message': message,
        'ai_type': aiType,
      },
      timeout: timeout,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['limit_reached'] == true) {
      throw AiLimitReachedException.fromPayload(Map<String, dynamic>.from(decoded));
    }
    if (decoded is Map && decoded['ok'] == true) {
      final data = decoded['data'];
      if (data is Map && data['response'] != null) return data['response'].toString();
      if (decoded['response'] != null) return decoded['response'].toString();
      throw Exception('AI returned an empty response');
    }
    if (decoded is Map) {
      throw Exception(decoded['message'] ?? 'Request failed');
    }
    throw Exception('Request failed');
  }

  Future<List<AIChatMessage>> fetchAiHistory(String sessionId) async {
    final response = await postWithFallback(
      'ai_chat',
      body: {
        'action': 'fetch_history',
        'session_id': sessionId,
      },
    );
    final data = parseResponse(response);
    final rows = (data['messages'] as List<dynamic>? ?? []);
    return rows.map((e) => AIChatMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<AIChatSession>> fetchAiSessions({
    required String studentId,
    String? aiType,
  }) async {
    final body = {
      'action': 'fetch_sessions',
      'student_id': studentId,
    };
    if (aiType != null) body['ai_type'] = aiType;

    final response = await postWithFallback(
      'ai_chat',
      body: body,
    );
    final data = parseResponse(response);
    final rows = (data['sessions'] as List<dynamic>? ?? []);
    return rows.map((e) => AIChatSession.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> deleteAiSession(String sessionId) async {
    final response = await postWithFallback(
      'ai_chat',
      body: {
        'action': 'delete_session',
        'session_id': sessionId,
      },
    );
    parseResponse(response);
  }

  Future<Map<String, dynamic>> checkAiUsage(String studentId) async {
    final response = await postWithFallback(
      'ai_usage.php',
      body: {
        'action': 'check_usage',
        'student_id': studentId,
      },
    );
    final data = parseResponse(response);
    return data;
  }

  Future<List<Map<String, dynamic>>> fetchAiPlans() async {
    final response = await postWithFallback(
      'ai_usage.php',
      body: {'action': 'get_plans'},
    );
    final data = parseResponse(response);
    return List<Map<String, dynamic>>.from(data['plans'] ?? []);
  }
}
