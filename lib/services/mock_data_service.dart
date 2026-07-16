import 'dart:math';
import 'api_service.dart';

/// Service cung cấp dữ liệu mẫu cho các màn hình khi backend chưa sẵn sàng
/// hoặc khi cần demo UI. Mọi method trả về `Future` với delay giả lập.
///
/// Schema canonical (áp dụng cho tất cả entity):
/// - Sinh viên: { id, student_id, student_code, full_name, class_id, class_code, class_name }
/// - Môn học : { subject_code, subject_name, credits, exam_form }
/// - Lớp     : { class_id, class_code, class_name }
/// - Học kỳ  : { semester_id, semester_name } - format thống nhất "Học kỳ N - YYYY-YYYY"
/// - Điểm    : { cc_score, qkt_score, ckt_score, total_score, grade, status }
///   - status: 'pass' khi total_score >= [kPassThreshold], ngược lại 'fail'
/// - Điểm danh SV: status ∈ { present, late, absent, unmarked, excused }
class MockDataService {
  static final _rand = Random();

  /// Ngưỡng đạt duy nhất cho toàn hệ thống (đồng bộ với grades_screen dialog).
  static const double kPassThreshold = 4.0;

  // ============ CANONICAL DATA SOURCES (dùng chung) ============

  /// 12 môn theo ngành — IT* CNTT, IS* ATTT, SE* KTPM.
  static const List<Map<String, dynamic>> canonicalSubjects = [
    // CNTT
    {'subject_code': 'IT001', 'subject_name': 'Lập trình cơ bản', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'IT002', 'subject_name': 'Cơ sở dữ liệu', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'IT003', 'subject_name': 'Cấu trúc dữ liệu & Giải thuật', 'credits': 4, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'IT004', 'subject_name': 'Lập trình Web', 'credits': 3, 'exam_form': 'Thực hành + Lý thuyết'},
    {'subject_code': 'IT005', 'subject_name': 'Mạng máy tính', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'IT006', 'subject_name': 'Trí tuệ nhân tạo', 'credits': 3, 'exam_form': 'Đồ án'},
    // ATTT
    {'subject_code': 'IS002', 'subject_name': 'Mật mã ứng dụng', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'IS003', 'subject_name': 'An toàn mạng', 'credits': 3, 'exam_form': 'Thực hành + Lý thuyết'},
    {'subject_code': 'IS004', 'subject_name': 'Bảo mật hệ thống thông tin', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'IS005', 'subject_name': 'Phân tích mã độc', 'credits': 3, 'exam_form': 'Thực hành'},
    {'subject_code': 'IS006', 'subject_name': 'Kiểm thử xâm nhập', 'credits': 3, 'exam_form': 'Thực hành'},
    // KTPM
    {'subject_code': 'SE001', 'subject_name': 'Phân tích yêu cầu phần mềm', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'SE002', 'subject_name': 'Thiết kế phần mềm', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'SE003', 'subject_name': 'Kiến trúc phần mềm', 'credits': 3, 'exam_form': 'Lý thuyết'},
    {'subject_code': 'SE004', 'subject_name': 'Kiểm thử phần mềm', 'credits': 3, 'exam_form': 'Thực hành + Lý thuyết'},
    {'subject_code': 'SE005', 'subject_name': 'DevOps & CI/CD', 'credits': 3, 'exam_form': 'Thực hành'},
    {'subject_code': 'SE006', 'subject_name': 'Công nghệ phần mềm nâng cao', 'credits': 3, 'exam_form': 'Đồ án'},
  ];

  /// 3 học kỳ gần nhất — format thống nhất.
  static const List<Map<String, dynamic>> canonicalSemesters = [
    {'id': 1, 'semester_id': 1, 'name': 'Học kỳ 1 - 2024-2025', 'semester_name': 'Học kỳ 1 - 2024-2025', 'start_date': '2024-09-01', 'end_date': '2024-12-31', 'status': 'finished', 'class_name': 'CNTT01'},
    {'id': 2, 'semester_id': 2, 'name': 'Học kỳ 2 - 2024-2025', 'semester_name': 'Học kỳ 2 - 2024-2025', 'start_date': '2025-01-15', 'end_date': '2025-05-31', 'status': 'finished', 'class_name': 'CNTT01'},
    {'id': 3, 'semester_id': 3, 'name': 'Học kỳ 1 - 2025-2026', 'semester_name': 'Học kỳ 1 - 2025-2026', 'start_date': '2025-09-01', 'end_date': '2025-12-31', 'status': 'active', 'class_name': 'CNTT01'},
  ];

  /// 4 lớp — là nguồn duy nhất cho mọi dropdown lớp.
  static const List<Map<String, dynamic>> canonicalClasses = [
    {'class_id': 1, 'class_code': 'CNTT01', 'class_name': 'CNTT01'},
    {'class_id': 2, 'class_code': 'CNTT02', 'class_name': 'CNTT02'},
    {'class_id': 3, 'class_code': 'ATTT01', 'class_name': 'ATTT01'},
    {'class_id': 4, 'class_code': 'KTPM01', 'class_name': 'KTPM01'},
  ];

