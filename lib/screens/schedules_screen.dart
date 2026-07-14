import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mock_data_service.dart';

const String _kAllClasses = 'Tất cả lớp';

class SchedulesScreen extends StatefulWidget {
  final String? role;
  final int? studentId;
  const SchedulesScreen({super.key, this.role, this.studentId});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

enum _FilterMode { all, study, exam }

class _SchedulesScreenState extends State<SchedulesScreen> {
  List<Map<String, dynamic>> _studySchedules = [];
  List<Map<String, dynamic>> _examSchedules = [];
  List<Map<String, dynamic>> _weekSummary = [];
  List<String> _classOptions = [];
  bool _isLoading = true;

  // Filter state
  String? _classFilter;
  _FilterMode _mode = _FilterMode.all;

  bool get _isStudent => widget.role == 'student';

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadData();
  }

  Future<void> _loadFilters() async {
    final list = await MockDataService.getScheduleClasses();
    final options = <String>[];
    if (!_isStudent) {
      // Admin/Teacher: thêm "Tất cả lớp" để xem toàn bộ
      options.add(_kAllClasses);
    }
    options.addAll(list.where((c) => c.isNotEmpty));

    String? defaultFilter;
    if (_isStudent) {
      // Student: mặc định là lớp của sinh viên
      final prefs = await SharedPreferences.getInstance();
      final cls = prefs.getString('class_name')?.trim();
      if (cls != null && cls.isNotEmpty) {
        defaultFilter = options.contains(cls) ? cls : (options.isNotEmpty ? options.first : null);
      } else {
        defaultFilter = options.isNotEmpty ? options.first : null;
      }
    } else {
      defaultFilter = _kAllClasses; // "Tất cả lớp"
    }

    if (!mounted) return;
    setState(() {
      _classOptions = options;
      _classFilter = defaultFilter;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Tải tuần tự để _weekSummary có thể tính từ chính lịch thực tế
      final study = await MockDataService.getSchedules(type: 'study', studentId: widget.studentId);
      final exam = await MockDataService.getSchedules(type: 'exam', studentId: widget.studentId);
      final week = await MockDataService.getScheduleWeekSummary(fromSchedules: study);
      if (!mounted) return;
      setState(() {
        _studySchedules = study;
        _examSchedules = exam;
        _weekSummary = week;
        _isLoading = false;
      });
    } catch (_) {
        if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ===== Filter helpers =====

  bool _isAllClasses(String filter) => filter == _kAllClasses || filter.isEmpty;

  List<Map<String, dynamic>> get _filteredAll {
    final list = <Map<String, dynamic>>[
      ..._studySchedules,
      ..._examSchedules,
    ];
    return list.where((s) {
      final filter = _classFilter ?? _kAllClasses;
      if (!_isAllClasses(filter) && s['class_name'] != filter) return false;
      if (_mode == _FilterMode.study && s['type'] != 'study') return false;
      if (_mode == _FilterMode.exam && s['type'] != 'exam') return false;
      return true;
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  List<Map<String, dynamic>> get _filteredStudy {
    final filter = _classFilter ?? _kAllClasses;
    return _studySchedules.where((s) =>
        _isAllClasses(filter) || s['class_name'] == filter).toList();
  }

  List<Map<String, dynamic>> get _filteredExam {
    final filter = _classFilter ?? _kAllClasses;
    return _examSchedules.where((s) =>
        _isAllClasses(filter) || s['class_name'] == filter).toList();
  }

  int get _countStudy => _filteredStudy.length;
  int get _countExam => _filteredExam.length;
  int get _countAll => _countStudy + _countExam;

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
                children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _buildWeekSummary(),
                ),
                _buildFilterBar(),
                Expanded(child: _buildFilteredList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm lịch', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text('Lịch học / Lịch thi',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                'Tuần ${_getWeekNumber()} • $_countAll lịch (${_countStudy} học / $_countExam thi)',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              const Text('Tổng quan tuần',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              const Spacer(),
              Text(
                '$_countAll buổi',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _weekSummary.map((d) {
              final color = _dayColor(d['color'] as String);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
            children: [
                      Text(d['day'] as String,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withOpacity(d['count'] == 0 ? 0.05 : 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Text(
                          '${d['count']}',
                          style: TextStyle(
                            color: d['count'] == 0 ? const Color(0xFF9CA3AF) : color,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
              ),
            ],
          ),
    );
  }

  // ===== Filter bar (sticky) =====

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFFF5F7FB),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
            children: [
          // Toggle: Tất cả / Lịch học / Lịch thi
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                _modeChip(_FilterMode.all, 'Tất cả', _countAll),
                _modeChip(_FilterMode.study, 'Lịch học', _countStudy, color: const Color(0xFF3B82F6)),
                _modeChip(_FilterMode.exam, 'Lịch thi', _countExam, color: const Color(0xFFEF4444)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Dropdown lớp
          _classDropdown(),
        ],
      ),
    );
  }

  Widget _modeChip(_FilterMode m, String label, int count, {Color? color}) {
    final selected = _mode == m;
    final accent = color ?? const Color(0xFF6B7280);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _mode = m),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.25)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _classDropdown() {
    // Phòng trường hợp value chưa có trong items, fallback về item đầu tiên để tránh crash DropdownButton
    final items = _classOptions;
    final value = (items.contains(_classFilter)) ? _classFilter : (items.isNotEmpty ? items.first : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                items: items
                    .map((c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c.isEmpty ? _kAllClasses : c),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _classFilter = v);
                },
              ),
            ),
          ),
          if (value != null && value.isNotEmpty && !_isAllClasses(value))
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
              onPressed: () => setState(() => _classFilter = _isStudent ? value : _kAllClasses),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // ===== List =====

  Widget _buildFilteredList() {
    final items = _filteredAll;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
      child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
        children: [
              Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('Không có lịch nào',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildScheduleCard(items[i]),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> s) {
    final isExam = s['type'] == 'exam';
    final color = isExam ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showScheduleDetail(s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    (s['date'] as String).split('-').last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    _monthFromDate(s['date'] as String),
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s['day_of_week'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
      child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s['subject_name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isExam ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isExam ? 'THI' : 'HỌC',
                          style: TextStyle(
                            color: isExam ? const Color(0xFFB91C1C) : const Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s['subject_code']} • Lớp ${s['class_name']}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _iconChip(Icons.access_time_rounded, s['time'] as String),
                      const SizedBox(width: 6),
                      _iconChip(Icons.room_rounded, s['room'] as String),
                    ],
                  ),
                  if (isExam && s['exam_form'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _iconChip(Icons.assignment_turned_in_rounded, s['exam_form'] as String),
                        const SizedBox(width: 6),
                        _iconChip(Icons.timer_rounded, '${s['duration']} phút'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showScheduleDetail(Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScheduleDetailSheet(schedule: s),
    );
  }

  // ===== Add dialog =====

  Future<void> _showAddDialog() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddScheduleSheet(),
    );
    if (result == null || !mounted) return;

    try {
      final created = await MockDataService.createSchedule(result);
      setState(() {
        if (created['type'] == 'exam') {
          _examSchedules.add(created);
        } else {
          _studySchedules.add(created);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${created['type'] == 'exam' ? 'lịch thi' : 'lịch học'}: ${created['subject_name']}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  // ===== Helpers =====

  int _getWeekNumber() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    return ((now.difference(start).inDays) / 7).ceil();
  }

  String _monthFromDate(String date) {
    final parts = date.split('-');
    if (parts.length < 3) return '';
    final m = int.tryParse(parts[1]) ?? 0;
    const months = ['', 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12'];
    return months[m];
  }

  Color _dayColor(String colorName) {
    switch (colorName) {
      case 'indigo': return const Color(0xFF6366F1);
      case 'blue': return const Color(0xFF3B82F6);
      case 'green': return const Color(0xFF10B981);
      case 'orange': return const Color(0xFFF59E0B);
      case 'purple': return const Color(0xFFA855F7);
      case 'red': return const Color(0xFFEF4444);
      case 'grey': return const Color(0xFF6B7280);
      default: return const Color(0xFF6B7280);
    }
  }
}

// ============ Add schedule bottom sheet ============

class _AddScheduleSheet extends StatefulWidget {
  const _AddScheduleSheet();

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  String _type = 'study';
  String? _subject;
  String? _class;
  String? _room;
  String? _examForm;
  String _duration = '90';
  String _note = '';
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  List<String> _subjects = [];
  List<String> _classes = [];
  List<String> _rooms = [];
  List<String> _examForms = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final results = await Future.wait([
      MockDataService.getScheduleSubjects(),
      MockDataService.getScheduleClasses(),
      MockDataService.getScheduleRooms(),
      MockDataService.getScheduleExamForms(),
    ]);
    if (!mounted) return;
    setState(() {
      _subjects = results[0];
      _classes = (results[1] as List<String>).where((c) => c != 'Tất cả lớp').toList();
      _rooms = results[2];
      _examForms = results[3];
      _subject ??= _subjects.isNotEmpty ? _subjects.first : null;
      _class ??= _classes.isNotEmpty ? _classes.first : null;
      _room ??= _rooms.isNotEmpty ? _rooms.first : null;
      _examForm ??= _examForms.isNotEmpty ? _examForms.first : null;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (t == null) return;
    setState(() {
      if (isStart) {
        _start = t;
        // Auto push end = start + 2h if end <= start
        final endMin = _end.hour * 60 + _end.minute;
        final startMin = t.hour * 60 + t.minute;
        if (endMin <= startMin) {
          _end = TimeOfDay(hour: (t.hour + 2) % 24, minute: t.minute);
        }
      } else {
        _end = t;
      }
    });
  }

  void _save() {
    if (_subject == null || _class == null || _room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đầy đủ thông tin'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }
    final subjectCode = _subject!.split(' - ').first;
    final subjectName = _subject!.contains(' - ') ? _subject!.split(' - ').skip(1).join(' - ') : _subject!;
    final dateStr = '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')} - ${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}';
    Navigator.pop(context, {
      'type': _type,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'class_name': _class,
      'date': dateStr,
      'time': timeStr,
      'room': _room,
      'exam_form': _type == 'exam' ? _examForm : null,
      'duration': _type == 'exam' ? int.tryParse(_duration) : null,
      'note': _note,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExam = _type == 'exam';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text('Thêm lịch học / lịch thi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                const SizedBox(height: 16),

                // Type toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _typeTab('study', 'Lịch học', Icons.school_rounded, const Color(0xFF3B82F6)),
                      _typeTab('exam', 'Lịch thi', Icons.assignment_rounded, const Color(0xFFEF4444)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _field(
                  label: 'Môn học',
                  icon: Icons.menu_book_rounded,
                  child: _dropdown(
                    value: _subject,
                    items: _subjects,
                    hint: 'Chọn môn học',
                    onChanged: (v) => setState(() => _subject = v),
                  ),
                ),
                _field(
                  label: 'Lớp',
                  icon: Icons.class_rounded,
                  child: _dropdown(
                    value: _class,
                    items: _classes,
                    hint: 'Chọn lớp',
                    onChanged: (v) => setState(() => _class = v),
                  ),
                ),
                _field(
                  label: 'Ngày',
                  icon: Icons.event_rounded,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const Spacer(),
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6B7280)),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: _field(
                      label: 'Bắt đầu',
                      icon: Icons.access_time_rounded,
                      child: _timeBox(_start, () => _pickTime(true)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _field(
                      label: 'Kết thúc',
                      icon: Icons.access_time_filled_rounded,
                      child: _timeBox(_end, () => _pickTime(false)),
                    )),
                  ],
                ),
                _field(
                  label: 'Phòng',
                  icon: Icons.room_rounded,
                  child: _dropdown(
                    value: _room,
                    items: _rooms,
                    hint: 'Chọn phòng',
                    onChanged: (v) => setState(() => _room = v),
                  ),
                ),
                if (isExam) ...[
                  _field(
                    label: 'Hình thức thi',
                    icon: Icons.assignment_turned_in_rounded,
                    child: _dropdown(
                      value: _examForm,
                      items: _examForms,
                      hint: 'Chọn hình thức',
                      onChanged: (v) => setState(() => _examForm = v),
                    ),
                  ),
                  _field(
                    label: 'Thời lượng (phút)',
                    icon: Icons.timer_rounded,
                    child: _dropdown(
                      value: _duration,
                      items: const ['45', '60', '90', '120', '150'],
                      hint: 'Chọn thời lượng',
                      onChanged: (v) => setState(() => _duration = v ?? '90'),
                    ),
                  ),
                ],
                _field(
                  label: 'Ghi chú (tuỳ chọn)',
                  icon: Icons.note_rounded,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Ghi chú thêm...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    maxLines: 2,
                    onChanged: (v) => _note = v,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Huỷ', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExam ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _save,
                        child: const Text('Lưu lịch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeTab(String value, String label, IconData icon, Color color) {
    final selected = _type == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF374151),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({required String label, required IconData icon, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    // Đảm bảo value luôn nằm trong items (tránh DropdownButton crash)
    final safeItems = items.isEmpty ? const [''] : items;
    final actualValue = (value != null && safeItems.contains(value))
        ? value
        : (safeItems.isNotEmpty && safeItems.first.isNotEmpty ? safeItems.first : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: actualValue,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: safeItems.map((it) => DropdownMenuItem<String>(value: it, child: Text(it, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _timeBox(TimeOfDay t, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const Spacer(),
            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

// ============ Schedule Detail Sheet ============

class _ScheduleDetailSheet extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const _ScheduleDetailSheet({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final isExam = (schedule['type'] ?? '') == 'exam';
    final color = isExam ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    final subjectCode = schedule['subject_code']?.toString() ?? '';
    final subjectName = schedule['subject_name']?.toString() ?? '';
    final className = schedule['class_name']?.toString() ?? '';
    final date = schedule['date']?.toString() ?? '';
    final dayOfWeek = schedule['day_of_week']?.toString() ?? '';
    final time = schedule['time']?.toString() ?? '';
    final room = schedule['room']?.toString() ?? '';
    final examForm = schedule['exam_form']?.toString();
    final duration = schedule['duration'];
    final note = schedule['note']?.toString() ?? '';
    final id = schedule['id']?.toString() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      child: Column(
        children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
          Row(
            children: [
              Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isExam ? Icons.assignment_rounded : Icons.class_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subjectName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isExam ? 'THI' : 'HỌC',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                    const SizedBox(height: 4),
                            Text(
                              '$subjectCode • Lớp $className',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ],
                ),
              ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                  ],
                ),
            ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(child: _infoBox(Icons.calendar_today_rounded, 'Ngày', _fmtDate(date), color)),
                      const SizedBox(width: 8),
                      Expanded(child: _infoBox(Icons.access_time_rounded, 'Giờ', time, color)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _infoBox(Icons.room_rounded, 'Phòng', room, color)),
                      const SizedBox(width: 8),
                      Expanded(child: _infoBox(Icons.event_note_rounded, 'Thứ', dayOfWeek, color)),
                    ],
                  ),
                  if (isExam && examForm != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _infoBox(Icons.assignment_turned_in_rounded, 'Hình thức', examForm, color)),
                        const SizedBox(width: 8),
                        Expanded(child: _infoBox(Icons.timer_rounded, 'Thời lượng', '$duration phút', color)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (note.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note_rounded, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              note,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4),
                            ),
                          ),
                        ],
                      ),
          ),
          const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
            children: [
                        const Icon(Icons.fingerprint_rounded, size: 14, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Text('Mã lịch: #$id',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã xuất lịch'), backgroundColor: Color(0xFF10B981)),
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Chia sẻ'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          foregroundColor: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã mở form chỉnh sửa: $subjectName'),
                              backgroundColor: color,
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Chỉnh sửa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827), fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  String _fmtDate(String date) {
    if (date.isEmpty) return '—';
    if (date.length >= 10) {
      final d = date.substring(8, 10);
      final m = date.substring(5, 7);
      final y = date.substring(0, 4);
      return '$d/$m/$y';
    }
    return date;
  }
}