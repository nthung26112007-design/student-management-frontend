import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';

/// Màn hình điểm cá nhân của student.
/// Chỉ hiển thị điểm của student đang đăng nhập.
class MyGradesScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const MyGradesScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<MyGradesScreen> createState() => _MyGradesScreenState();
}

class _MyGradesScreenState extends State<MyGradesScreen> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  // Filter: theo học kỳ & môn
  List<String> _semesterOptions = [];
  String _selectedSemester = '';
  List<String> _subjectOptions = [];
  String _selectedSubject = '';

  // Map học kỳ → danh sách môn (đồng bộ với curriculum)
  static const Map<String, List<String>> _subjectsBySemester = {
    'Học kỳ 1 - 2024-2025': ['IT001 - Lập trình cơ bản', 'IT002 - Cơ sở dữ liệu'],
    'Học kỳ 2 - 2024-2025': ['IT003 - Cấu trúc dữ liệu & Giải thuật', 'IT004 - Lập trình Web'],
    'Học kỳ 1 - 2025-2026': ['IT005 - Mạng máy tính', 'IT006 - Trí tuệ nhân tạo'],
  };

  List<String> get _filteredSubjectOptions {
    if (_selectedSemester.isEmpty) return _subjectOptions;
    return _subjectsBySemester[_selectedSemester] ?? _subjectOptions;
  }

  @override
  void initState() {
    super.initState();
    _loadFilters().then((_) => _loadData());
  }

  Future<void> _loadFilters() async {
    List<String> semesters;
    try {
      semesters = await MockDataService.getGradeBookSemesters();
    } catch (_) {
      semesters = [];
    }

    if (!mounted) return;
    setState(() {
      _semesterOptions = semesters;
      // Bỏ qua '' ở đầu — chọn học kỳ đầu tiên thực sự
      _selectedSemester = semesters.isNotEmpty && semesters.first.isNotEmpty
          ? semesters.first
          : (semesters.length > 1 ? semesters[1] : '');
      _subjectOptions = [];
      _selectedSubject = '';
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Map tên học kỳ → id (bỏ qua '' ở đầu)
      int? semesterId;
      if (_selectedSemester.isNotEmpty) {
        final idx = _semesterOptions.indexOf(_selectedSemester);
        // indexOf trả về vị trí trong _semesterOptions (bắt đầu từ 0 với '')
        // canonicalSemesters[0] tương ứng với _semesterOptions[1] vì có '' ở index 0
        final canonicalIdx = idx - 1;
        if (canonicalIdx >= 0 && canonicalIdx < canonicalSemesters.length) {
          semesterId = canonicalSemesters[canonicalIdx]['semester_id'] as int;
        }
      }

      final rows = await MockDataService.getGradeBook(
        studentId: widget.studentId,
        semesterId: semesterId,
        subjectCode: _selectedSubject.isNotEmpty ? _selectedSubject.split(' - ').first : null,
      );
      final stats = await MockDataService.getGradeBookStats(fromRows: rows);

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _stats = stats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildStatCards(),
            const SizedBox(height: 20),
            _buildFilterRow(),
            const SizedBox(height: 20),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: Color(0xFF6366F1), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kết quả học tập',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
              ),
              Text(
                widget.studentName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    final total = _stats['total_records'] ?? 0;
    final avg = (_stats['average_score'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final passRate = (_stats['pass_rate'] as num?)?.toStringAsFixed(1) ?? '0.0';
    final passCount = _stats['pass_count'] ?? 0;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cardW = w >= 600 ? (w - 36) / 4 : (w - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(width: cardW, child: _statCard('Tổng môn', '$total', Icons.format_list_numbered_rounded, const Color(0xFF3B82F6))),
          SizedBox(width: cardW, child: _statCard('Điểm TB', avg, Icons.analytics_rounded, const Color(0xFFF59E0B))),
          SizedBox(width: cardW, child: _statCard('Đạt', '$passCount', Icons.check_circle_rounded, const Color(0xFF10B981))),
          SizedBox(width: cardW, child: _statCard('Tỷ lệ đạt', '$passRate%', Icons.pie_chart_rounded, const Color(0xFF6366F1))),
        ],
      );
    });
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    // Safe values — luôn non-null, luôn có ít nhất 1 item
    final semItems = _semesterOptions.isEmpty ? ['—'] : _semesterOptions;
    final semValue = semItems.contains(_selectedSemester) ? _selectedSemester : (semItems.isNotEmpty ? semItems.first : '');
    final subjItems = _subjectOptions.isEmpty ? ['—'] : _subjectOptions;
    final subjValue = subjItems.contains(_selectedSubject) ? _selectedSubject : (subjItems.isNotEmpty ? subjItems.first : '');

    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth >= 500;
      final filteredSubj = _filteredSubjectOptions;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
            child: _filterDropdown(
              icon: Icons.calendar_month_rounded,
              hint: 'Chọn học kỳ',
              value: semValue,
              items: semItems,
              onChanged: (v) {
                if (v != null && v != _selectedSemester) {
                  setState(() {
                    _selectedSemester = v;
                    // Reset subject khi đổi học kỳ để tránh giá trị không còn trong dropdown
                    _selectedSubject = '';
                  });
                  _loadData();
                }
              },
            ),
          ),
          SizedBox(
            width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
            child: _filterDropdown(
              icon: Icons.menu_book_rounded,
              hint: 'Tất cả môn',
              value: filteredSubj.contains(_selectedSubject) ? _selectedSubject : '',
              items: filteredSubj.isEmpty ? ['—'] : filteredSubj,
              onChanged: (v) {
                if (v != null && v != _selectedSubject) {
                  setState(() => _selectedSubject = v);
                  _loadData();
                }
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _filterDropdown({
    required IconData icon,
    required String hint,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Loại bỏ trùng lặp bằng Set để tránh lỗi "exactly one item with value"
    final uniqueItems = items.toSet().toList();
    final safeItems = uniqueItems.isEmpty ? ['—'] : uniqueItems;
    final safeValue = safeItems.contains(value) ? value : (safeItems.isNotEmpty ? safeItems.first : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                hint: Text(hint, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                items: safeItems.map((it) => DropdownMenuItem<String>(
                  value: it,
                  child: Text(it, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(60),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải điểm...', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    if (_rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text('Chưa có dữ liệu điểm', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Môn học', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
                Expanded(child: Text('CC', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
                Expanded(child: Text('QK', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
                Expanded(child: Text('CK', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
                Expanded(child: Text('Tổng', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
                Expanded(child: Text('Xếp loại', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
                Expanded(child: Text('Trạng thái', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
              ],
            ),
          ),
          // Rows
          ..._rows.map((r) => _buildRow(r)),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final total = (r['total_score'] as num).toDouble();
    final status = r['status'] as String;
    final grade = r['grade'] as String;
    final gradeColor = _gradeColor(grade);
    final statusColor = status == 'pass' ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusLabel = status == 'pass' ? 'Đạt' : 'Không đạt';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['subject_name'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  r['subject_code'] as String,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          Expanded(child: _scoreCell(r['cc_score'], const Color(0xFF3B82F6))),
          Expanded(child: _scoreCell(r['qkt_score'], const Color(0xFFF59E0B))),
          Expanded(child: _scoreCell(r['ckt_score'], const Color(0xFFEF4444))),
          Expanded(child: _scoreCell(total.toStringAsFixed(1), const Color(0xFF1F2937), bold: true)),
          Expanded(child: Center(child: _gradeBadge(grade, gradeColor))),
          Expanded(child: Center(child: _statusBadge(statusLabel, statusColor))),
        ],
      ),
    );
  }

  Widget _scoreCell(dynamic score, Color color, {bool bold = false}) {
    return Text(
      score.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        color: color,
      ),
    );
  }

  Widget _gradeBadge(String grade, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(grade, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'A': return const Color(0xFF10B981);
      case 'B': return const Color(0xFF3B82F6);
      case 'C': return const Color(0xFFF59E0B);
      case 'D': return const Color(0xFFF97316);
      default:  return const Color(0xFFEF4444);
    }
  }
}