  /// 40 sinh viên — nguồn duy nhất, dùng cho Attendance, Grades, Tuition.
  /// Thứ tự + lớp + tên phải KHỚP 100% với students_screen `_mockStudents()`.
  static final List<Map<String, dynamic>> canonicalStudents = [
    // CNTT01 (11 SV)
    {'student_id': 1, 'student_code': 'SV001', 'full_name': 'Nguyễn Văn An', 'class_name': 'CNTT01'},
    {'student_id': 2, 'student_code': 'SV002', 'full_name': 'Trần Thị Bình', 'class_name': 'CNTT01'},
    {'student_id': 3, 'student_code': 'SV003', 'full_name': 'Lê Hoàng Cường', 'class_name': 'CNTT01'},
    {'student_id': 4, 'student_code': 'SV004', 'full_name': 'Phạm Thị Dung', 'class_name': 'CNTT01'},
    {'student_id': 5, 'student_code': 'SV005', 'full_name': 'Hoàng Minh Đức', 'class_name': 'CNTT01'},
    {'student_id': 6, 'student_code': 'SV006', 'full_name': 'Võ Thị Hoa', 'class_name': 'CNTT01'},
    {'student_id': 7, 'student_code': 'SV007', 'full_name': 'Đặng Quốc Huy', 'class_name': 'CNTT01'},
    {'student_id': 8, 'student_code': 'SV008', 'full_name': 'Bùi Thị Lan', 'class_name': 'CNTT01'},
    {'student_id': 9, 'student_code': 'SV009', 'full_name': 'Ngô Văn Khánh', 'class_name': 'CNTT01'},
    {'student_id': 10, 'student_code': 'SV010', 'full_name': 'Đinh Thị Linh', 'class_name': 'CNTT01'},
    {'student_id': 36, 'student_code': 'SV036', 'full_name': 'Ứng Thị Cẩm', 'class_name': 'CNTT01'},
    // CNTT02 (10 SV)
    {'student_id': 11, 'student_code': 'SV011', 'full_name': 'Trương Văn Minh', 'class_name': 'CNTT02'},
    {'student_id': 12, 'student_code': 'SV012', 'full_name': 'Phan Thị Ngọc', 'class_name': 'CNTT02'},
    {'student_id': 13, 'student_code': 'SV013', 'full_name': 'Lý Hoàng Phúc', 'class_name': 'CNTT02'},
    {'student_id': 14, 'student_code': 'SV014', 'full_name': 'Vũ Thị Quỳnh', 'class_name': 'CNTT02'},
    {'student_id': 15, 'student_code': 'SV015', 'full_name': 'Tô Văn Sơn', 'class_name': 'CNTT02'},
    {'student_id': 16, 'student_code': 'SV016', 'full_name': 'Hồ Thị Trang', 'class_name': 'CNTT02'},
    {'student_id': 17, 'student_code': 'SV017', 'full_name': 'Châu Văn Tùng', 'class_name': 'CNTT02'},
    {'student_id': 18, 'student_code': 'SV018', 'full_name': 'Dương Thị Uyên', 'class_name': 'CNTT02'},
    {'student_id': 19, 'student_code': 'SV019', 'full_name': 'Lâm Văn Vinh', 'class_name': 'CNTT02'},
    {'student_id': 20, 'student_code': 'SV020', 'full_name': 'Cao Thị Xuân', 'class_name': 'CNTT02'},
    {'student_id': 37, 'student_code': 'SV037', 'full_name': 'Vương Văn Đạt', 'class_name': 'CNTT02'},
    {'student_id': 38, 'student_code': 'SV038', 'full_name': 'Hứa Thị Giang', 'class_name': 'CNTT02'},
    // ATTT01 (9 SV)
    {'student_id': 21, 'student_code': 'SV021', 'full_name': 'Đỗ Hoàng Yên', 'class_name': 'ATTT01'},
    {'student_id': 22, 'student_code': 'SV022', 'full_name': 'Mai Thị Hằng', 'class_name': 'ATTT01'},
    {'student_id': 23, 'student_code': 'SV023', 'full_name': 'Hà Văn Khôi', 'class_name': 'ATTT01'},
    {'student_id': 24, 'student_code': 'SV024', 'full_name': 'Kiều Thị Mai', 'class_name': 'ATTT01'},
    {'student_id': 25, 'student_code': 'SV025', 'full_name': 'Thái Văn Nam', 'class_name': 'ATTT01'},
    {'student_id': 26, 'student_code': 'SV026', 'full_name': 'Lưu Thị Oanh', 'class_name': 'ATTT01'},
    {'student_id': 27, 'student_code': 'SV027', 'full_name': 'Tăng Văn Phát', 'class_name': 'ATTT01'},
    {'student_id': 28, 'student_code': 'SV028', 'full_name': 'Quách Thị Quy', 'class_name': 'ATTT01'},
    {'student_id': 39, 'student_code': 'SV039', 'full_name': 'Kha Văn Hào', 'class_name': 'ATTT01'},
    // KTPM01 (10 SV)
    {'student_id': 29, 'student_code': 'SV029', 'full_name': 'Tiêu Văn Rôn', 'class_name': 'KTPM01'},
    {'student_id': 30, 'student_code': 'SV030', 'full_name': 'Âu Thị Sen', 'class_name': 'KTPM01'},
    {'student_id': 31, 'student_code': 'SV031', 'full_name': 'Chung Văn Tài', 'class_name': 'KTPM01'},
    {'student_id': 32, 'student_code': 'SV032', 'full_name': 'Mạc Thị Vân', 'class_name': 'KTPM01'},
    {'student_id': 33, 'student_code': 'SV033', 'full_name': 'Nhâm Văn Ưng', 'class_name': 'KTPM01'},
    {'student_id': 34, 'student_code': 'SV034', 'full_name': 'Quan Thị Yến', 'class_name': 'KTPM01'},
    {'student_id': 35, 'student_code': 'SV035', 'full_name': 'Từ Văn Bảo', 'class_name': 'KTPM01'},
    {'student_id': 40, 'student_code': 'SV040', 'full_name': 'La Thị Kim', 'class_name': 'KTPM01'},
  ];

