import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

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
  List<String> _classOptions = [];
  bool _isLoading = true;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // Filter state
  String? _classFilter;
  _FilterMode _mode = _FilterMode.all;

  bool get _isStudent => widget.role == 'student';
  bool get _canManageSchedules => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadData();
  }

  Future<void> _loadFilters() async {
    List<String> list = [];
    try {
      final classes = await ApiService.getClasses();
      list = classes
          .map((c) => (c['name'] ?? c['class_name'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()..sort();
    } catch (_) {}
    try {
      final schedules = await ApiService.getSchedules();
      list.addAll(schedules.map((s) => (s['class_name'] ?? '').toString().trim()).where((c) => c.isNotEmpty));
    } catch (_) {}
    try {
      final students = await ApiService.getStudents();
      if (students is List) {
        list.addAll(students.map((s) => (s['class_name'] ?? '').toString().trim()).where((c) => c.isNotEmpty));
      }
    } catch (_) {}
    list = list.toSet().toList()..sort();
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
      final results = await Future.wait([
        ApiService.getSchedules(type: 'study'),
        ApiService.getSchedules(type: 'exam'),
      ]);
      final study = results[0].map((s) => _normalizeSchedule(Map<String, dynamic>.from(s))).toList();
      final exam = results[1].map((s) => _normalizeSchedule(Map<String, dynamic>.from(s))).toList();
      if (!mounted) return;
      setState(() {
        _studySchedules = study;
        _examSchedules = exam;
        _isLoading = false;
      });
    } catch (_) {
        if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _normalizeSchedule(Map<String, dynamic> row) {
    final date = (row['schedule_date'] ?? row['date'] ?? '').toString();
    final normalizedDate = date.length >= 10 ? date.substring(0, 10) : date;
    DateTime? parsedDate;
    try { parsedDate = DateTime.parse(normalizedDate); } catch (_) {}
    const weekdays = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return {
      ...row,
      'date': normalizedDate,
      'time': row['schedule_time'] ?? row['time'] ?? '',
      'subject_name': row['subject_name'] ?? row['title'] ?? '',
      'day_of_week': parsedDate == null ? '' : weekdays[parsedDate.weekday],
    };
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
      final scheduleClass = (s['class_name'] ?? '').toString().trim().toLowerCase();
      if (!_isAllClasses(filter) && scheduleClass != filter.trim().toLowerCase()) return false;
      if (_mode == _FilterMode.study && s['type'] != 'study') return false;
      if (_mode == _FilterMode.exam && s['type'] != 'exam') return false;
      return true;
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  List<Map<String, dynamic>> get _filteredStudy {
    final filter = _classFilter ?? _kAllClasses;
    return _studySchedules.where((s) =>
        _isAllClasses(filter) || (s['class_name'] ?? '').toString().trim().toLowerCase() == filter.trim().toLowerCase()).toList();
  }

  List<Map<String, dynamic>> get _filteredExam {
    final filter = _classFilter ?? _kAllClasses;
    return _examSchedules.where((s) =>
        _isAllClasses(filter) || (s['class_name'] ?? '').toString().trim().toLowerCase() == filter.trim().toLowerCase()).toList();
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
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildMonthCalendar(),
                  ),
                  _buildFilterBar(),
                  const SizedBox(height: 90),
                ],
              ),
            ),
      floatingActionButton: _canManageSchedules ? FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm lịch', style: TextStyle(fontWeight: FontWeight.w800)),
            ) : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text('Lịch học / Lịch thi',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                'Tháng ${_visibleMonth.month}/${_visibleMonth.year} • $_countAll lịch (${_countStudy} học / $_countExam thi)',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final eventsByDay = <int, List<Map<String, dynamic>>>{};
    for (final event in _filteredAll) {
      DateTime? date;
      try { date = DateTime.parse((event['date'] ?? '').toString()); } catch (_) {}
      if (date != null && date.year == _visibleMonth.year && date.month == _visibleMonth.month) {
        eventsByDay.putIfAbsent(date.day, () => []).add(event);
      }
    }
    const weekDays = ['Hai', 'Ba', 'Tư', 'Năm', 'Sáu', 'Bảy', 'CN'];
    final today = DateTime.now();
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
          Row(children: [
            IconButton(onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: Text('Tháng ${_visibleMonth.month}, ${_visibleMonth.year}', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)))),
            IconButton(onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
            child: Row(children: weekDays.asMap().entries.map((entry) => Expanded(child: Text(entry.value,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              color: entry.key == 6 ? const Color(0xFF0284C7) : const Color(0xFF374151))))).toList()),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: 45),
            itemCount: cells,
            itemBuilder: (context, index) {
              final day = index - leading + 1;
              if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
              final events = eventsByDay[day] ?? const <Map<String, dynamic>>[];
              final isSunday = index % 7 == 6;
              final isToday = today.year == _visibleMonth.year && today.month == _visibleMonth.month && today.day == day;
              return InkWell(
                onTap: events.isEmpty
                    ? null
                    : () => _showDaySchedules(DateTime(_visibleMonth.year, _visibleMonth.month, day), events),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 27, height: 27, alignment: Alignment.center,
                    decoration: isToday ? const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle) : null,
                    child: Text('$day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: isToday ? Colors.white : (isSunday ? const Color(0xFF0284C7) : const Color(0xFF111827))))),
                  const SizedBox(height: 3),
                  SizedBox(height: 7, child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: events.take(3).map((event) => Container(width: 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(shape: BoxShape.circle,
                      color: event['type'] == 'exam' ? const Color(0xFFF59E0B) : const Color(0xFF22C55E)))).toList())),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.circle, size: 8, color: Color(0xFF22C55E)), SizedBox(width: 4), Text('Lịch học', style: TextStyle(fontSize: 11)),
            SizedBox(width: 16), Icon(Icons.circle, size: 8, color: Color(0xFFF59E0B)), SizedBox(width: 4), Text('Lịch thi', style: TextStyle(fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Future<void> _showDaySchedules(DateTime date, List<Map<String, dynamic>> events) async {
    final sortedEvents = [...events]
      ..sort((a, b) => (a['time'] ?? '').toString().compareTo((b['time'] ?? '').toString()));
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(
                'Lịch ngày ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ...sortedEvents.map((event) {
                final isExam = event['type'] == 'exam';
                final color = isExam ? const Color(0xFFF59E0B) : const Color(0xFF22C55E);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => Navigator.pop(context, event),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(isExam ? Icons.assignment_rounded : Icons.school_rounded, color: color),
                    ),
                    title: Text((event['subject_name'] ?? event['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      (event['time'] ?? '').toString(),
                      'Lớp ${(event['class_name'] ?? '').toString()}',
                      if ((event['room'] ?? '').toString().isNotEmpty) 'Phòng ${event['room']}',
                    ].where((value) => value.isNotEmpty).join(' • ')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) _showScheduleDetail(selected);
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
    // Loại bỏ trùng lặp bằng Set để tránh lỗi "exactly one item with value"
    final uniqueItems = _classOptions.toSet().toList();
    final items = uniqueItems.isEmpty ? [''] : uniqueItems;
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

  void _showScheduleDetail(Map<String, dynamic> s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScheduleDetailSheet(schedule: s, canManage: _canManageSchedules),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _showAddDialog(initial: s);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa lịch'),
          content: Text('Bạn có chắc muốn xóa lịch ${s['subject_name'] ?? ''}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await ApiService.deleteSchedule((s['id'] as num).toInt());
        await _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa lịch')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa lịch: $e')));
      }
    }
  }

  // ===== Add dialog =====

  Future<void> _showAddDialog({Map<String, dynamic>? initial}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddScheduleSheet(initial: initial),
    );
    if (result == null || !mounted) return;

    try {
      final payload = {
        'type': result['type'],
        'title': result['subject_name'],
        'subject_name': result['subject_name'],
        'subject_code': result['subject_code'],
        'class_name': result['class_name'],
        'schedule_date': result['date'],
        'schedule_time': result['time'],
        'room': result['room'],
        'teacher_id': result['teacher_id'],
        'exam_form': result['exam_form'],
        'duration': result['duration'],
        'note': result['note'],
      };
      if (initial == null) {
        await ApiService.addSchedule(payload);
      } else {
        await ApiService.updateSchedule((initial['id'] as num).toInt(), payload);
      }
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${initial == null ? 'Đã thêm' : 'Đã cập nhật'} ${result['type'] == 'exam' ? 'lịch thi' : 'lịch học'}: ${result['subject_name']}'),
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
  final Map<String, dynamic>? initial;
  const _AddScheduleSheet({this.initial});

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  String _type = 'study';
  String? _subject;
  String? _class;
  String? _room;
  String? _examForm;
  String? _teacherLabel;
  int? _teacherId;
  String _duration = '90';
  String _note = '';
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  List<String> _subjects = [];
  List<String> _classes = [];
  List<String> _rooms = [];
  List<String> _examForms = [];
  List<String> _teacherLabels = [];
  final Map<String, int> _teacherIds = {};
  bool _isLoadingOptions = true;
  bool _isLoadingSubjects = false;
  int _subjectRequestId = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _type = (initial['type'] ?? 'study').toString();
      _class = initial['class_name']?.toString();
      _room = initial['room']?.toString();
      _examForm = initial['exam_form']?.toString();
      _teacherId = int.tryParse((initial['teacher_id'] ?? '').toString());
      _duration = (initial['duration'] ?? 90).toString();
      _note = initial['note']?.toString() ?? '';
      final code = initial['subject_code']?.toString() ?? '';
      final name = initial['subject_name']?.toString() ?? '';
      _subject = '$code - $name';
      try { _date = DateTime.parse((initial['date'] ?? initial['schedule_date']).toString()); } catch (_) {}
      final times = (initial['time'] ?? initial['schedule_time'] ?? '').toString().split(' - ');
      if (times.isNotEmpty) _start = _parseTime(times[0], _start);
      if (times.length > 1) _end = _parseTime(times[1], _end);
    }
    _loadOptions();
  }

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? fallback.hour, minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  Future<void> _loadOptions() async {
    List classes = [];
    List schedules = [];
    List attendanceSessions = [];
    List teachers = [];
    try { classes = await ApiService.getClasses(); } catch (_) {}
    if (classes.isEmpty) {
      try {
        final students = await ApiService.getStudents();
        if (students is List) {
          classes = students
              .map((s) => {'name': s['class_name']})
              .where((c) => (c['name'] ?? '').toString().isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    try { schedules = await ApiService.getSchedules(); } catch (_) {}
    try { attendanceSessions = await ApiService.getAttendanceSessions(); } catch (_) {}
    try { teachers = await ApiService.getTeachers(); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _classes = classes
          .map((c) => (c['name'] ?? c['class_name'] ?? '').toString())
          .where((c) => c.isNotEmpty)
          .toSet().toList();
      _rooms = schedules
          .map((s) => (s['room'] ?? '').toString())
          .followedBy(attendanceSessions.map((s) => (s['room'] ?? '').toString()))
          .where((room) => room.isNotEmpty)
          .toSet().toList();
      _examForms = schedules
          .map((s) => (s['exam_form'] ?? '').toString())
          .where((form) => form.isNotEmpty)
          .toSet().toList();
      _teacherIds.clear();
      for (final teacher in teachers) {
        final teacherId = int.tryParse((teacher['id'] ?? '').toString());
        final name = (teacher['full_name'] ?? teacher['teacher_code'] ?? '').toString().trim();
        if (teacherId != null && name.isNotEmpty) _teacherIds['$name (#${teacher['teacher_code']})'] = teacherId;
      }
      _teacherLabels = _teacherIds.keys.toList()..sort();
      if (_teacherId != null) {
        for (final entry in _teacherIds.entries) {
          if (entry.value == _teacherId) _teacherLabel = entry.key;
        }
      }
      _teacherLabel ??= _teacherLabels.isNotEmpty ? _teacherLabels.first : null;
      _teacherId ??= _teacherLabel == null ? null : _teacherIds[_teacherLabel];
      _subject ??= _subjects.isNotEmpty ? _subjects.first : null;
      _class ??= _classes.isNotEmpty ? _classes.first : null;
      _room ??= _rooms.isNotEmpty ? _rooms.first : null;
      _examForm ??= _examForms.isNotEmpty ? _examForms.first : null;
      _isLoadingOptions = false;
    });
    await _loadSubjectsForClass();
  }

  Future<void> _loadSubjectsForClass() async {
    final selectedClass = _class?.trim() ?? '';
    final previousSubject = _subject;
    final requestId = ++_subjectRequestId;
    setState(() {
      _subjects = [];
      _subject = null;
      _isLoadingSubjects = true;
    });
    if (selectedClass.isEmpty) {
      setState(() => _isLoadingSubjects = false);
      return;
    }
    try {
      final courses = await ApiService.getCourses(className: selectedClass);
      if (!mounted || requestId != _subjectRequestId || _class?.trim() != selectedClass) return;
      final subjects = courses.map((course) {
          final code = (course['code'] ?? course['subject_code'] ?? '').toString();
          final name = (course['name'] ?? course['subject_name'] ?? '').toString();
          return '$code - $name';
        })
        .where((subject) => subject != ' - ')
        .toSet()
        .toList();
      setState(() {
        _subjects = subjects;
        _subject = previousSubject != null && subjects.contains(previousSubject)
            ? previousSubject
            : (subjects.isNotEmpty ? subjects.first : null);
        _isLoadingSubjects = false;
      });
    } catch (_) {
      if (mounted && requestId == _subjectRequestId) {
        setState(() => _isLoadingSubjects = false);
      }
    }
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
    if (_subject == null || _class == null || _room == null || _teacherId == null) {
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
      'teacher_id': _teacherId,
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
                    hint: _isLoadingSubjects
                        ? 'Đang tải môn học...'
                        : (_subjects.isEmpty ? 'Lớp chưa có môn học' : 'Chọn môn học'),
                    onChanged: _isLoadingSubjects ? null : (v) => setState(() => _subject = v),
                  ),
                ),
                _field(
                  label: 'Lớp',
                  icon: Icons.class_rounded,
                  child: _dropdown(
                    value: _class,
                    items: _classes,
                    hint: 'Chọn lớp',
                    onChanged: (v) {
                      setState(() => _class = v);
                      _loadSubjectsForClass();
                    },
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
                  child: _rooms.isNotEmpty
                      ? _dropdown(
                          value: _room,
                          items: _rooms,
                          hint: 'Chọn phòng',
                          onChanged: (v) => setState(() => _room = v),
                        )
                      : TextField(
                          decoration: InputDecoration(
                            hintText: _isLoadingOptions ? 'Đang tải phòng...' : 'Nhập phòng học',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (value) => _room = value.trim(),
                        ),
                ),
                _field(
                  label: 'Giáo viên phụ trách',
                  icon: Icons.person_rounded,
                  child: _dropdown(
                    value: _teacherLabel,
                    items: _teacherLabels,
                    hint: _teacherLabels.isEmpty ? 'Chưa có tài khoản giáo viên' : 'Chọn giáo viên',
                    onChanged: (value) => setState(() {
                      _teacherLabel = value;
                      _teacherId = value == null ? null : _teacherIds[value];
                    }),
                  ),
                ),
                if (isExam) ...[
                  _field(
                    label: 'Hình thức thi',
                    icon: Icons.assignment_turned_in_rounded,
                    child: _examForms.isNotEmpty
                        ? _dropdown(
                            value: _examForm,
                            items: _examForms,
                            hint: 'Chọn hình thức',
                            onChanged: (v) => setState(() => _examForm = v),
                          )
                        : TextField(
                            decoration: InputDecoration(
                              hintText: _isLoadingOptions ? 'Đang tải...' : 'Nhập hình thức thi',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (value) => _examForm = value.trim(),
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
    required ValueChanged<String?>? onChanged,
  }) {
    // Loại bỏ trùng lặp bằng Set để tránh lỗi "exactly one item with value"
    final uniqueItems = items.toSet().toList();
    final safeItems = uniqueItems.isEmpty ? const [''] : uniqueItems;
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
  final bool canManage;
  const _ScheduleDetailSheet({required this.schedule, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isExam = (schedule['type'] ?? '') == 'exam';
    final color = isExam ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    final subjectCode = schedule['subject_code']?.toString() ?? '';
    final subjectName = schedule['subject_name']?.toString() ?? '';
    final className = schedule['class_name']?.toString() ?? '';
    final rawDate = schedule['date']?.toString() ?? '';
    final date = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    final dayOfWeek = schedule['day_of_week']?.toString() ?? '';
    final time = schedule['time']?.toString() ?? '';
    final room = schedule['room']?.toString() ?? '';
    final teacherName = schedule['teacher_name']?.toString() ?? '';
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
                  if (teacherName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoBox(Icons.person_rounded, 'Giáo viên phụ trách', teacherName, color),
                  ],
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
            if (canManage) SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'delete'),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Xóa'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          foregroundColor: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, 'edit'),
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
