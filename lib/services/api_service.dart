import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// const String baseUrl = 'http://192.168.100.170:3000/api'; // Android emulator
const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://student-management-backend-1-ilp9.onrender.com/api',
);

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token.trim());
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final decoded = jsonDecode(res.body);
    if (decoded is String) return {'error': decoded};
    return decoded;
  }

  static Future<Map<String, dynamic>> getMyProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/profile/me'),
      headers: await authHeaders(),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMyAvatar(String avatarUrl) async {
    final res = await http.put(
      Uri.parse('$baseUrl/profile/avatar'),
      headers: await authHeaders(),
      body: jsonEncode({'avatar_url': avatarUrl}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final res = await http.put(
      Uri.parse('$baseUrl/profile/change-password'),
      headers: await authHeaders(),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(decoded is Map ? decoded['message']?.toString() ?? decoded.toString() : decoded.toString());
    }
    return decoded is Map<String, dynamic> ? decoded : {'raw': decoded};
  }

  static Future<dynamic> getStudents({String? className}) async {
    final url = className != null && className.isNotEmpty
        ? '$baseUrl/students?className=${Uri.encodeComponent(className)}'
        : '$baseUrl/students';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<void> addStudent(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/students'), headers: await authHeaders(), body: jsonEncode(data));
    if (res.statusCode >= 400) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? decoded['message'] ?? 'Thêm sinh viên thất bại');
    }
  }

  static Future<void> updateStudent(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/students/$id'), headers: await authHeaders(), body: jsonEncode(data));
    if (res.statusCode >= 400) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? decoded['message'] ?? 'Cập nhật sinh viên thất bại');
    }
  }

  static Future<void> deleteStudent(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/students/$id'), headers: await authHeaders());
    if (res.statusCode >= 400) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? decoded['message'] ?? 'Xóa sinh viên thất bại');
    }
  }

  // --- TEACHERS ---
  static Future<List> getTeachers({String? teacherCode}) async {
    final url = teacherCode != null && teacherCode.isNotEmpty
        ? '$baseUrl/teachers?teacherCode=${Uri.encodeComponent(teacherCode)}'
        : '$baseUrl/teachers';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<void> addTeacher(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/teachers'), headers: await authHeaders(), body: jsonEncode(data));
    if (res.statusCode >= 400) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? decoded['message'] ?? 'Thêm giáo viên thất bại');
    }
  }

  static Future<void> updateTeacher(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/teachers/$id'), headers: await authHeaders(), body: jsonEncode(data));
    if (res.statusCode >= 400) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? decoded['message'] ?? 'Cập nhật giáo viên thất bại');
    }
  }

  static Future<void> deleteTeacher(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/teachers/$id'), headers: await authHeaders());
    if (res.statusCode >= 400) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? decoded['message'] ?? 'Xóa giáo viên thất bại');
    }
  }

  static Future<List> getGrades({int? studentId, int? semesterId, String? className}) async {
    final params = <String>[];
    if (studentId != null) params.add('studentId=$studentId');
    if (semesterId != null) params.add('semesterId=$semesterId');
    if (className != null && className.isNotEmpty) params.add('className=$className');
    final url = params.isNotEmpty ? '$baseUrl/grades?${params.join('&')}' : '$baseUrl/grades';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<void> addGrade(Map<String, dynamic> data) async {
    await http.post(Uri.parse('$baseUrl/grades'), headers: await authHeaders(), body: jsonEncode(data));
  }

  static Future<void> updateGrade(int id, Map<String, dynamic> data) async {
    await http.put(Uri.parse('$baseUrl/grades/$id'), headers: await authHeaders(), body: jsonEncode(data));
  }

  static Future<List> getSemesters({String? className}) async {
    var uri = Uri.parse('$baseUrl/semesters');
    if (className != null) {
      uri = uri.replace(queryParameters: {'class_name': className});
    }
    final res = await http.get(uri, headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<void> addSemester(Map<String, dynamic> data) async {
    await http.post(Uri.parse('$baseUrl/semesters'), headers: await authHeaders(), body: jsonEncode(data));
  }

  static Future<void> updateSemester(int id, Map<String, dynamic> data) async {
    await http.put(Uri.parse('$baseUrl/semesters/$id'), headers: await authHeaders(), body: jsonEncode(data));
  }

  static Future<void> deleteSemester(int id) async {
    await http.delete(Uri.parse('$baseUrl/semesters/$id'), headers: await authHeaders());
  }

  static Future<List> getCourses({int? semesterId, String? className}) async {
    final params = <String>[];
    if (semesterId != null) params.add('semester_id=$semesterId');
    if (className != null && className.isNotEmpty) params.add('class_name=${Uri.encodeComponent(className)}');
    final url = params.isNotEmpty ? '$baseUrl/courses?${params.join('&')}' : '$baseUrl/courses';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<void> addCourse(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/courses'), headers: await authHeaders(), body: jsonEncode(data));
    if (res.statusCode >= 400) {
      String message = 'Lỗi ${res.statusCode}: Không thể thêm môn học';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          message = decoded['message']?.toString()
              ?? decoded['detail']?.toString()
              ?? decoded['error']?.toString()
              ?? decoded.toString();
        } else if (decoded is String) {
          message = 'Lỗi ${res.statusCode}: $decoded';
        }
      } catch (_) {
        message = 'Lỗi ${res.statusCode}: ${res.body}';
      }
      throw Exception(message);
    }
  }

  static Future<void> updateCourse(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/courses/$id'), headers: await authHeaders(), body: jsonEncode(data));
    if (res.statusCode >= 400) {
      String message = 'Lỗi ${res.statusCode}: Không thể cập nhật môn học';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          message = decoded['message']?.toString() ?? decoded['error']?.toString() ?? decoded.toString();
        } else if (decoded is String) {
          message = 'Lỗi ${res.statusCode}: $decoded';
        }
      } catch (_) {
        message = 'Lỗi ${res.statusCode}: ${res.body}';
      }
      throw Exception(message);
    }
  }

  static Future<void> deleteCourse(int id) async {
    await http.delete(Uri.parse('$baseUrl/courses/$id'), headers: await authHeaders());
  }

  static Future<List> getAttendanceSessions({String? className, int? courseId}) async {
    final params = <String>[];
    if (className != null && className.isNotEmpty) params.add('className=$className');
    if (courseId != null) params.add('courseId=$courseId');
    final url = params.isNotEmpty ? '$baseUrl/attendance/sessions?${params.join('&')}' : '$baseUrl/attendance/sessions';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getAttendanceSession(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/attendance/sessions/$id'), headers: await authHeaders());
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> addAttendanceSession(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/attendance/sessions'), headers: await authHeaders(), body: jsonEncode(data));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List> getAttendanceRecords({int? sessionId, int? studentId}) async {
    final params = <String>[];
    if (sessionId != null) params.add('sessionId=$sessionId');
    if (studentId != null) params.add('studentId=$studentId');
    final url = params.isNotEmpty ? '$baseUrl/attendance/records?${params.join('&')}' : '$baseUrl/attendance/records';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addAttendanceRecordsBulk(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/attendance/records/bulk'), headers: await authHeaders(), body: jsonEncode(data));
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(decoded is Map ? decoded['message']?.toString() ?? decoded.toString() : decoded.toString());
    }
    return decoded is Map<String, dynamic> ? decoded : {'raw': decoded};
  }

  static Future<void> updateAttendanceRecord(int id, Map<String, dynamic> data) async {
    await http.put(Uri.parse('$baseUrl/attendance/records/$id'), headers: await authHeaders(), body: jsonEncode(data));
  }

  static Future<List> getAttendanceSummary({int? studentId, String? className, int? courseId}) async {
    final params = <String>[];
    if (studentId != null) params.add('studentId=$studentId');
    if (className != null && className.isNotEmpty) params.add('className=$className');
    if (courseId != null) params.add('courseId=$courseId');
    final url = params.isNotEmpty ? '$baseUrl/attendance/summary?${params.join('&')}' : '$baseUrl/attendance/summary';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<List> getTuitionInvoices({int? studentId}) async {
    final url = studentId != null ? '$baseUrl/fees/invoices?studentId=$studentId' : '$baseUrl/fees/invoices';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addTuitionInvoice(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/fees/invoices'), headers: await authHeaders(), body: jsonEncode(data));
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      if (res.statusCode >= 400) {
        throw Exception('Tạo hóa đơn thất bại (${res.statusCode}): ${res.body}');
      }
      throw Exception('Phản hồi không hợp lệ từ server: ${res.body}');
    }
    if (res.statusCode >= 400) {
      throw Exception(decoded is Map ? decoded['message']?.toString() ?? decoded.toString() : decoded.toString());
    }
    return decoded is Map<String, dynamic> ? decoded : {'raw': decoded};
  }

  static Future<void> updateTuitionInvoice(int id, Map<String, dynamic> data) async {
    await http.put(Uri.parse('$baseUrl/fees/invoices/$id'), headers: await authHeaders(), body: jsonEncode(data));
  }

  static Future<void> deleteTuitionInvoice(int id) async {
    await http.delete(Uri.parse('$baseUrl/fees/invoices/$id'), headers: await authHeaders());
  }

  static Future<List> getTuitionPayments({int? studentId}) async {
    final url = studentId != null ? '$baseUrl/fees/payments?studentId=$studentId' : '$baseUrl/fees/payments';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<void> addTuitionPayment(Map<String, dynamic> data) async {
    await http.post(Uri.parse('$baseUrl/fees/payments'), headers: await authHeaders(), body: jsonEncode(data));
  }

  static Future<List> getTuitionSummary({int? studentId}) async {
    final url = studentId != null ? '$baseUrl/fees/summary?studentId=$studentId' : '$baseUrl/fees/summary';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<List> getSchedules({String? type, String? className}) async {
    final params = <String>[];
    if (type != null && type.isNotEmpty) params.add('type=$type');
    if (className != null && className.isNotEmpty) params.add('className=${Uri.encodeComponent(className)}');
    final url = params.isNotEmpty ? '$baseUrl/schedules?${params.join('&')}' : '$baseUrl/schedules';
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addSchedule(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/schedules'), headers: await authHeaders(), body: jsonEncode(data));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateSchedule(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/schedules/$id'), headers: await authHeaders(), body: jsonEncode(data));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteSchedule(int id) async {
    await http.delete(Uri.parse('$baseUrl/schedules/$id'), headers: await authHeaders());
  }
}