  // ============ GRADES - Quản lý điểm ============

  static Future<List<Map<String, dynamic>>> getGrades({
    int? studentId,
    int? semesterId,
  }) async {
    await _delay();
    final list = <Map<String, dynamic>>[];
    final svList = studentId == null
        ? canonicalStudents
        : canonicalStudents.where((s) => s['student_id'] == studentId).toList();
    for (final sv in svList) {
      for (final sub in canonicalSubjects) {
        final cc = 5.0 + _rand.nextDouble() * 4.5;
        final qk = 5.0 + _rand.nextDouble() * 4.5;
        final ck = 5.0 + _rand.nextDouble() * 4.5;
        final total = (cc * 0.1 + qk * 0.3 + ck * 0.6);
        list.add({
          'id': _rand.nextInt(99999),
          'student_id': sv['student_id'],
          'student_code': sv['student_code'],
          'full_name': sv['full_name'],
          'class_name': sv['class_name'],
          'subject_code': sub['subject_code'],
          'subject_name': sub['subject_name'],
          'credits': sub['credits'],
          'exam_form': sub['exam_form'],
          'cc_score': cc.round(),
          'qkt_score': qk.round(),
          'ckt_score': ck.round(),
          'total_score': total,
          'grade': _letterGrade(total),
          'gpa': _gpa(total),
          'semester_id': canonicalSemesters[_rand.nextInt(canonicalSemesters.length)]['semester_id'],
        });
      }
    }
    if (semesterId != null) {
      // Lọc mềm — nếu cùng SV có nhiều kỳ, giữ lại kỳ trùng.
      list.removeWhere((r) => r['semester_id'] != semesterId);
    }
    return list;
  }

  static Future<List<Map<String, dynamic>>> getGradeSummary() async {
    await _delay();
    return [
      {'label': 'Điểm TB', 'value': '8.2', 'trend': '+0.4', 'icon': 'analytics', 'color': 'indigo'},
      {'label': 'Tín chỉ tích lũy', 'value': '78', 'trend': '+12', 'icon': 'school', 'color': 'green'},
      {'label': 'Môn đậu', 'value': '24/25', 'trend': '96%', 'icon': 'check', 'color': 'blue'},
      {'label': 'Môn nợ', 'value': '1', 'trend': '-1', 'icon': 'report', 'color': 'orange'},
    ];
  }

  // ============ ATTENDANCE - Điểm danh ============

  /// Tính attendance summary từ session list (tránh tỉ lệ 85% sai).
  static Future<List<Map<String, dynamic>>> getAttendanceSummary({
    String? className,
    int? studentId,
    List<Map<String, dynamic>>? fromSessions,
  }) async {
    await _delay();
    final sessions = fromSessions ?? await getAttendanceSessions(className: className, studentId: studentId);
    int present = 0, absent = 0, late = 0, excused = 0, totalSessions = 0;
    for (final s in sessions) {
      present += int.tryParse(s['present_count']?.toString() ?? '0') ?? 0;
      absent += int.tryParse(s['absent_count']?.toString() ?? '0') ?? 0;
      late += int.tryParse(s['late_count']?.toString() ?? '0') ?? 0;
      excused += int.tryParse(s['excused_count']?.toString() ?? '0') ?? 0;
      totalSessions += int.tryParse(s['total_count']?.toString() ?? '0') ?? 0;
    }
    final denom = totalSessions == 0 ? 1 : totalSessions;
    String pct(int v) => (v / denom * 100).round().toString();
    return [
      {'label': 'Có mặt', 'value': '${pct(present)}%', 'count': present, 'color': 'green'},
      {'label': 'Muộn', 'value': '${pct(late)}%', 'count': late, 'color': 'orange'},
      {'label': 'Vắng', 'value': '${pct(absent)}%', 'count': absent, 'color': 'red'},
      {'label': 'Có phép', 'value': '${pct(excused)}%', 'count': excused, 'color': 'blue'},
    ];
  }

  static Future<List<Map<String, dynamic>>> getAttendanceSessions({
    int? studentId,
    String? className,
    int? courseId,
  }) async {
    await _delay();
    final list = <Map<String, dynamic>>[];
    // Lọc session theo class nếu có
    final classList = className == null || className.isEmpty
        ? canonicalClasses
        : canonicalClasses.where((c) => c['class_name'] == className).toList();
    if (classList.isEmpty) return list;
    // Lấy SV của lớp đầu tiên phù hợp để tính total_count (nếu có studentId thì chỉ của SV đó)
    String sessionClass = classList.first['class_name'] as String;
    final studentsOfClass = canonicalStudents.where((s) => s['class_name'] == sessionClass).toList();
    final totalCount = studentsOfClass.length;
    for (int i = 0; i < 14; i++) {
      final date = DateTime.now().subtract(Duration(days: i * 2));
      final subj = canonicalSubjects[i % canonicalSubjects.length];
      // Phân bố realistic: 1 absent, 1 late, còn lại present
      String sessionStatus;
      int presentCount, absentCount = 0, lateCount = 0, exc = 0;
      if (i % 5 == 0) {
        sessionStatus = 'absent';
        absentCount = (totalCount * 0.7).round();
        presentCount = totalCount - absentCount;
      } else if (i % 5 == 1) {
        sessionStatus = 'late';
        lateCount = (totalCount * 0.2).round();
        presentCount = totalCount - lateCount;
      } else {
        sessionStatus = 'present';
        presentCount = totalCount - 1;
        lateCount = 1;
      }
      list.add({
        'id': 1000 + i,
        'date': _fmtDate(date),
        'time': '07:30 - 09:30',
        'class_name': sessionClass,
        'subject': subj['subject_name'], // giữ 'subject' cho header
        'subject_code': subj['subject_code'],
        'subject_name': subj['subject_name'],
        'room': 'A${101 + i % 3}',
        'status': sessionStatus,
        'present_count': presentCount,
        'absent_count': absentCount,
        'late_count': lateCount,
        'excused_count': exc,
        'total_count': totalCount,
        'unmarked_count': totalCount - presentCount - absentCount - lateCount - exc,
      });
    }
    return list;
  }

