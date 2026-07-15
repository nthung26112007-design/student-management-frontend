import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import '../services/api_service.dart';
class AttendanceScreen extends StatefulWidget {
  final String? role;
  final int? studentId;
  const AttendanceScreen({super.key, this.role, this.studentId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String _filter = 'all'; // all | present | absent | late
  List<String> _classOptions = [];
  List<String> _subjectOptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      List<dynamic> summary = [];
      List<dynamic> sessions = [];

      try {
        sessions = await ApiService.getAttendanceSessions();
      } catch (_) {}

      Map<String, int> classStudentCounts = {};
      try {
        final allStudents = await ApiService.getStudents();
        if (allStudents is List) {
          for (var s in allStudents) {
            final cName = s['class_name']?.toString().trim() ?? '';
            if (cName.isNotEmpty) {
              classStudentCounts[cName] = (classStudentCounts[cName] ?? 0) + 1;
            }
          }
          if (mounted) {
            _classOptions = classStudentCounts.keys.toList();
            _classOptions.sort();
          }
        }
      } catch (_) {}

      try {
        final allCourses = await ApiService.getCourses();
        if (allCourses is List) {
          final courses = allCourses.map((e) {
            final code = e['code']?.toString() ?? e['subject_code']?.toString() ?? '';
            final name = e['name']?.toString() ?? e['subject_name']?.toString() ?? '';
            return '$code - $name';
          }).where((s) => s != ' - ').toSet().toList();
          
          if (mounted && courses.isNotEmpty) {
            _subjectOptions = courses;
          }
        }
      } catch (_) {}

      // No fallback to MockDataService for sessions, strictly use DB.
      summary = await MockDataService.getAttendanceSummary(
        fromSessions: sessions.map((e) => Map<String, dynamic>.from(e)).toList(),
      );

      if (!mounted) return;
      setState(() {
        _summary = summary.map((e) => Map<String, dynamic>.from(e)).toList();
        _sessions = sessions.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterSessions() {
    if (_filter == 'all') return _sessions;
    return _sessions.where((s) => s['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildSummaryCards(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabHeaderDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF14B8A6),
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: const Color(0xFF14B8A6),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Theo buổi học'),
                        Tab(text: 'Tổng hợp'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildSessionList(),
                  _buildSummaryView(),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: const Color(0xFF14B8A6),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Quản lý điểm danh',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 56),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Điểm danh lớp CK-K46A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hôm nay • ${_sessions.length} buổi đã tạo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => _showCreateSessionDialog(),
          tooltip: 'Tạo buổi điểm danh',
        ),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
      ],
    );
  }

  Widget _buildSummaryView() {
    // Tổng hợp thật từ _sessions — cộng các count do service trả (không suy từ status).
    final totalSessions = _sessions.length;
    int totalStudentsCount = 0;
    int totalPresent = 0;
    int totalLate = 0;
    int totalAbsent = 0;
    int totalExcused = 0;
    int totalUnmarked = 0;
    for (final s in _sessions) {
      totalStudentsCount += int.tryParse(s['total_count']?.toString() ?? '0') ?? 0;
      totalPresent += int.tryParse(s['present_count']?.toString() ?? '0') ?? 0;
      totalLate += int.tryParse(s['late_count']?.toString() ?? '0') ?? 0;
      totalAbsent += int.tryParse(s['absent_count']?.toString() ?? '0') ?? 0;
      totalExcused += int.tryParse(s['excused_count']?.toString() ?? '0') ?? 0;
      totalUnmarked += int.tryParse(s['unmarked_count']?.toString() ?? '0') ?? 0;
    }
    final attended = totalPresent + totalLate;
    final ratio = totalStudentsCount > 0
        ? ((attended / totalStudentsCount) * 100).round()
        : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Hero panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tổng quan điểm danh',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('$ratio%',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                '$attended / $totalStudentsCount lượt điểm danh trong $totalSessions buổi',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 4 ô tổng hợp — đồng bộ với chi tiết buổi
        Row(children: [
          Expanded(child: _summaryStatBox('Có mặt', '$totalPresent', const Color(0xFF10B981), Icons.check_circle_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _summaryStatBox('Muộn', '$totalLate', const Color(0xFFF59E0B), Icons.schedule_rounded)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _summaryStatBox('Vắng', '$totalAbsent', const Color(0xFFEF4444), Icons.cancel_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _summaryStatBox('Có phép', '$totalExcused', const Color(0xFF3B82F6), Icons.verified_user_outlined)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _summaryStatBox('Chưa ĐD', '$totalUnmarked', const Color(0xFF6B7280), Icons.help_outline_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _summaryStatBox('Tổng SV lượt', '$totalStudentsCount', const Color(0xFF14B8A6), Icons.groups_2_rounded)),
        ]),
        const SizedBox(height: 20),
        // Chi tiết từng buổi
        Row(children: [
          const Text('Chi tiết từng buổi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const Spacer(),
          Text('$totalSessions buổi',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (_sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text('Chưa có buổi học nào',
                style: TextStyle(color: Color(0xFF6B7280))),
          )
        else
          ..._sessions.map((s) {
            final tot = int.tryParse(s['total_count']?.toString() ?? '0') ?? 0;
            final pre = int.tryParse(s['present_count']?.toString() ?? '0') ?? 0;
            final st = (s['status'] ?? '').toString();
            final ratioS = tot > 0 ? ((pre / tot) * 100).round() : 0;
            final color = _statusColorFromStatus(st);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.event_note_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['subject']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${s['date'] ?? ''} • ${s['class_name'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _miniBadge('${_statusLabel(st)}', color),
                        const SizedBox(width: 6),
                        _miniBadge('$pre/$tot', const Color(0xFF3B82F6)),
                        const SizedBox(width: 6),
                        _miniBadge('$ratioS%', const Color(0xFF14B8A6)),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
              ]),
            );
          }),
      ],
    );
  }

  Widget _summaryStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: _summary.map((s) {
        final color = _statusColor(s['color']?.toString() ?? '');
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: s == _summary.last ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(s['value']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                    )),
                const SizedBox(height: 2),
                Text(s['label']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${s['count']}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionList() {
    final list = _filterSessions();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('all', 'Tất cả', Icons.list_alt_rounded),
                _filterChip('present', 'Có mặt', Icons.check_circle_outline),
                _filterChip('late', 'Muộn', Icons.schedule_rounded),
                _filterChip('absent', 'Vắng', Icons.cancel_outlined),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('Không có buổi học nào',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _buildSessionCard(list[index]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : const Color(0xFF14B8A6)),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF374151),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        selectedColor: const Color(0xFF14B8A6),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? const Color(0xFF14B8A6) : const Color(0xFFE5E7EB)),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final status = session['status']?.toString() ?? '';
    final color = _statusColorFromStatus(status);
    final rawDate = session['date']?.toString() ?? '';
    final dateStr = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showSessionDetail(session),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dateStr.split('-').last,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _monthFromDate(dateStr),
                        style: const TextStyle(color: Colors.white70, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session['session_title']?.toString() ?? session['subject_name']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (session['start_time'] != null && session['end_time'] != null)
                            '${session['start_time']} - ${session['end_time']}',
                          if (session['room'] != null)
                            'Phòng ${session['room']}',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'Lớp ${session['class_name']}',
                          if (session['lecturer'] != null && session['lecturer'].toString().isNotEmpty)
                            'GV: ${session['lecturer']}',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF6B7280)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showCreateSessionDialog(initialSession: session);
                        } else if (val == 'delete') {
                          _deleteSession(session['id']);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Sửa buổi học')),
                        const PopupMenuItem(value: 'delete', child: Text('Xóa buổi học')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _statusBadge(status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _attendanceStat('Có mặt', session['present_count'], const Color(0xFF10B981)),
                  Container(width: 1, height: 16, color: const Color(0xFFE5E7EB)),
                  _attendanceStat('Muộn', session['late_count'], const Color(0xFFF59E0B)),
                  Container(width: 1, height: 16, color: const Color(0xFFE5E7EB)),
                  _attendanceStat('Vắng', session['absent_count'], const Color(0xFFEF4444)),
                  const Spacer(),
                  Text('Xem chi tiết',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  Icon(Icons.chevron_right_rounded, size: 16, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceStat(String label, dynamic count, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$count',
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColorFromStatus(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  void _showSessionDetail(Map<String, dynamic> session) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SessionDetailSheet(session: session),
    );
    if (updated == null || !mounted) return;
    // Cập nhật lại session trong _sessions
    setState(() {
      final idx = _sessions.indexWhere((s) => (s['id'] ?? '') == (updated['id'] ?? ''));
      if (idx >= 0) {
        _sessions[idx] = {..._sessions[idx], ...updated};
      }
    });
  }

  void _showCreateSessionDialog({Map<String, dynamic>? initialSession}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: _CreateSessionDialog(
            classOptions: _classOptions,
            subjectOptions: _subjectOptions,
            initialSession: initialSession,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;

    final subjectStr = result['subject']?.toString() ?? '';
    final parts = subjectStr.split(' - ');
    final subjectCode = parts.first.trim();
    final subjectName = parts.length > 1 ? parts.sublist(1).join(' - ') : subjectStr;
    final rawDate = result['date']?.toString() ?? '';
    final dateParts = rawDate.split('-');
    final displayDate = dateParts.length == 3
        ? '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}'
        : rawDate;
    final sessionTitle = '$displayDate - ${result['class_name']} - $subjectName';

    try {
      final payload = {
        'session_title': sessionTitle,
        'session_date': result['date'],
        'class_name': result['class_name'],
        'course_id': null, 
        'subject_code': subjectCode,
        'room': result['room'],
        'start_time': result['start_time'],
        'end_time': result['end_time'],
        'lecturer': result['lecturer'],
        'teacher_id': result['teacher_id'],
      };

      if (initialSession != null) {
        await ApiService.updateAttendanceSession(initialSession['id'], payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật buổi điểm danh thành công'), backgroundColor: Color(0xFF10B981)),
        );
      } else {
        await ApiService.addAttendanceSession(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo buổi điểm danh thành công'), backgroundColor: Color(0xFF10B981)),
        );
      }
      
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _deleteSession(int id) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa buổi điểm danh này không? Mọi dữ liệu điểm danh sẽ bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa')
          ),
        ],
      )
    );
    if (conf != true) return;

    try {
      await ApiService.deleteAttendanceSession(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa buổi điểm danh'), backgroundColor: Color(0xFF10B981)),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  String _monthFromDate(String date) {
    final parts = date.split('-');
    if (parts.length < 3) return '';
    final m = int.tryParse(parts[1]) ?? 0;
    const months = ['', 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12'];
    return months[m];
  }

  Color _statusColor(String colorName) {
    switch (colorName) {
      case 'green': return const Color(0xFF10B981);
      case 'red': return const Color(0xFFEF4444);
      case 'orange': return const Color(0xFFF59E0B);
      case 'blue': return const Color(0xFF3B82F6);
      default: return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present': return 'Đã ĐD';
      case 'absent': return 'Vắng';
      case 'late': return 'Muộn';
      case 'excused': return 'Có phép';
      case 'pending': return 'Chưa ĐD';
      case 'unmarked': return 'Chưa ĐD';
      default: return status.isEmpty ? '—' : status;
    }
  }

  Color _statusColorFromStatus(String status) {
    switch (status) {
      case 'present': return const Color(0xFF10B981);
      case 'absent': return const Color(0xFFEF4444);
      case 'late': return const Color(0xFFF59E0B);
      case 'excused': return const Color(0xFF3B82F6);
      case 'pending': return const Color(0xFFF59E0B);
      case 'unmarked': return const Color(0xFF6B7280);
      default: return const Color(0xFF6B7280);
    }
  }
}

// ============ Create Session Dialog ============

class _CreateSessionDialog extends StatefulWidget {
  final List<String> classOptions;
  final List<String> subjectOptions;
  final Map<String, dynamic>? initialSession;

  const _CreateSessionDialog({
    required this.classOptions,
    required this.subjectOptions,
    this.initialSession,
  });

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);

  final _rooms = const ['A101', 'A102', 'A201', 'B101', 'B202', 'C301', 'Hội trường'];

  String? _subject;
  String? _class;
  String? _room;
  String? _teacher;
  int? _teacherId;
  List<String> _localSubjectOptions = [];
  List<String> _teacherOptions = [];
  final Map<String, int> _teacherIds = {};
  bool _isLoadingSubjects = false;
  int _subjectRequestId = 0;

  @override
  void initState() {
    super.initState();
    _localSubjectOptions = widget.subjectOptions;
    
    if (widget.initialSession != null) {
      final s = widget.initialSession!;
      _class = s['class_name']?.toString() ?? '';
      _room = s['room']?.toString();
      _teacher = s['lecturer']?.toString();
      _teacherId = int.tryParse((s['teacher_id'] ?? '').toString());
      
      if (s['session_date'] != null) {
        try { _date = DateTime.parse(s['session_date']); } catch (_) {}
      }
      if (s['start_time'] != null) {
        final pts = s['start_time'].split(':');
        if (pts.length >= 2) _start = TimeOfDay(hour: int.tryParse(pts[0]) ?? 7, minute: int.tryParse(pts[1]) ?? 30);
      }
      if (s['end_time'] != null) {
        final pts = s['end_time'].split(':');
        if (pts.length >= 2) _end = TimeOfDay(hour: int.tryParse(pts[0]) ?? 9, minute: int.tryParse(pts[1]) ?? 30);
      }
      final scode = s['subject_code']?.toString() ?? '';
      final sname = s['subject_name']?.toString() ?? s['session_title']?.toString() ?? '';
      _subject = '$scode - $sname';
    } else {
      _subject = _localSubjectOptions.isNotEmpty ? _localSubjectOptions.first : '';
      _class = widget.classOptions.isNotEmpty ? widget.classOptions.first : '';
      _room = _rooms.first;
    }
    
    _loadSubjectsForClass();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final data = await ApiService.getTeachers();
      if (data is List) {
        final teacherIds = <String, int>{};
        for (final item in data) {
          final id = int.tryParse((item['id'] ?? '').toString());
          final name = (item['full_name'] ?? item['teacher_code'] ?? '').toString().trim();
          final code = (item['teacher_code'] ?? '').toString().trim();
          if (id != null && name.isNotEmpty) teacherIds['$name (#$code)'] = id;
        }
        if (mounted && teacherIds.isNotEmpty) {
          setState(() {
            _teacherIds
              ..clear()
              ..addAll(teacherIds);
            _teacherOptions = teacherIds.keys.toList()..sort();
            if (_teacherId != null) {
              for (final entry in teacherIds.entries) {
                if (entry.value == _teacherId) _teacher = entry.key;
              }
            }
            _teacher ??= _teacherOptions.first;
            _teacherId ??= _teacherIds[_teacher];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSubjectsForClass() async {
    final className = _class?.trim() ?? '';
    final requestId = ++_subjectRequestId;
    if (className.isEmpty) {
      if (mounted) setState(() {
        _localSubjectOptions = [];
        _subject = null;
        _isLoadingSubjects = false;
      });
      return;
    }
    if (mounted) setState(() {
      _isLoadingSubjects = true;
      _localSubjectOptions = [];
    });
    try {
      final allCourses = await ApiService.getCourses(className: className);
      if (allCourses is List) {
        final courses = allCourses.map((e) {
          final code = e['code']?.toString() ?? e['subject_code']?.toString() ?? '';
          final name = e['name']?.toString() ?? e['subject_name']?.toString() ?? '';
          return '$code - $name';
        }).where((s) => s != ' - ').toSet().toList();
        if (mounted && requestId == _subjectRequestId && _class?.trim() == className) {
          setState(() {
            _localSubjectOptions = courses;
            if (!_localSubjectOptions.contains(_subject)) {
              _subject = _localSubjectOptions.isNotEmpty ? _localSubjectOptions.first : null;
            }
            _isLoadingSubjects = false;
          });
        }
      }
    } catch (_) {
      if (mounted && requestId == _subjectRequestId) {
        setState(() {
          _localSubjectOptions = [];
          _subject = null;
          _isLoadingSubjects = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (t == null) return;
    setState(() {
      if (isStart) {
        _start = t;
      } else {
        _end = t;
      }
    });
  }

  String _displaySubject(String s) {
    if (!s.contains(' - ')) return s;
    final parts = s.split(' - ');
    if (parts.length > 1) {
      final name = parts.sublist(1).join(' - ').trim();
      if (name.isNotEmpty) return name;
    }
    return parts.first.trim();
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_available_rounded, color: Color(0xFF3B82F6), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Tạo buổi điểm danh',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),
          _label('Lớp'),
          DropdownButtonFormField<String>(
            value: widget.classOptions.contains(_class) ? _class : null,
            isExpanded: true,
            decoration: _dec('Chọn lớp'),
            items: widget.classOptions
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _class = v;
                _subject = null;
                _localSubjectOptions = [];
              });
              _loadSubjectsForClass();
            },
          ),
          const SizedBox(height: 12),
          _label('Môn học'),
          DropdownButtonFormField<String>(
            value: _localSubjectOptions.contains(_subject) ? _subject : null,
            isExpanded: true,
            decoration: _dec(_isLoadingSubjects
                ? 'Đang tải môn học...'
                : (_localSubjectOptions.isEmpty ? 'Lớp chưa có môn học' : 'Chọn môn học')),
            items: _localSubjectOptions
                .map((s) => DropdownMenuItem(
                      value: s, 
                      child: Text(_displaySubject(s), overflow: TextOverflow.ellipsis)
                    ))
                .toList(),
            onChanged: _isLoadingSubjects || _localSubjectOptions.isEmpty
                ? null
                : (v) => setState(() => _subject = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Ngày'),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Text(
                          '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6B7280)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Phòng'),
                  DropdownButtonFormField<String>(
                    value: _rooms.contains(_room) ? _room : null,
                    isExpanded: true,
                    decoration: _dec('Chọn phòng'),
                    items: _rooms
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _room = v),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Giờ bắt đầu'),
                  InkWell(
                    onTap: () => _pickTime(true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Text(
                          '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6B7280)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Giờ kết thúc'),
                  InkWell(
                    onTap: () => _pickTime(false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Text(
                          '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFF6B7280)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _label('Giảng viên'),
          DropdownButtonFormField<String>(
            value: _teacherOptions.contains(_teacher) ? _teacher : null,
            isExpanded: true,
            decoration: _dec('Chọn giảng viên'),
            items: _teacherOptions
                .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() {
              _teacher = v;
              _teacherId = v == null ? null : _teacherIds[v];
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_subject == null || _class == null || _room == null || _teacherId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn đầy đủ thông tin'), backgroundColor: Color(0xFFEF4444)),
                    );
                    return;
                  }
                  final dateStr = '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
                  Navigator.pop(context, {
                    'subject': _subject,
                    'class_name': _class,
                    'room': _room,
                    'date': dateStr,
                    'start_time': '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
                    'end_time': '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
                    'lecturer': _teacher,
                    'teacher_id': _teacherId,
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tạo buổi học'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ============ Session Detail Sheet ============

class _SessionDetailSheet extends StatefulWidget {
  final Map<String, dynamic> session;
  const _SessionDetailSheet({required this.session});

  @override
  State<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<_SessionDetailSheet> {
  late Map<String, dynamic> _session;
  late List<Map<String, dynamic>> _students;
  String _studentFilter = 'all'; 
  final TextEditingController _searchC = TextEditingController();
  bool _isLoadingStudents = true;

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
    _students = [];
    _loadStudentsForSession();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadStudentsForSession() async {
    final className = (_session['class_name'] ?? '').toString();
    List<Map<String, dynamic>> realStudents = [];
    try {
      final data = await ApiService.getStudents(className: className.isNotEmpty ? className : null);
      if (data is List) {
        realStudents = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    if (realStudents.isEmpty) {
      realStudents = MockDataService.canonicalStudents
          .where((s) => s['class_name'] == className)
          .toList();
    }

    final canon = realStudents.map((s) => {
      'student_id': s['id'] ?? s['student_id'],
      'code': s['student_code'] ?? s['code'] ?? '',
      'name': s['full_name'] ?? s['name'] ?? '',
      'class_name': s['class_name'],
      'status': 'unmarked',
    }).toList();

    try {
      final sessionId = _session['id'];
      if (sessionId != null) {
        final recordsData = await ApiService.getAttendanceRecords(sessionId: sessionId);
        if (recordsData is List) {
           for (final record in recordsData) {
              final studentId = record['student_id'];
              final status = record['status'] ?? 'unmarked';
              final sIndex = canon.indexWhere((s) => s['student_id'] == studentId);
              if (sIndex >= 0) {
                 canon[sIndex]['status'] = status;
              }
           }
        }
      }
    } catch (_) {}

    canon.sort((a, b) {
      int order(String s) {
        switch (s) {
          case 'unmarked': return 0;
          case 'absent': return 1;
          case 'late': return 2;
          case 'excused': return 3;
          default: return 4;
        }
      }
      return order(a['status']?.toString() ?? '').compareTo(order(b['status']?.toString() ?? ''));
    });

    if (!mounted) return;
    setState(() {
      _students = canon;
      _isLoadingStudents = false;
    });
  }

  void _setStatus(int idx, String newStatus) {
    if (idx < 0 || idx >= _students.length) return;
    setState(() {
      _students[idx]['status'] = newStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final students = _students;
    final rawSessionDate = (session['session_date'] ?? session['date'] ?? '').toString();
    final sessionDate = rawSessionDate.length >= 10 ? rawSessionDate.substring(0, 10) : rawSessionDate;
    final sessionDateParts = sessionDate.split('-');
    final sessionDay = sessionDateParts.length == 3 ? sessionDateParts[2] : '--';
    final sessionMonth = sessionDateParts.length == 3 ? 'THG ${int.tryParse(sessionDateParts[1]) ?? sessionDateParts[1]}' : '';
    final displaySessionDate = sessionDateParts.length == 3
        ? '${sessionDateParts[2]}/${sessionDateParts[1]}/${sessionDateParts[0]}'
        : sessionDate;

    int presentActual = students.where((s) => s['status'] == 'present').length;
    int absentActual = students.where((s) => s['status'] == 'absent').length;
    int lateActual = students.where((s) => s['status'] == 'late').length;
    int unmarkedActual = students.where((s) => s['status'] == 'unmarked').length;
    int excusedActual = students.where((s) => s['status'] == 'excused').length;
    
    final totalCount = students.length;
    final presentCount = presentActual;

    final ratio = totalCount > 0
        ? (((presentActual + lateActual) / totalCount) * 100).round()
        : 0;

    // Filter
    final filtered = students.where((s) {
      final okF = _studentFilter == 'all' || s['status'] == _studentFilter;
      final q = _searchC.text.trim().toLowerCase();
      final okS = q.isEmpty ||
          (s['name']?.toString() ?? '').toLowerCase().contains(q) ||
          (s['code']?.toString() ?? '').toLowerCase().contains(q);
      return okF && okS;
    }).toList();

    final serverMarked = int.tryParse(session['present_count']?.toString() ?? '0') ?? 0;
    final localMarked = presentActual + lateActual;
    final isInconsistent = false;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(sessionDay, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            Text(sessionMonth, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 9, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session['session_title']?.toString() ?? session['subject_name']?.toString() ?? 'Buổi điểm danh',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                displaySessionDate,
                                if (session['start_time'] != null && session['end_time'] != null)
                                  '${session['start_time']} - ${session['end_time']}',
                              ].where((value) => value.isNotEmpty).join(' • '),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
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
            // Banner cảnh báo mâu thuẫn
            if (isInconsistent)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dữ liệu không đồng bộ: server báo $serverMarked ĐD, danh sách thực tế $localMarked. Hãy cập nhật lại.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            // Stats — đồng bộ từ danh sách thực
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  _statBox('Có mặt', '$presentActual', const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _statBox('Vắng', '$absentActual', const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  _statBox('Muộn', '$lateActual', const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _statBox('Tỷ lệ', '$ratio%', const Color(0xFF3B82F6)),
                ],
              ),
            ),
            // Banner cảnh báo SV chưa điểm danh
            if (unmarkedActual > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.priority_high_rounded, color: Color(0xFFB91C1C), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Còn $unmarkedActual SV chưa điểm danh (trong tổng $totalCount SV lớp)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  Expanded(child: _infoLine(Icons.class_rounded, 'Lớp', session['class_name']?.toString() ?? '')),
                  Expanded(child: _infoLine(Icons.room_rounded, 'Phòng', session['room']?.toString() ?? '')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _infoLine(Icons.person_rounded, 'Giảng viên', session['lecturer']?.toString() ?? ''),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            // Filter chips + search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchC,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên / mã SV',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF6B7280)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ]),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                children: [
                  _filterChip2('all', 'Tất cả (${students.length})'),
                  _filterChip2('present', 'Có mặt ($presentActual)', const Color(0xFF10B981)),
                  _filterChip2('absent', 'Vắng ($absentActual)', const Color(0xFFEF4444)),
                  _filterChip2('late', 'Muộn ($lateActual)', const Color(0xFFF59E0B)),
                  _filterChip2('excused', 'Có phép ($excusedActual)', const Color(0xFF3B82F6)),
                  _filterChip2('unmarked', 'Chưa ĐD ($unmarkedActual)', const Color(0xFF6B7280)),
                ],
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Text('Danh sách điểm danh',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${students.length}/$totalCount SV',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingStudents
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            students.isEmpty
                                ? 'Chưa có SV nào'
                                : 'Không có SV nào khớp bộ lọc',
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                        )
                      : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        final st = s['status']?.toString() ?? '';
                        final realIdx = students.indexOf(s);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: st == 'unmarked'
                                ? const Color(0xFFFFFBEB)
                                : (st == 'absent' ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: st == 'unmarked'
                                  ? const Color(0xFFFCD34D)
                                  : (st == 'absent' ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _avatarColor(realIdx >= 0 ? realIdx : i),
                              child: Text(
                                (s['name'] as String).substring(0, 1),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['name']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                                  Text(s['code']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                            _statusBadge(st),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF6B7280)),
                              tooltip: 'Đổi trạng thái',
                              onSelected: (v) => _setStatus(realIdx, v),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'present', child: Text('Có mặt')),
                                PopupMenuItem(value: 'late', child: Text('Muộn')),
                                PopupMenuItem(value: 'absent', child: Text('Vắng')),
                                PopupMenuItem(value: 'unmarked', child: Text('Chưa ĐD')),
                              ],
                            ),
                          ]),
                        );
                      },
                    ),
            ),
            // Footer buttons
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
                            const SnackBar(content: Text('Đã xuất danh sách điểm danh'), backgroundColor: Color(0xFF10B981)),
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Xuất Excel'),
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
                        onPressed: () async {
                          // Lưu danh sách điểm danh lên server.
                          try {
                            final records = students.map((s) => {
                              'student_id': s['id'] ?? s['student_id'],
                              'status': s['status'] ?? 'unmarked',
                              'note': s['note'] ?? ''
                            }).toList();
                            
                            await ApiService.addAttendanceRecordsBulk({
                              'sessionId': _session['id'],
                              'records': records,
                            });
                            
                            if (!mounted) return;
                            setState(() {
                              _session['present_count'] = presentActual;
                              _session['absent_count'] = absentActual;
                              _session['late_count'] = lateActual;
                              _session['excused_count'] = excusedActual;
                              _session['unmarked_count'] = unmarkedActual;
                              _session['total_count'] = totalCount;
                              _session['status'] = unmarkedActual > 0
                                  ? 'pending'
                                  : (absentActual > totalCount / 2 ? 'absent' : 'present');
                            });
                            Navigator.pop(context, _session);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã lưu buổi điểm danh'), backgroundColor: Color(0xFF10B981)),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi lưu buổi điểm danh: $e'), backgroundColor: const Color(0xFFEF4444)),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: const Text('Lưu buổi điểm danh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
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

  Widget _filterChip2(String value, String label, [Color? color]) {
    final selected = _studentFilter == value;
    final c = color ?? const Color(0xFF14B8A6);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _studentFilter = value),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700, fontSize: 11),
        selectedColor: c,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? c : const Color(0xFFE5E7EB)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'present':
        color = const Color(0xFF10B981);
        label = 'Có mặt';
        break;
      case 'absent':
        color = const Color(0xFFEF4444);
        label = 'Vắng';
        break;
      case 'late':
        color = const Color(0xFFF59E0B);
        label = 'Muộn';
        break;
      case 'unmarked':
        color = const Color(0xFF6B7280);
        label = 'Chưa ĐD';
        break;
      default:
        color = const Color(0xFF6B7280);
        label = '—';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: status == 'unmarked' ? Border.all(color: color.withValues(alpha: 0.4), style: BorderStyle.solid) : null,
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF111827), fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _avatarColor(int i) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ];
    return colors[i % colors.length];
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabHeaderDelegate(this.tabBar);

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) => false;
}
