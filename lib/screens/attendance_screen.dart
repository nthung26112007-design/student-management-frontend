import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _StudentAttendanceDraft {
  final Map<String, dynamic> student;
  String status;
  final TextEditingController reasonController;

  _StudentAttendanceDraft({required this.student, this.status = 'present', String reason = ''})
      : reasonController = TextEditingController(text: reason);

  void dispose() => reasonController.dispose();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _classController = TextEditingController();
  final _sessionTitleController = TextEditingController();
  final _sessionNoteController = TextEditingController();
  final _courseIdController = TextEditingController();

  bool _isLoading = false;
  List _sessions = [];
  List _summary = [];
  List<Map<String, dynamic>> _students = [];
  final List<_StudentAttendanceDraft> _drafts = [];
  DateTime _selectedDate = DateTime.now();
  String _mode = 'class';
  List<String> _availableClasses = [];
  String? _selectedClass;

  int get _presentCount => _drafts.where((d) => d.status == 'present').length;
  int get _excusedCount => _drafts.where((d) => d.status == 'excused').length;
  int get _absentCount => _drafts.where((d) => d.status == 'absent').length;

  String get _dateLabel {
    final d = _selectedDate.day.toString().padLeft(2, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final y = _selectedDate.year.toString();
    return '$d/$m/$y';
  }

  String get _defaultSessionTitle {
    final className = _selectedClass ?? _classController.text.trim();
    return 'Điểm danh $_dateLabel${className.isNotEmpty ? ' - $className' : ''}';
  }

  @override
  void initState() {
    super.initState();
    _sessionTitleController.text = _defaultSessionTitle;
    _loadAvailableClasses();
  }

  @override
  void dispose() {
    _classController.dispose();
    _sessionTitleController.dispose();
    _sessionNoteController.dispose();
    _courseIdController.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAvailableClasses() async {
    try {
      final data = await ApiService.getStudents();
      List<String> classes = <String>[];
      if (data is List) {
        classes = data
            .map((e) => (e['class_name'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        classes.sort();
      }
      if (!mounted) return;
      setState(() {
        _availableClasses = classes;
        if (_availableClasses.isNotEmpty && _selectedClass == null) {
          _selectedClass = _availableClasses.first;
          _classController.text = _selectedClass!;
          _sessionTitleController.text = _defaultSessionTitle;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await ApiService.getAttendanceSessions(
        className: (_selectedClass ?? _classController.text).trim(),
        courseId: int.tryParse(_courseIdController.text.trim()),
      );
      final summary = await ApiService.getAttendanceSummary(
        className: (_selectedClass ?? _classController.text).trim(),
        courseId: int.tryParse(_courseIdController.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _summary = summary;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentsForClass() async {
    final data = await ApiService.getStudents();
    final students = data is List
        ? data
            .map((e) => Map<String, dynamic>.from(e))
            .where((s) {
              final className = (s['class_name'] ?? '').toString().trim();
              return _selectedClass == null || _selectedClass!.isEmpty || className == _selectedClass;
            })
            .toList()
        : data is Map
            ? [Map<String, dynamic>.from(data)]
            : <Map<String, dynamic>>[];

    final classes = students
        .map((s) => (s['class_name'] ?? '').toString().trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    for (final d in _drafts) {
      d.dispose();
    }
    _drafts
      ..clear()
      ..addAll(students.map((s) => _StudentAttendanceDraft(student: s)));

    if (!mounted) return;
    setState(() {
      _students = students;
      _availableClasses = classes;
      if (_selectedClass != null && _selectedClass!.isEmpty) {
        _selectedClass = null;
      }
      _classController.text = _selectedClass ?? _classController.text;
      _sessionTitleController.text = _defaultSessionTitle;
    });
  }

  Future<void> _createSessionAndMark() async {
    final className = (_selectedClass ?? _classController.text).trim();
    if (className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn lớp')));
      return;
    }
    if (_sessionTitleController.text.trim().isEmpty) {
      _sessionTitleController.text = _defaultSessionTitle;
    }
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có danh sách sinh viên để điểm danh')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final sessionRes = await ApiService.addAttendanceSession({
        'session_title': _sessionTitleController.text.trim(),
        'session_date': _selectedDate.toIso8601String().substring(0, 10),
        'class_name': className,
        'course_id': int.tryParse(_courseIdController.text.trim()),
        'note': _sessionNoteController.text.trim().isEmpty ? null : _sessionNoteController.text.trim(),
      });

      final records = _drafts.map((draft) {
        return {
          'student_id': draft.student['id'],
          'status': draft.status,
          'note': draft.status == 'excused' ? draft.reasonController.text.trim() : null,
        };
      }).toList();

      await ApiService.addAttendanceRecordsBulk({
        'sessionId': sessionRes['id'],
        'records': records,
      });

      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo buổi và lưu điểm danh')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tạo được buổi điểm danh: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: const Text('Điểm danh'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip('Có mặt: $_presentCount', Colors.green),
                  _infoChip('Vắng phép: $_excusedCount', Colors.orange),
                  _infoChip('Vắng: $_absentCount', Colors.red),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          _buildSummarySection(),
                          const SizedBox(height: 12),
                          _buildSessionSection(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.teal.withOpacity(0.16), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Điểm danh', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Giao diện theo kiểu web dashboard: thiết lập buổi điểm danh, đánh dấu sinh viên và xem thống kê.',
            style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statChip('Có mặt', _presentCount, Colors.green),
              const SizedBox(width: 8),
              _statChip('Vắng phép', _excusedCount, Colors.orange),
              const SizedBox(width: 8),
              _statChip('Vắng', _absentCount, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _buildSummarySection() {
    return _cardShell(
      title: 'Thiết lập buổi điểm danh',
      icon: Icons.event_available,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedClass,
            decoration: const InputDecoration(
              labelText: 'Chọn lớp',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.class_),
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('Chọn lớp...')),
              ..._availableClasses.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))),
            ],
            onChanged: (value) {
              setState(() {
                _selectedClass = value;
                _classController.text = value ?? '';
                _sessionTitleController.text = _defaultSessionTitle;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _sessionTitleController.text = _defaultSessionTitle;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày điểm danh',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    child: Text(_dateLabel),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _courseIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Course ID (nếu theo môn)',
                    prefixIcon: Icon(Icons.book),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sessionTitleController,
            decoration: const InputDecoration(
              labelText: 'Tên buổi điểm danh',
              prefixIcon: Icon(Icons.event_note),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sessionNoteController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_selectedClass == null || _selectedClass!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn lớp')));
                      return;
                    }
                    await _loadStudentsForClass();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('Tải sinh viên'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createSessionAndMark,
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu điểm danh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Danh sách sinh viên',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 360,
              child: ListView.separated(
                itemCount: _drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildStudentCard(_drafts[index].student, _drafts[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Tổng hợp điểm danh'),
        const SizedBox(height: 8),
        if (_summary.isEmpty)
          _emptyHint('Chưa có thống kê điểm danh')
        else
          ..._summary.map((item) => _buildSummaryCard(item)),
        const SizedBox(height: 12),
        _buildSectionTitle('Các buổi điểm danh gần đây'),
        const SizedBox(height: 8),
        if (_sessions.isEmpty)
          _emptyHint('Chưa có buổi điểm danh nào')
        else
          ..._sessions.map((item) => _buildSessionCard(item)),
      ],
    );
  }

  Widget _cardShell({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.teal.shade700),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, _StudentAttendanceDraft draft) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  (student['full_name'] ?? '?').toString().isNotEmpty ? student['full_name'][0].toString().toUpperCase() : '?',
                  style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${student['full_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '${student['student_code'] ?? ''} • ${student['class_name'] ?? ''}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              _statusBadge(draft.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statusButton(draft, 'present', 'Có mặt', Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _statusButton(draft, 'excused', 'Vắng có phép', Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _statusButton(draft, 'absent', 'Vắng không phép', Colors.red)),
            ],
          ),
          if (draft.status == 'excused') ...[
            const SizedBox(height: 12),
            TextField(
              controller: draft.reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do vắng',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF9FBFC),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusButton(_StudentAttendanceDraft draft, String value, String label, Color color) {
    final selected = draft.status == value;
    return InkWell(
      onTap: () => setState(() => draft.status = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : const Color(0xFFF3F6FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 18, color: selected ? color : Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? color : Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'present':
        color = Colors.green;
        label = 'Có mặt';
        break;
      case 'excused':
        color = Colors.orange;
        label = 'Vắng phép';
        break;
      default:
        color = Colors.red;
        label = 'Vắng';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Widget _buildSummaryCard(Map item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(Icons.person, color: Colors.teal.shade700)),
        title: Text(item['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'Mã SV: ${item['student_code'] ?? ''} | Lớp: ${item['class_name'] ?? ''}\n'
          'Có mặt: ${item['present_count'] ?? 0} | Vắng: ${item['absent_count'] ?? 0} | Có phép: ${item['excused_count'] ?? 0}',
        ),
        trailing: Text('${item['total_sessions'] ?? 0} buổi', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSessionCard(Map item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(Icons.event_note, color: Colors.teal.shade700)),
        title: Text(item['session_title'] ?? 'Buổi điểm danh', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${item['class_name'] ?? ''} • ${item['session_date'] ?? ''}'),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _statChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