  // ============ SCHEDULES - Lịch học / Lịch thi ============

  static Future<List<Map<String, dynamic>>> getSchedules({
    int? studentId,
    String? type, // 'study' | 'exam'
    String? className,
  }) async {
    await _delay();
    final list = <Map<String, dynamic>>[];
    final rooms = ['A101', 'A102', 'A201', 'B101', 'B202', 'C301'];
    final allClasses = canonicalClasses.map((c) => c['class_name'] as String).toList();
    // Nếu truyền studentId thì tự suy lớp của SV từ canonicalStudents
    String? effectiveClass = className;
    if (studentId != null) {
      final sv = canonicalStudents.firstWhere(
        (s) => s['student_id'] == studentId,
        orElse: () => <String, dynamic>{},
      );
      if (sv.isNotEmpty) effectiveClass = sv['class_name'] as String?;
    }
    final classesToShow = effectiveClass == null || effectiveClass.isEmpty
        ? allClasses
        : [effectiveClass];
    int i = 0;
    for (final cls in classesToShow) {
      for (final subj in canonicalSubjects) {
        final day = DateTime.now().add(Duration(days: i));
        final isExam = type == 'exam';
        list.add({
          'id': i + 1,
          'date': _fmtDate(day),
          'day_of_week': _dayOfWeek(day.weekday),
          'time': isExam ? '09:00 - 11:00' : '07:30 - 09:30',
          'subject_code': subj['subject_code'],
          'subject_name': subj['subject_name'],
          'class_name': cls,
          'room': rooms[i % rooms.length],
          'type': type ?? 'study',
          'exam_form': isExam ? 'Lý thuyết' : null,
          'duration': isExam ? 120 : 90,
        });
        i++;
        if (i >= 24) break;
      }
      if (i >= 24) break;
    }
    return list;
  }

  /// Tổng hợp tuần — tính từ số lịch tải về (không cứng 23 cố định).
  static Future<List<Map<String, dynamic>>> getScheduleWeekSummary({
    List<Map<String, dynamic>>? fromSchedules,
  }) async {
    await _delay();
    final weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final List<int> counts = List.filled(7, 0);
    final source = fromSchedules ?? await getSchedules();
    for (final s in source) {
      final d = (s['day_of_week'] ?? '').toString();
      final idx = weekdays.indexOf(d);
      if (idx >= 0) counts[idx]++;
    }
    const colors = ['indigo', 'blue', 'green', 'orange', 'purple', 'red', 'grey'];
    return [
      for (int i = 0; i < 7; i++) {'day': weekdays[i], 'count': counts[i], 'color': colors[i]},
    ];
  }

  // ============ TUITION - Học phí ============

  static Future<List<Map<String, dynamic>>> getTuitionInvoices({
    int? studentId,
  }) async {
    await _delay();
    final list = <Map<String, dynamic>>[];
    final svList = studentId == null
        ? canonicalStudents
        : canonicalStudents.where((s) => s['student_id'] == studentId).toList();
    if (svList.isEmpty) return list;
    // Mỗi SV có 3 invoice (1/kỳ)
    int invId = 2000;
    for (final sv in svList.take(4)) {
      // lấy 4 SV đầu để demo
      for (final sem in canonicalSemesters) {
        final total = 4500000 + _rand.nextInt(2000000);
        final paid = _rand.nextBool() ? total : (total * (0.3 + _rand.nextDouble() * 0.6)).toInt();
        final status = paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');
        final dueDate = DateTime.now().add(Duration(days: -30 + (invId % 30)));
        list.add({
          'id': invId++,
          'invoice_code': 'INV2024${(1000 + invId).toString()}',
          'student_id': sv['student_id'],
          'student_code': sv['student_code'],
          'student_name': sv['full_name'],
          'class_name': sv['class_name'],
          'semester_id': sem['semester_id'],
          'semester': sem['semester_name'],
          'total_amount': total,
          'paid_amount': paid,
          'remaining_amount': total - paid,
          'due_date': _fmtDate(dueDate),
          'status': status,
          'credits': 14 + _rand.nextInt(6),
          'tuition_per_credit': 285000,
        });
      }
    }
    return list;
  }

