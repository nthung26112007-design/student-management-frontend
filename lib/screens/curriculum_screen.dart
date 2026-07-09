import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CurriculumScreen extends StatefulWidget {
  final String role;
  final bool embedded;
  const CurriculumScreen({super.key, required this.role, this.embedded = false});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  List<Map<String, dynamic>> _semesters = [];
  final Map<int, List<Map<String, dynamic>>> _coursesBySemester = {};
  final Set<int> _expandedSemesterIds = {};
  bool _loading = true;
  String? _loadError;

  final _semesterNameController = TextEditingController();
  final _semesterStartController = TextEditingController();
  final _semesterEndController = TextEditingController();
  String _selectedSemesterStatus = 'active';
  int? _editingSemesterId;

  final _subjectCodeController = TextEditingController();
  final _subjectNameController = TextEditingController();
  final _creditsController = TextEditingController();
  final _classNameController = TextEditingController();
  int? _selectedSemesterIdForCourse;
  String _selectedCourseStatus = 'studying';
  int? _editingCourseId;

  bool get _isStudent => widget.role == 'student';
  bool get _canEdit => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _semesterNameController.dispose();
    _semesterStartController.dispose();
    _semesterEndController.dispose();
    _subjectCodeController.dispose();
    _subjectNameController.dispose();
    _creditsController.dispose();
    _classNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final semesters = await ApiService.getSemesters();
      final semesterList = semesters.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      _coursesBySemester.clear();
      for (final sem in semesterList) {
        final semesterId = sem['id'] as int;
        final courses = await ApiService.getCourses(semesterId: semesterId);
        _coursesBySemester[semesterId] = courses.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      }
      if (!mounted) return;
      setState(() {
        _semesters = semesterList;
        _selectedSemesterIdForCourse ??= _semesters.isNotEmpty ? _semesters.first['id'] as int : null;
        _expandedSemesterIds.clear();
        if (_semesters.isNotEmpty) _expandedSemesterIds.add(_semesters.first['id'] as int);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveSemester() async {
    final name = _semesterNameController.text.trim();
    final start = _semesterStartController.text.trim();
    final end = _semesterEndController.text.trim();
    if (name.isEmpty || start.isEmpty || end.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ tên, ngày bắt đầu và ngày kết thúc')));
      return;
    }
    final payload = {'name': name, 'start_date': start, 'end_date': end, 'status': _selectedSemesterStatus};
    try {
      if (_editingSemesterId == null) {
        await ApiService.addSemester(payload);
      } else {
        await ApiService.updateSemester(_editingSemesterId!, payload);
      }
      _clearSemesterForm();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingSemesterId == null ? 'Đã thêm học kỳ' : 'Đã lưu học kỳ')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được học kỳ: $e')));
    }
  }

  Future<void> _saveCourse() async {
    final semesterId = _selectedSemesterIdForCourse;
    final subjectName = _subjectNameController.text.trim();
    final subjectCode = _subjectCodeController.text.trim();
    final className = _classNameController.text.trim();
    final credits = int.tryParse(_creditsController.text.trim()) ?? 0;
    if (semesterId == null || subjectName.isEmpty || subjectCode.isEmpty || className.isEmpty || credits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ mã môn, tên môn, lớp, học kỳ và số tín chỉ hợp lệ')));
      return;
    }
    final payload = {
      'semester_id': semesterId,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'class_name': className,
      'credits': credits,
      'status': _selectedCourseStatus,
    };
    try {
      if (_editingCourseId == null) {
        await ApiService.addCourse(payload);
      } else {
        await ApiService.updateCourse(_editingCourseId!, payload);
      }
      _clearCourseForm();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingCourseId == null ? 'Đã thêm môn học' : 'Đã lưu môn học')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được môn học: $e')));
    }
  }

  void _clearSemesterForm() {
    _editingSemesterId = null;
    _semesterNameController.clear();
    _semesterStartController.clear();
    _semesterEndController.clear();
    _selectedSemesterStatus = 'active';
  }

  void _clearCourseForm() {
    _editingCourseId = null;
    _subjectCodeController.clear();
    _subjectNameController.clear();
    _creditsController.clear();
    _classNameController.clear();
    _selectedCourseStatus = 'studying';
  }

  Future<void> _confirmDeleteSemester(Map<String, dynamic> semester) async {
    final ok = await _confirmDialog('Xóa học kỳ', 'Bạn có chắc muốn xóa học kỳ "${semester['name'] ?? semester['semester_name'] ?? ''}"?');
    if (!ok) return;
    try {
      await ApiService.deleteSemester(semester['id'] as int);
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa học kỳ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xóa được học kỳ: $e')));
    }
  }

  Future<void> _confirmDeleteCourse(Map<String, dynamic> course) async {
    final ok = await _confirmDialog('Xóa môn học', 'Bạn có chắc muốn xóa môn "${course['subject_name'] ?? course['name'] ?? ''}"?');
    if (!ok) return;
    try {
      await ApiService.deleteCourse(course['id'] as int);
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa môn học')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xóa được môn học: $e')));
    }
  }

  Future<bool> _confirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    );
    return result ?? false;
  }

  void _editSemester(Map<String, dynamic> semester) {
    _editingSemesterId = semester['id'] as int;
    _semesterNameController.text = semester['name']?.toString() ?? semester['semester_name']?.toString() ?? '';
    _semesterStartController.text = _formatDate(semester['start_date']);
    _semesterEndController.text = _formatDate(semester['end_date']);
    _selectedSemesterStatus = semester['status']?.toString() == 'finished' ? 'finished' : 'active';
    setState(() {});
  }

  void _editCourse(Map<String, dynamic> course, int semesterId) {
    _editingCourseId = course['id'] as int;
    _selectedSemesterIdForCourse = semesterId;
    _subjectCodeController.text = course['subject_code']?.toString() ?? course['code']?.toString() ?? '';
    _subjectNameController.text = course['subject_name']?.toString() ?? '';
    _classNameController.text = course['class_name']?.toString() ?? '';
    _creditsController.text = (course['credits'] ?? course['credit'] ?? '').toString();
    final raw = (course['status'] ?? '').toString();
    if (raw == 'pass' || raw == 'passed' || raw == 'đạt') {
      _selectedCourseStatus = 'pass';
    } else if (raw == 'fail' || raw == 'failed' || raw == 'chưa đạt') {
      _selectedCourseStatus = 'fail';
    } else {
      _selectedCourseStatus = 'studying';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Không tải được dữ liệu chương trình khung'),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ],
        ),
      );
    } else if (_semesters.isEmpty) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Chưa có kỳ học nào', style: TextStyle(color: Colors.grey.shade700)),
            if (_canEdit) ...[
              const SizedBox(height: 6),
              Text('Hãy dùng form phía trên để thêm học kỳ mới.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ],
        ),
      );
    } else {
      content = ListView(padding: const EdgeInsets.all(16), children: [
        _buildHeaderCard(),
        if (_canEdit) ...[
          const SizedBox(height: 16),
          _buildAddSemesterCard(),
          const SizedBox(height: 16),
          _buildAddCourseCard(),
        ],
        const SizedBox(height: 16),
        ..._semesters.map(_buildSemesterCard),
      ]);
    }

    if (widget.embedded) {
      return Container(color: const Color(0xFFF5F7FB), child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Chương trình khung'), backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
      body: content,
    );
  }

  Widget _buildHeaderCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.blue.withOpacity(0.08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lộ trình học tập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_isStudent ? 'Xem từng học kỳ và danh sách môn học bên trong.' : 'Quản lý chương trình khung theo từng học kỳ và lớp học.', style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
        ]),
      );

  Widget _buildAddSemesterCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.orange.withOpacity(0.12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_editingSemesterId == null ? 'Thêm học kỳ mới' : 'Sửa học kỳ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.orange.shade800)),
          const SizedBox(height: 12),
          TextField(controller: _semesterNameController, decoration: const InputDecoration(labelText: 'Tên học kỳ', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _semesterStartController, decoration: const InputDecoration(labelText: 'Ngày bắt đầu (YYYY-MM-DD)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _semesterEndController, decoration: const InputDecoration(labelText: 'Ngày kết thúc (YYYY-MM-DD)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSemesterStatus,
            decoration: const InputDecoration(labelText: 'Trạng thái', border: OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 'active', child: Text('Đang học')), DropdownMenuItem(value: 'finished', child: Text('Kết thúc'))],
            onChanged: (v) => setState(() => _selectedSemesterStatus = v ?? 'active'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _saveSemester, icon: Icon(_editingSemesterId == null ? Icons.add_circle_outline : Icons.save), label: Text(_editingSemesterId == null ? 'Thêm học kỳ' : 'Lưu học kỳ'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _clearSemesterForm, child: const Text('Hủy')),
          ]),
        ]),
      );

  Widget _buildAddCourseCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.green.withOpacity(0.12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_editingCourseId == null ? 'Thêm môn học mới' : 'Sửa môn học', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green.shade800)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _selectedSemesterIdForCourse,
            decoration: const InputDecoration(labelText: 'Học kỳ', border: OutlineInputBorder()),
            items: _semesters.map((s) => DropdownMenuItem<int?>(value: s['id'] as int, child: Text('${s['name'] ?? s['semester_name'] ?? ''}'))).toList(),
            onChanged: (v) => setState(() => _selectedSemesterIdForCourse = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _subjectCodeController, decoration: const InputDecoration(labelText: 'Mã môn', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _subjectNameController, decoration: const InputDecoration(labelText: 'Tên môn học', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _classNameController, decoration: const InputDecoration(labelText: 'Lớp', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _creditsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tín chỉ', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCourseStatus,
            decoration: const InputDecoration(labelText: 'Trạng thái', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'studying', child: Text('Đang học')),
              DropdownMenuItem(value: 'pass', child: Text('Đạt')),
              DropdownMenuItem(value: 'fail', child: Text('Chưa đạt')),
            ],
            onChanged: (v) => setState(() => _selectedCourseStatus = v ?? 'studying'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _saveCourse, icon: Icon(_editingCourseId == null ? Icons.add : Icons.save), label: Text(_editingCourseId == null ? 'Thêm môn học' : 'Lưu môn học'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _clearCourseForm, child: const Text('Hủy')),
          ]),
        ]),
      );

  Widget _buildSemesterCard(Map<String, dynamic> semester) {
    final semesterId = semester['id'] as int;
    final expanded = _expandedSemesterIds.contains(semesterId);
    final courses = _coursesBySemester[semesterId] ?? const [];
    final isActive = semester['status'] == 'active';
    final semesterName = (semester['name'] ?? semester['semester_name'] ?? 'Học kỳ').toString();
    final start = _formatDate(semester['start_date']);
    final end = _formatDate(semester['end_date']);
    final totalCredits = _sumCredits(courses);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => expanded ? _expandedSemesterIds.remove(semesterId) : _expandedSemesterIds.add(semesterId)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: isActive ? Colors.green.withOpacity(0.12) : Colors.blue.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.school, color: isActive ? Colors.green : Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(semesterName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${semesterName.toUpperCase()}${start.isNotEmpty || end.isNotEmpty ? '  •  $start → $end' : ''}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('--  (TC: $totalCredits)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isActive ? Colors.green.withOpacity(0.10) : Colors.grey.withOpacity(0.10), borderRadius: BorderRadius.circular(999)), child: Text(isActive ? 'Đang học' : 'Kết thúc', style: TextStyle(color: isActive ? Colors.green.shade800 : Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
              if (_canEdit) ...[
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editSemester(semester)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteSemester(semester)),
              ],
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade600),
            ]),
          ),
        ),
        if (expanded) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blueGrey.withOpacity(0.05),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Môn Học Bắt Buộc', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
              Text('(TC: $totalCredits)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
            ]),
          ),
          _buildSubjectTable(courses, semesterId),
        ],
      ]),
    );
  }

  Widget _buildSubjectTable(List<Map<String, dynamic>> courses, int semesterId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(Colors.blue.shade700),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        columns: const [
          DataColumn(label: Text('Mã Môn')),
          DataColumn(label: Text('Tên Môn Học')),
          DataColumn(label: Text('TC')),
          DataColumn(label: Text('Trạng Thái')),
          DataColumn(label: Text('')),
        ],
        rows: courses.map((course) {
          final credits = course['credits'] ?? course['credit'] ?? 0;
          final status = _courseStatus(course);
          final statusColor = status == 'Đạt' ? Colors.green : status == 'Chưa đạt' ? Colors.red : Colors.orange;
          return DataRow(cells: [
            DataCell(Text('${course['subject_code'] ?? course['code'] ?? ''}')),
            DataCell(SizedBox(width: 220, child: Text('${course['subject_name'] ?? ''}'))),
            DataCell(Text('$credits')),
            DataCell(Text(status, style: TextStyle(fontWeight: FontWeight.w700, color: statusColor))),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              if (_canEdit) ...[
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editCourse(course, semesterId)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirmDeleteCourse(course)),
              ]
            ])),
          ]);
        }).toList(),
      ),
    );
  }

  String _courseStatus(Map<String, dynamic> course) {
    final raw = (course['status'] ?? course['course_status'] ?? '').toString().toLowerCase().trim();
    if (raw == 'pass' || raw == 'passed' || raw == 'done' || raw == 'completed' || raw == 'đạt') return 'Đạt';
    if (raw == 'fail' || raw == 'failed' || raw == 'chưa đạt') return 'Chưa đạt';
    return 'Đang học';
  }

  int _sumCredits(List<Map<String, dynamic>> courses) {
    int total = 0;
    for (final c in courses) {
      total += int.tryParse((c['credits'] ?? c['credit'] ?? 0).toString()) ?? 0;
    }
    return total;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    return str.length >= 10 ? str.substring(0, 10) : str;
  }
}
