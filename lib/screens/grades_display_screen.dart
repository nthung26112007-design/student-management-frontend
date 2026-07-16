import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Màn hình xem điểm của sinh viên (chỉ đọc).
/// Dùng cho student xem kết quả học tập.
class GradesDisplayScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const GradesDisplayScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<GradesDisplayScreen> createState() => _GradesDisplayScreenState();
}

class _GradesDisplayScreenState extends State<GradesDisplayScreen> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  List<String> _semesterOptions = [];
  String _selectedSemester = '';
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    List<String> semesters = [''];
    try {
      final profile = await ApiService.getMyProfile();
      final className = (profile['class_name'] ?? '').toString().trim();
      final data = await ApiService.getSemesters(className: className.isEmpty ? null : className);
      semesters.addAll(data
          .map((semester) => (semester['name'] ?? semester['semester_name'] ?? '').toString())
          .where((name) => name.isNotEmpty));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _semesterOptions = semesters.toSet().toList();
      _selectedSemester = '';
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getGrades(studentId: widget.studentId);
      final rows = data.map((item) {
        final row = Map<String, dynamic>.from(item);
        for (final key in ['cc_score', 'qkt_score', 'ckt_score', 'total_score']) {
          if (row[key] != null) row[key] = double.tryParse(row[key].toString());
        }
        row['semester_id'] = row['resolved_semester_id'] ?? row['semester_id'];
        row['semester_name'] = row['semester_name'] ?? 'Học kỳ ${row['semester_id'] ?? ''}';
        return row;
      }).toList();
      final graded = rows.where((row) => row['total_score'] != null).toList();
      final total = graded.length;
      final passed = graded.where((row) => row['status'] == 'pass' || (row['total_score'] as double) >= 4).length;
      final average = total == 0
          ? 0.0
          : graded.fold<double>(0, (sum, row) => sum + (row['total_score'] as double)) / total;
      final stats = {'total': total, 'passed': passed, 'average': average};
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _stats = stats;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSemesterChanged(String? value) {
    if (value == null) return;
    setState(() => _selectedSemester = value);
    _loadData();
  }

  int get _totalPages => (_filteredRows.length / _pageSize).ceil().clamp(1, 999);

  List<Map<String, dynamic>> get _filteredRows {
    if (_selectedSemester.isEmpty || _selectedSemester == '') return _rows;
    return _rows.where((r) {
      final sem = r['semester_name']?.toString() ?? '';
      return sem == _selectedSemester;
    }).toList();
  }

  List<Map<String, dynamic>> get _pagedRows {
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredRows.length);
    if (start >= _filteredRows.length) return [];
    return _filteredRows.sublist(start, end);
  }

  // ============ Stats ============

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  // ============ Grade cell ============

  Widget _buildGradeCell(String? score, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        score ?? '-',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  Color _gradeColor(String? grade) {
    switch (grade) {
      case 'A': return Colors.green;
      case 'B': return Colors.blue;
      case 'C': return Colors.orange;
      case 'D': return Colors.deepOrange;
      case 'F': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _gradeBg(String? grade) {
    switch (grade) {
      case 'A': return Colors.green;
      case 'B': return Colors.blue;
      case 'C': return Colors.orange;
      case 'D': return Colors.deepOrange;
      case 'F': return Colors.red;
      default: return Colors.grey;
    }
  }

  // ============ Build ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(),
            const SizedBox(height: 16),
            _buildStatCards(),
            const SizedBox(height: 20),
            _buildFilterBar(),
            const SizedBox(height: 16),
            _buildTable(),
            if (_totalPages > 1) ...[
              const SizedBox(height: 16),
              _buildPagination(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Kết quả học tập',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Xin chào ${widget.studentName}! Đây là kết quả học tập của bạn.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    final total = _stats['total'] ?? 0;
    final avg = _stats['average'] ?? 0.0;
    final passed = _stats['passed'] ?? 0;
    final rate = total > 0 ? (passed / total * 100) : 0.0;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth >= 700
          ? (c.maxWidth - 24) / 4
          : c.maxWidth;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(width: w, child: _buildStatCard('Tổng môn', '$total', Colors.blue, Icons.book_rounded)),
          SizedBox(width: w, child: _buildStatCard('Điểm TB', avg.toStringAsFixed(2), Colors.purple, Icons.analytics_rounded)),
          SizedBox(width: w, child: _buildStatCard('Môn đạt', '$passed', Colors.green, Icons.check_circle_rounded)),
          SizedBox(width: w, child: _buildStatCard('Tỷ lệ đạt', '${rate.toStringAsFixed(1)}%', Colors.orange, Icons.percent_rounded)),
        ],
      );
    });
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: Color(0xFF6B7280), size: 18),
          const SizedBox(width: 8),
          const Text('Lọc theo học kỳ:', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSemesterDropdown(),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterDropdown() {
    final uniqueSemesters = _semesterOptions.toSet().toList();
    final safeSemesters = uniqueSemesters.isEmpty ? [''] : uniqueSemesters;
    final safeValue = safeSemesters.contains(_selectedSemester) ? _selectedSemester : (safeSemesters.isNotEmpty ? safeSemesters.first : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
          items: safeSemesters
              .map((s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(
                      s.isEmpty ? 'Tất cả học kỳ' : s,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: _onSemesterChanged,
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_isLoading) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_pagedRows.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, size: 48, color: Color(0xFF9CA3AF)),
              SizedBox(height: 12),
              Text('Không có dữ liệu điểm.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('STT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                SizedBox(width: 8),
                Expanded(flex: 3, child: Text('Môn học', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 2, child: Text('Học kỳ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                SizedBox(width: 60, child: Text('CC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                SizedBox(width: 8),
                SizedBox(width: 60, child: Text('QT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                SizedBox(width: 8),
                SizedBox(width: 60, child: Text('CK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                SizedBox(width: 8),
                SizedBox(width: 60, child: Text('Tổng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                SizedBox(width: 8),
                SizedBox(width: 60, child: Text('Loại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                SizedBox(width: 8),
                SizedBox(width: 70, child: Text('Trạng thái', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Table rows
          ...List.generate(_pagedRows.length, (index) {
            final row = _pagedRows[index];
            final grade = row['grade']?.toString();
            final status = row['status']?.toString();
            final isPass = status == 'pass';
            final bgColor = index.isEven ? Colors.white : const Color(0xFFF9FAFB);
            final rowIndex = (_currentPage - 1) * _pageSize + index + 1;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('$rowIndex', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                  SizedBox(width: 8),
                  Expanded(flex: 3, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['subject_name'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        row['subject_code'] ?? '',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  )),
                  Expanded(flex: 2, child: Text(row['semester_name'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), textAlign: TextAlign.center)),
                  SizedBox(width: 8),
                  SizedBox(width: 60, child: Center(child: _buildGradeCell(row['cc_score']?.toString(), Colors.blue, Colors.blue))),
                  SizedBox(width: 8),
                  SizedBox(width: 60, child: Center(child: _buildGradeCell(row['qkt_score']?.toString(), Colors.purple, Colors.purple))),
                  SizedBox(width: 8),
                  SizedBox(width: 60, child: Center(child: _buildGradeCell(row['ckt_score']?.toString(), Colors.orange, Colors.orange))),
                  SizedBox(width: 8),
                  SizedBox(width: 60, child: Center(child: _buildGradeCell(row['total_score']?.toStringAsFixed(1), Colors.teal, Colors.teal))),
                  SizedBox(width: 8),
                  SizedBox(width: 60, child: Center(child: _buildGradeCell(grade, _gradeColor(grade), _gradeColor(grade)))),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPass ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPass ? 'Đạt' : 'Không đạt',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPass ? Colors.green : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: const Color(0xFF6B7280),
        ),
        ...List.generate(_totalPages.clamp(0, 5), (i) {
          final page = i + 1;
          return GestureDetector(
            onTap: () => setState(() => _currentPage = page),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _currentPage == page ? const Color(0xFF1E3A5F) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _currentPage == page ? const Color(0xFF1E3A5F) : Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  '$page',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _currentPage == page ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: const Color(0xFF6B7280),
        ),
      ],
    );
  }
}