  /// Tính lại summary từ chính danh sách invoice truyền vào (không trả số cứng).
  static Future<Map<String, dynamic>> getTuitionSummary({
    int? studentId,
    List<Map<String, dynamic>>? fromInvoices,
  }) async {
    await _delay();
    final invoices = fromInvoices ?? await getTuitionInvoices(studentId: studentId);
    int total = 0, paid = 0, unpaid = 0, overdue = 0;
    for (final inv in invoices) {
      total += int.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0;
      paid += int.tryParse(inv['paid_amount']?.toString() ?? '0') ?? 0;
      if ((inv['status'] ?? '') == 'unpaid') unpaid++;
      // overdue nếu due_date < now và chưa paid hết
      try {
        final due = DateTime.parse((inv['due_date'] ?? '').toString());
        if (due.isBefore(DateTime.now()) && (inv['status'] ?? '') != 'paid') overdue++;
      } catch (_) {}
    }
    final remaining = total - paid;
    final paidPercent = total > 0 ? (paid / total * 100) : 0.0;
    return {
      'total_amount': total,
      'paid_amount': paid,
      'remaining_amount': remaining,
      'paid_percent': double.parse(paidPercent.toStringAsFixed(1)),
      'unpaid_invoices': unpaid,
      'overdue_invoices': overdue,
    };
  }

  static Future<List<Map<String, dynamic>>> getTuitionPayments({
    int? studentId,
    List<Map<String, dynamic>>? fromInvoices,
  }) async {
    await _delay();
    final invoices = fromInvoices ?? await getTuitionInvoices(studentId: studentId);
    final list = <Map<String, dynamic>>[];
    int payId = 3000;
    for (final inv in invoices.take(3)) {
      // mỗi invoice có 1-2 payment
      final total = int.tryParse(inv['paid_amount']?.toString() ?? '0') ?? 0;
      final splits = _rand.nextBool() ? 1 : 2;
      final per = (total / splits).round();
      for (int s = 0; s < splits; s++) {
        final date = DateTime.now().subtract(Duration(days: payId - 3000));
        list.add({
          'id': payId++,
          'payment_code': 'PAY${(20240000 + payId)}',
          'invoice_id': inv['id'],
          'invoice_code': inv['invoice_code'],
          'student_id': inv['student_id'],
          'student_code': inv['student_code'],
          'amount': per,
          'date': _fmtDate(date),
          'method': ['Chuyển khoản', 'Tiền mặt', 'Thẻ tín dụng'][payId % 3],
          'note': splits > 1 ? 'Thanh toán đợt ${s + 1}' : 'Thanh toán đủ',
        });
      }
    }
    return list;
  }

  // ============ GRADE BOOK - Bảng điểm admin ============
  // ============ GRADES DISPLAY (Student xem điểm chỉ đọc) ============

  /// Chương trình khung thực tế: lớp → học kỳ → danh sách môn.
  /// Nguồn duy nhất cho cả curriculum display lẫn grades.
  /// Muốn thêm môn vào kỳ nào → sửa ở đây.
  static const Map<String, Map<int, List<String>>> _curriculumLayout = {
    'CNTT01': {
      1: ['IT001', 'IT003'],
      2: ['IT002', 'IT004'],
      3: ['IT005', 'IT006'],
    },
    'CNTT02': {
      1: ['IT001', 'IT003'],
      2: ['IT002', 'IT004'],
      3: ['IT005', 'IT006'],
    },
    'ATTT01': {
      1: ['IT001', 'IS002'],
      2: ['IS003', 'IS004'],
      3: ['IS005', 'IS006'],
    },
    'KTPM01': {
      1: ['SE001', 'SE002'],
      2: ['SE003', 'SE004'],
      3: ['SE005', 'SE006'],
    },
  };

  /// Lấy danh sách subject_code cho 1 lớp + 1 học kỳ từ chương trình khung.
  static List<String> _getCurriculumSubjectCodes(String className, int semesterId) {
    final classMap = _curriculumLayout[className] ?? _curriculumLayout['CNTT01']!;
    return classMap[semesterId] ?? [];
  }

  /// Lấy danh sách môn học cho 1 học kỳ + lớp (từ chương trình khung thực tế).
  /// Dùng chung cho cả curriculum display lẫn grades.
  static List<Map<String, dynamic>> _getSubjectsForSemester(int semesterId, String? className) {
    final c = (className ?? '').trim().isEmpty ? 'CNTT01' : className!.trim();
    final sem = canonicalSemesters.firstWhere(
      (s) => s['id'] == semesterId,
      orElse: () => const {},
    );
    if (sem.isEmpty) return [];

    final codes = _getCurriculumSubjectCodes(c, semesterId);
    return codes.map((code) {
      return canonicalSubjects.firstWhere(
        (s) => s['subject_code'] == code,
        orElse: () => const {},
      );
    }).where((s) => s.isNotEmpty).toList().asMap().entries.map((e) {
      final i = e.key;
      final s = e.value;
      return {
        'id': 100 + semesterId * 10 + i,
        'code': s['subject_code'],
        'subject_code': s['subject_code'],
        'name': s['subject_name'],
        'subject_name': s['subject_name'],
        'credits': s['credits'],
        'credit': s['credits'],
        'theory_hours': 30,
        'practice_hours': 15,
        'course_type': 'Bắt buộc',
        'exam_form': s['exam_form'] ?? 'Tự luận',
        'status': 'studying',
        'semester_id': semesterId,
        'semester_name': sem['semester_name'],
        'class_name': c,
      };
    }).toList();
  }

  /// Trả về subject options cho dropdown "Môn học" trong grades filter.
  /// Nếu className và semesterId đều null → tất cả môn.
  /// Nếu chỉ có className → môn theo lớp (mọi HK).
  /// Nếu có cả className + semesterId → môn theo lớp + HK cụ thể.
  static Future<List<String>> getGradeBookFilteredSubjects({
    String? className,
    int? semesterId,
  }) async {
    try {
      final allCourses = await ApiService.getCourses(className: className, semesterId: semesterId);
      if (allCourses is List) {
        return allCourses.map((e) {
          final code = e['code']?.toString() ?? e['subject_code']?.toString() ?? '';
          final name = e['subject_name']?.toString() ?? '';
          return '$code - $name';
        }).where((s) => s != ' - ').toSet().toList();
      }
    } catch (_) {}
    return [];
  }

