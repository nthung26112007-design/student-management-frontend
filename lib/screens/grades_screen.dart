import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class GradesScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String role;

  const GradesScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.role,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool _isLoading = true;
  String? _studentClassName;
  List<Map<String, dynamic>> _semesters = [];
  final Map<int, List<Map<String, dynamic>>> _coursesBySemester = {};
  final Map<int, List<Map<String, dynamic>>> _gradesBySemester = {};
  final Set<int> _expandedSemesters = {};

  bool get _canEdit => widget.role == 'admin' || widget.role == 'teacher';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadStudentClass();
      final semesters = await ApiService.getSemesters();
      final semesterList = (semesters is List) ? semesters.map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

      for (final sem in semesterList) {
        final semesterId = sem['id'] as int;
        final courses = await ApiService.getCourses(semesterId: semesterId);
        final grades = await ApiService.getGrades(widget.studentId, semesterId: semesterId);

        final className = _studentClassName?.trim().toUpperCase();
        final filteredCourses = (courses is List ? courses : [])
            .map((e) => Map<String, dynamic>.from(e))
            .where((c) {
              if (className == null || className.isEmpty) return true;
              return (c['class_name'] ?? '').toString().trim().toUpperCase() == className;
            })
            .toList();

        final filteredGrades = (grades is List ? grades : [])
            .map((e) => Map<String, dynamic>.from(e))
            .where((g) {
              if (className == null || className.isEmpty) return true;
              final gradeClass = (g['class_name'] ?? g['student_class_name'] ?? '').toString().trim().toUpperCase();
              return gradeClass == className;
            })
            .toList();

        _coursesBySemester[semesterId] = filteredCourses;
        _gradesBySemester[semesterId] = filteredGrades;
      }

      if (!mounted) return;
      setState(() {
        _semesters = semesterList;
        if (_semesters.isNotEmpty) _expandedSemesters.add(_semesters.first['id'] as int);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentClass() async {
    try {
      final students = await ApiService.getStudents();
      String? className;

      if (students is Map) {
        className = students['class_name']?.toString();
      } else if (students is List) {
        final matched = students.where((s) => s['id'] == widget.studentId).toList();
        if (matched.isNotEmpty) className = matched.first['class_name']?.toString();
      }

      if (className == null || className.trim().isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        className = prefs.getString('class_name');
      }

      _studentClassName = className;
    } catch (_) {}
  }

  Map<String, dynamic>? _getGradeForCourse(int semesterId, int courseId) {
    final grades = _gradesBySemester[semesterId] ?? const [];
    try {
      return grades.firstWhere((g) => g['course_id'] == courseId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Kỳ thi / Kết quả học tập'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _semesters.isEmpty
              ? const Center(child: Text('Chưa có học kỳ nào', style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _semesters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final semester = _semesters[index];
                    final semesterId = semester['id'] as int;
                    final courses = _coursesBySemester[semesterId] ?? const [];
                    final expanded = _expandedSemesters.contains(semesterId);
                    final semesterName = '${semester['name'] ?? semester['semester_name'] ?? 'Học kỳ'}';
                    final yearLabel = '${semester['start_date']?.toString().substring(0, 4) ?? ''}-${semester['end_date']?.toString().substring(0, 4) ?? ''}';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              semesterName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            subtitle: Text(yearLabel.isNotEmpty ? yearLabel : 'Danh sách môn học của học kỳ này'),
                            trailing: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                            onTap: () {
                              setState(() {
                                if (expanded) {
                                  _expandedSemesters.remove(semesterId);
                                } else {
                                  _expandedSemesters.add(semesterId);
                                }
                              });
                            },
                          ),
                          if (expanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(flex: 2, child: Text('Mã môn', style: TextStyle(fontWeight: FontWeight.w700))),
                                        Expanded(flex: 5, child: Text('Môn học', style: TextStyle(fontWeight: FontWeight.w700))),
                                        Expanded(flex: 1, child: Text('TC', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                                        Expanded(flex: 2, child: Text('Điểm TB', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (courses.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('Chưa có môn học trong học kỳ này', style: TextStyle(color: Colors.grey)),
                                    )
                                  else
                                    ...courses.map((course) {
                                      final grade = _getGradeForCourse(semesterId, course['id'] as int);
                                      final avg = grade?['average_score'];
                                      final avgText = avg == null ? '--' : (avg as num).toStringAsFixed(2).replaceAll('.', ',');
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          title: Row(
                                            children: [
                                              Expanded(flex: 2, child: Text('${course['subject_code'] ?? course['code'] ?? '--'}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                              Expanded(flex: 5, child: Text('${course['subject_name'] ?? ''}')),
                                              Expanded(flex: 1, child: Text('${course['credits'] ?? course['credit'] ?? 0}', textAlign: TextAlign.center)),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  avgText,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: _getGradeColor(avg),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Color _getGradeColor(dynamic score) {
    if (score == null) return Colors.grey;
    final s = (score as num).toDouble();
    if (s >= 8.0) return Colors.green;
    if (s >= 6.5) return Colors.blue;
    if (s >= 5.0) return Colors.orange;
    return Colors.red;
  }
}
