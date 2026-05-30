import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _classController = TextEditingController();
  final _sessionTitleController = TextEditingController();
  final _sessionNoteController = TextEditingController();
  final _courseIdController = TextEditingController();
  bool _isLoading = false;
  List _sessions = [];
  List _summary = [];
  List _students = [];
  DateTime _selectedDate = DateTime.now();
  String _mode = 'class';
  String _selectedStatus = 'present';

  @override
  void dispose() {
    _classController.dispose();
    _sessionTitleController.dispose();
    _sessionNoteController.dispose();
    _courseIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await ApiService.getAttendanceSessions(
        className: _classController.text.trim(),
        courseId: int.tryParse(_courseIdController.text.trim()),
      );
      final summary = await ApiService.getAttendanceSummary(
        className: _classController.text.trim(),
        courseId: int.tryParse(_courseIdController.text.trim()),
      );
      setState(() {
        _sessions = sessions;
        _summary = summary;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentsForClass() async {
    final data = await ApiService.getStudents();
    final className = _classController.text.trim();
    setState(() {
      if (data is List) {
        _students = className.isEmpty
            ? data
            : data.where((s) => (s['class_name'] ?? '') == className).toList();
      } else if (data is Map) {
        _students = [data];
      } else {
        _students = [];
      }
    });
  }

  Future<void> _createSessionAndMark() async {
    setState(() => _isLoading = true);
    try {
      final sessionRes = await ApiService.addAttendanceSession({
        'session_title': _sessionTitleController.text.trim(),
        'session_date': _selectedDate.toIso8601String().substring(0, 10),
        'class_name': _classController.text.trim(),
        'course_id': int.tryParse(_courseIdController.text.trim()),
        'note': _sessionNoteController.text.trim().isEmpty ? null : _sessionNoteController.text.trim(),
      });
      final records = _students.map((student) => {
        'student_id': student['id'],
        'status': _selectedStatus,
        'note': null,
      }).toList();
      await ApiService.addAttendanceRecordsBulk({
        'sessionId': sessionRes['id'],
        'records': records,
      });
      await _loadData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Điểm danh'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'class', label: Text('Theo lớp')),
                              ButtonSegment(value: 'course', label: Text('Theo môn')),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (value) {
                              setState(() => _mode = value.first);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _classController,
                      decoration: const InputDecoration(
                        labelText: 'Lớp',
                        prefixIcon: Icon(Icons.class_),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _courseIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Course ID (nếu theo môn)',
                        prefixIcon: Icon(Icons.book),
                        border: OutlineInputBorder(),
                      ),
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
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'present', child: Text('Có mặt')),
                        DropdownMenuItem(value: 'absent', child: Text('Vắng')),
                        DropdownMenuItem(value: 'late', child: Text('Muộn')),
                        DropdownMenuItem(value: 'excused', child: Text('Có phép')),
                      ],
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái mặc định',
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _loadStudentsForClass();
                          await _createSessionAndMark();
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Tạo buổi & lưu điểm danh'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.search),
                        label: const Text('Xem thống kê'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        _buildSectionTitle('Tổng hợp điểm danh'),
                        const SizedBox(height: 8),
                        ..._summary.map((item) => Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              child: ListTile(
                                title: Text(item['full_name'] ?? ''),
                                subtitle: Text(
                                  'Mã SV: ${item['student_code'] ?? ''} | Lớp: ${item['class_name'] ?? ''}\n'
                                  'Có mặt: ${item['present_count'] ?? 0} | Vắng: ${item['absent_count'] ?? 0} | Muộn: ${item['late_count'] ?? 0} | Có phép: ${item['excused_count'] ?? 0}',
                                ),
                                trailing: Text('${item['total_sessions'] ?? 0} buổi'),
                              ),
                            )),
                        const SizedBox(height: 12),
                        _buildSectionTitle('Các buổi điểm danh gần đây'),
                        const SizedBox(height: 8),
                        ..._sessions.map((item) => Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              child: ListTile(
                                leading: const Icon(Icons.event_note),
                                title: Text(item['session_title'] ?? 'Buổi điểm danh'),
                                subtitle: Text(
                                  '${item['class_name'] ?? ''} • ${item['session_date'] ?? ''}',
                                ),
                              ),
                            )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