  /// In-memory storage cho điểm đã nhập. Key: "${studentId}_${semesterId}_${subjectCode}".
  static final Map<String, Map<String, dynamic>> _gradeStorage = {};

  /// Tạo key định danh duy nhất cho 1 điểm.
  static String _gradeKey(int studentId, int semesterId, String subjectCode) =>
      '${studentId}_${semesterId}_$subjectCode';

  /// Trả về danh sách điểm.
  /// - Sinh viên: từ danh sách sinh viên (theo lớp)
  /// - Môn học : từ chương trình khung (theo học kỳ + lớp)
  /// - Điểm    : từ storage nếu đã nhập, ngược lại null
  static Future<List<Map<String, dynamic>>> getGradeBook({
    String? className,
    int? semesterId,
    String? subjectCode,
    String? search,
    int? studentId,
    List<Map<String, dynamic>>? fromStudents,
  }) async {
    // 1. Fetch Students
    List<dynamic> allStudentsRaw = [];
    try {
      allStudentsRaw = await ApiService.getStudents();
    } catch (_) {
      allStudentsRaw = canonicalStudents;
    }
    
    var filteredStudents = (fromStudents != null && fromStudents.isNotEmpty) 
        ? fromStudents 
        : allStudentsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

    filteredStudents = filteredStudents
        .where((s) => className == null || className.isEmpty || s['class_name'] == className)
        .toList();
    if (studentId != null) {
      filteredStudents = filteredStudents.where((s) => s['student_id'] == studentId || s['id'] == studentId).toList();
    }

    // 2. Fetch Courses from API
    List<dynamic> allCoursesRaw = [];
    try {
      allCoursesRaw = await ApiService.getCourses(className: className, semesterId: semesterId);
    } catch (_) {}

    List<Map<String, dynamic>> subjects = allCoursesRaw.map((e) {
      return {
        'course_id': e['id'] ?? e['course_id'],
        'subject_code': e['code']?.toString() ?? e['subject_code']?.toString() ?? '',
        'subject_name': e['subject_name']?.toString() ?? e['name']?.toString() ?? '',
        'class_name': e['class_name']?.toString() ?? '',
        'credits': e['credits'] ?? 3,
        'semester_id': e['semester_id'],
        'semester_name': e['semester_name'] ?? 'Học kỳ ${e['semester_id']}',
      };
    }).toList();

    if (subjectCode != null && subjectCode.isNotEmpty) {
      subjects = subjects.where((s) => s['subject_code'] == subjectCode).toList();
    }

    // 3. Fetch Grades from API
    List<dynamic> allGradesRaw = [];
    try {
      allGradesRaw = await ApiService.getGrades(className: className, semesterId: semesterId);
    } catch (_) {}
    
    final gradesMap = <String, Map<String, dynamic>>{};
    final list = <Map<String, dynamic>>[];
    for (var g in allGradesRaw) {
      final sId = g['student_id'];
      final semId = g['resolved_semester_id'] ?? g['semester_id'];
      final courseId = g['course_id'];
      final subCode = g['subject_code']?.toString() ?? g['code']?.toString() ?? '';
      if (subjectCode != null && subjectCode.isNotEmpty && subCode != subjectCode) continue;

      final gradeRow = Map<String, dynamic>.from(g);
      gradeRow.addAll({
        'semester_id': semId,
        'subject_code': subCode,
        'subject_name': g['subject_name'] ?? '',
        'cc_score': g['cc_score'] ?? g['attendance_score'],
        'qkt_score': g['qkt_score'] ?? g['midterm_score'],
        'ckt_score': g['ckt_score'] ?? g['final_score'],
        'total_score': g['total_score'] ?? g['average_score'],
        'note': g['note'] ?? '',
        '_isPersisted': true,
      });
      list.add(gradeRow);

      if (sId != null && courseId != null) {
        gradesMap['course_${sId}_$courseId'] = gradeRow;
      }
      if (sId != null && semId != null && subCode.isNotEmpty) {
        gradesMap['${sId}_${semId}_$subCode'] = gradeRow;
      }
    }

    // 4. Bổ sung các tổ hợp sinh viên - môn học chưa có điểm.
    int rowId = 1;
    for (final s in filteredStudents) {
      for (final sub in subjects) {
        if (s['class_name'] != sub['class_name']) continue;

        final sId = s['student_id'] ?? s['id'];
        final semId = sub['semester_id'] ?? 0;
        final courseId = sub['course_id'];
        final subCode = sub['subject_code'] ?? '';
        final key = '${sId}_${semId}_$subCode';
        
        Map<String, dynamic>? saved = courseId == null ? null : gradesMap['course_${sId}_$courseId'];
        saved ??= gradesMap[key];
        if (saved != null) continue;
        final localSaved = _gradeStorage[key];

        list.add({
          'id': 'new_${rowId++}',
          'student_id': sId,
          'student_code': s['student_code'] ?? s['code'],
          'full_name': s['full_name'] ?? s['name'],
          'class_name': s['class_name'],
          'subject_code': subCode,
          'subject_name': sub['subject_name'],
          'credits': sub['credits'],
          'semester_id': semId,
          'semester_name': sub['semester_name'],
          'course_id': courseId,
          'cc_score': localSaved?['cc_score'],
          'qkt_score': localSaved?['qkt_score'],
          'ckt_score': localSaved?['ckt_score'],
          'total_score': localSaved?['total_score'],
          'grade': localSaved?['grade'],
          'status': localSaved?['status'],
          'note': localSaved?['note'] ?? '',
          '_key': key,
        });
      }
    }

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return list.where((r) =>
        (r['student_code']?.toString() ?? '').toLowerCase().contains(q) ||
        (r['full_name']?.toString() ?? '').toLowerCase().contains(q) ||
        (r['subject_code']?.toString() ?? '').toLowerCase().contains(q) ||
        (r['subject_name']?.toString() ?? '').toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  /// Thêm / cập nhật một điểm vào storage.
  static Future<Map<String, dynamic>> saveGrade({
    required int studentId,
    required int courseId,
    required int semesterId,
    required String subjectCode,
    required double ccScore,
    required double qktScore,
    required double cktScore,
    String? note,
  }) async {
    await _delay();
    final key = _gradeKey(studentId, semesterId, subjectCode);
    final total = ccScore * 0.1 + qktScore * 0.3 + cktScore * 0.6;
    final grade = _letterGrade(total);
    final status = total >= kPassThreshold ? 'pass' : 'fail';

    _gradeStorage[key] = {
      'cc_score': ccScore,
      'qkt_score': qktScore,
      'ckt_score': cktScore,
      'total_score': total,
      'grade': grade,
      'status': status,
      'note': note ?? '',
    };

    await ApiService.addGrade({
      'student_id': studentId,
      'course_id': courseId,
      'semester_id': semesterId,
      'cc_score': ccScore,
      'qkt_score': qktScore,
      'ckt_score': cktScore,
      'total_score': total,
      'grade': grade,
      'status': status,
      'note': note ?? '',
    });

    return _gradeStorage[key]!;
  }

  /// Xóa một điểm khỏi storage.
  static Future<void> deleteGrade({
    required int studentId,
    required int semesterId,
    required String subjectCode,
  }) async {
    await _delay();
    final key = _gradeKey(studentId, semesterId, subjectCode);
    _gradeStorage.remove(key);
  }

  /// Tính stats TỪ STORAGE (chỉ đếm dòng đã có điểm thật).
  static Future<Map<String, dynamic>> getGradeBookStats({
    String? className,
    int? semesterId,
    List<Map<String, dynamic>>? fromRows,
  }) async {
    await _delay();
    final rows = fromRows ?? await getGradeBook(className: className, semesterId: semesterId);

    // Chỉ đếm những dòng đã có điểm thật
    final gradedRows = rows.where((r) => r['total_score'] != null).toList();
    final total = gradedRows.length;

    if (total == 0) {
      return {
        'total_records': 0,
        'total_slots': rows.length,
        'average_score': 0.0,
        'pass_rate': 0.0,
        'pass_count': 0,
        'fail_count': 0,
        'graded_count': 0,
      };
    }
    int passCount = 0;
    double sum = 0;
    for (final r in gradedRows) {
      final t = double.tryParse(r['total_score']?.toString() ?? '0') ?? 0.0;
      sum += t;
      if ((r['status'] ?? '') == 'pass') passCount++;
    }
    return {
      'total_records': total,
      'total_slots': rows.length,
      'average_score': double.parse((sum / total).toStringAsFixed(2)),
      'pass_rate': double.parse((passCount / total * 100).toStringAsFixed(1)),
      'pass_count': passCount,
      'fail_count': total - passCount,
      'graded_count': total,
    };
  }

  /// Dropdown lớp cho Grade Book — item đầu là "Tất cả" (chuỗi rỗng).
  static Future<List<String>> getGradeBookClasses() async {
    await _delay();
    return ['', ...canonicalClasses.map((c) => c['class_name'] as String)];
  }

  // ============ SCHEDULES - dropdown data ============

  /// Dropdown lớp lịch học — item đầu là "Tất cả" (chuỗi rỗng).
  static Future<List<String>> getScheduleClasses() async {
    await _delay();
    return ['', ...canonicalClasses.map((c) => c['class_name'] as String)];
  }

  /// Trả về chuỗi "code - name" (format giữ nguyên để dropdown hiển thị).
  static Future<List<String>> getScheduleSubjects() async {
    await _delay();
    return canonicalSubjects
        .map((s) => '${s['subject_code']} - ${s['subject_name']}')
        .toList();
  }

  static Future<List<String>> getScheduleRooms() async {
    await _delay();
    return ['A101', 'A102', 'A201', 'B101', 'B202', 'C301', 'Hội trường', 'Phòng thực hành 1'];
  }

  static Future<List<String>> getScheduleExamForms() async {
    await _delay();
    return ['Tự luận', 'Trắc nghiệm', 'Vấn đáp', 'Thực hành', 'Đồ án'];
  }

  /// Thêm 1 lịch (study hoặc exam) vào danh sách đã load.
  /// Trả về row đã insert (chưa có id thật - mock).
  static Future<Map<String, dynamic>> createSchedule(Map<String, dynamic> payload) async {
    await _delay();
    final isExam = payload['type'] == 'exam';
    return {
      'id': DateTime.now().millisecondsSinceEpoch,
      'type': isExam ? 'exam' : 'study',
      'subject_code': payload['subject_code'] ?? canonicalSubjects[0]['subject_code'],
      'subject_name': payload['subject_name'] ?? canonicalSubjects[0]['subject_name'],
      'class_name': payload['class_name'] ?? (canonicalClasses[0]['class_name'] as String),
      'date': payload['date'],
      'day_of_week': payload['day_of_week'] ?? _dayFromDate(payload['date'] as String),
      'time': payload['time'] ?? '08:00 - 10:00',
      'room': payload['room'] ?? 'A101',
      'exam_form': isExam ? (payload['exam_form'] ?? 'Tự luận') : null,
      'duration': isExam ? (payload['duration'] ?? 90) : null,
      'note': payload['note'] ?? '',
    };
  }

  static String _dayFromDate(String date) {
    try {
      final d = DateTime.parse(date);
      const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      return days[d.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  /// Dropdown học kỳ Grade Book — dùng canonical, format thống nhất.
  static Future<List<String>> getGradeBookSemesters() async {
    await _delay();
    // Thêm '' cho option "Tất cả" để đồng nhất với các dropdown khác
    final names = canonicalSemesters.map((s) => s['semester_name'] as String).toList();
    return ['', ...names];
  }

  static Future<List<String>> getGradeBookSubjects() async {
    await _delay();
    // Loại bỏ trùng lặp bằng Set để tránh lỗi DropdownButton
    return canonicalSubjects
        .map((s) => '${s['subject_code']} - ${s['subject_name']}')
        .toSet() // deduplicate
        .toList();
  }

  /// Dropdown lớp cho Tuition — dùng canonical.
  static Future<List<String>> getTuitionClasses() async {
    await _delay();
    return canonicalClasses.map((c) => c['class_name'] as String).toList();
  }

  /// Dropdown học kỳ cho Tuition.
  static Future<List<String>> getTuitionSemesters() async {
    await _delay();
    return canonicalSemesters.map((s) => s['semester_name'] as String).toList();
  }

  // ============ HELPERS ============

  static Future<void> _delay() =>
      Future.delayed(Duration(milliseconds: 250 + _rand.nextInt(200)));

  static String _fmtDate(DateTime d) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static String _dayOfWeek(int day) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return labels[day - 1];
  }

  /// Xếp loại điểm (canonical). Dùng kPassThreshold = 4.0 làm chuẩn đậu.
  static String _letterGrade(double score) {
    if (score >= 8.5) return 'A';
    if (score >= 7.0) return 'B';
    if (score >= 5.5) return 'C';
    if (score >= kPassThreshold) return 'D'; // 4.0 - 5.49 → D (đạt)
    return 'F'; // < 4.0 → F (trượt)
  }

  static double _gpa(double score) {
    if (score >= 8.5) return 4.0;
    if (score >= 7.0) return 3.5;
    if (score >= 5.5) return 3.0;
    if (score >= kPassThreshold) return 2.0;
    return 1.0;
  }

  // ============ CURRICULUM (Chương trình khung) ============

  /// Trả về danh sách học kỳ theo lớp (mock khi backend rỗng).
  /// Schema khớp backend /semesters: { id, name, semester_name, start_date, end_date, status, class_name }.
  static Future<List<Map<String, dynamic>>> getCurriculumSemesters({String? className}) async {
    try {
      final sems = await ApiService.getSemesters(className: className);
      if (sems is List) {
        return sems.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Trả về danh sách môn học cho 1 học kỳ (mock khi backend rỗng).
  /// Schema khớp backend /courses: { id, code, name, credits, semester_id, semester_name, class_name }.
  static Future<List<Map<String, dynamic>>> getCurriculumCourses({
    required int semesterId,
    String? className,
  }) async {
    try {
      final courses = await ApiService.getCourses(semesterId: semesterId, className: className);
      if (courses is List) {
        return courses.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ============ GRADES DISPLAY (Student xem điểm chỉ đọc) ============

  /// Trả về danh sách điểm của một sinh viên cụ thể.
  /// Môn học: từ chương trình khung (theo học kỳ).
  /// Điểm: từ storage nếu đã nhập, ngược lại null.
  static Future<List<Map<String, dynamic>>> getStudentGrades(int studentId) async {
    await _delay();
    final rows = <Map<String, dynamic>>[];

    for (final sem in canonicalSemesters) {
      final semId = sem['semester_id'] as int;
      final subjects = _getSubjectsForSemester(semId, null);

      for (final subj in subjects) {
        final key = _gradeKey(studentId, semId, subj['subject_code'] as String);
        final saved = _gradeStorage[key];

        rows.add({
          'student_id': studentId,
          'subject_code': subj['subject_code'],
          'subject_name': subj['subject_name'],
          'credits': subj['credits'],
          'semester_id': semId,
          'semester_name': sem['semester_name'],
          'cc_score': saved?['cc_score'],
          'qkt_score': saved?['qkt_score'],
          'ckt_score': saved?['ckt_score'],
          'total_score': saved?['total_score'],
          'grade': saved?['grade'],
          'status': saved?['status'],
        });
      }
    }
    return rows;
  }

  /// Trả về thống kê điểm của một sinh viên (chỉ từ điểm đã nhập).
  static Future<Map<String, dynamic>> getStudentGradeStats(int studentId) async {
    final grades = await getStudentGrades(studentId);
    final graded = grades.where((g) => g['total_score'] != null).toList();
    if (graded.isEmpty) {
      return {'total': 0, 'graded': 0, 'average': 0.0, 'passed': 0, 'failed': 0};
    }
    final total = graded.length;
    final passed = graded.where((g) => g['status'] == 'pass').length;
    final avg = graded.map((g) => (g['total_score'] as double)).reduce((a, b) => a + b) / total;
    return {
      'total': grades.length,
      'graded': total,
      'average': double.parse(avg.toStringAsFixed(2)),
      'passed': passed,
      'failed': total - passed,
    };
  }
}
