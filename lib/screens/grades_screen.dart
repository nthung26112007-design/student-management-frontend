import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import '../services/api_service.dart';
class GradesScreen extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  final String? role;

  const GradesScreen({
    super.key,
    this.studentId,
    this.studentName,
    this.role,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool get _canEditGrades => widget.role == 'admin' || widget.role == 'teacher';
  bool get _canDeleteGrades => widget.role == 'admin';
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _apiStudents = [];
  List<String> _classOptions = [];
  List<String> _semesterOptions = [];
  List<String> _subjectOptions = [];

  String? _selectedClass;
  String? _selectedSemester;
  String? _selectedSubject;
  final TextEditingController _searchController = TextEditingController();
  // Map từ semester name → semester_id để truyền thật vào service
  final Map<String, int> _semesterIdMap = {};

  bool _isLoading = true;
  int _currentPage = 1;
  static const int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFilters().then((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    List<String> classes = [];
    
    try {
      final studentsData = await ApiService.getStudents();
      if (studentsData is List) {
        _apiStudents = studentsData.map((e) => Map<String, dynamic>.from(e)).toList();
        classes = _apiStudents
            .map((e) => (e['class_name'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        classes.sort();
      }
    } catch (_) {}

    // Fallbacks
    if (classes.isEmpty) {
      classes = await MockDataService.getGradeBookClasses();
    }
    classes = ['', ...classes.where((c) => c.isNotEmpty)];

    if (!mounted) return;
    setState(() {
      _classOptions = classes;
      _selectedClass = null;
    });

    await _reloadSubjectsAndLoad();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Map tên học kỳ đang chọn (nếu có) → id thật
      int? semesterId;
      if (_selectedSemester != null && _semesterIdMap.containsKey(_selectedSemester)) {
        semesterId = _semesterIdMap[_selectedSemester];
      }
      final rows = await MockDataService.getGradeBook(
        className: (_selectedClass == null || _selectedClass!.isEmpty) ? null : _selectedClass,
        semesterId: semesterId,
        subjectCode: _selectedSubject?.split(' - ').first,
        search: _searchController.text,
        fromStudents: _apiStudents.isNotEmpty ? _apiStudents : null,
      );
      // Stats tính từ chính rows vừa load (không dùng số cứng)
      final stats = await MockDataService.getGradeBookStats(fromRows: rows);
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

  void _onSearchChanged() {
    _loadData();
  }

  Future<void> _reloadSubjectsAndLoad() async {
    // 1. Reload semesters based on _selectedClass
    List<String> semesters = [];
    _semesterIdMap.clear();
    try {
      final semesterData = await ApiService.getSemesters(
        className: (_selectedClass == null || _selectedClass!.isEmpty) ? null : _selectedClass,
      );
      if (semesterData is List) {
        for (final sem in semesterData) {
           final name = sem['name'] ?? sem['semester_name'] ?? '';
           final id = sem['id'];
           if (name.isNotEmpty && id != null) {
              semesters.add(name);
              _semesterIdMap[name] = id;
           }
        }
      }
    } catch (_) {}
    
    if (semesters.isEmpty) {
      semesters = await MockDataService.getGradeBookSemesters();
      for (var m in MockDataService.canonicalSemesters) {
        _semesterIdMap[m['semester_name'] as String] = m['semester_id'] as int;
      }
    }
    semesters = ['', ...semesters.where((s) => s.isNotEmpty).toSet()];

    // null luôn có nghĩa là "Tất cả kỳ học"; không tự chọn kỳ đầu tiên.
    if (_selectedSemester != null && !_semesterIdMap.containsKey(_selectedSemester) && _selectedSemester != '') {
       _selectedSemester = null;
    }

    int? semesterId;
    if (_selectedSemester != null && _semesterIdMap.containsKey(_selectedSemester)) {
      semesterId = _semesterIdMap[_selectedSemester];
    }
    
    // 2. Reload subjects
    List<String> subjects = [];
    try {
       final courseData = await ApiService.getCourses(
         className: (_selectedClass == null || _selectedClass!.isEmpty) ? null : _selectedClass,
         semesterId: semesterId,
       );
       if (courseData is List) {
          subjects = courseData.map((e) {
            final code = e['code'] ?? e['subject_code'] ?? '';
            final name = e['name'] ?? e['subject_name'] ?? '';
            return '$code - $name'.trim();
          }).where((s) => s != '-').toSet().toList();
          subjects.sort();
       }
    } catch (_) {}
    
    if (subjects.isEmpty) {
      subjects = await MockDataService.getGradeBookFilteredSubjects(
        className: (_selectedClass == null || _selectedClass!.isEmpty) ? null : _selectedClass,
        semesterId: semesterId,
      );
    }
    subjects = ['', ...subjects.where((s) => s.isNotEmpty).toSet()];

    if (!mounted) return;
    setState(() {
      _semesterOptions = semesters;
      _subjectOptions = subjects;
      if (_selectedSubject != null && !subjects.contains(_selectedSubject)) {
        _selectedSubject = null;
      }
    });
    _loadData();
  }

  // ============ Pagination ============

  int get _totalPages => (_rows.length / _pageSize).ceil().clamp(1, 999);

  List<Map<String, dynamic>> get _pagedRows {
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _rows.length);
    if (start >= _rows.length) return [];
    return _rows.sublist(start, end);
  }

  // ============ Build ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(),
            const SizedBox(height: 16),
            _buildStatCards(),
            const SizedBox(height: 20),
            _buildFilterRow(),
            const SizedBox(height: 20),
            _buildTable(),
            const SizedBox(height: 16),
            _buildPagination(),
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
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Quản lý điểm',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Theo dõi và cập nhật bảng điểm sinh viên',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        if (_canEditGrades) Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFB923C)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showAddGradeDialog(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Thêm bảng điểm',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cross = w >= 1100 ? 4 : (w >= 700 ? 2 : 1);
      final aspect = w >= 1100 ? 2.8 : (w >= 700 ? 3.0 : 3.4);
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          childAspectRatio: aspect,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        children: [
          _statCard('Tổng bảng điểm', '${_stats['total_records'] ?? 0}',
              'tổng số', Icons.assessment_rounded, const Color(0xFFF59E0B)),
          _statCard('Điểm TB',
              (_stats['average_score'] as num?)?.toStringAsFixed(1) ?? '0.0',
              'hệ 10', Icons.star_rounded, const Color(0xFF10B981)),
          _statCard('Đạt',
              '${(((_stats['pass_rate'] as num?) ?? 0) / 100 * ((_stats['total_records'] as num?) ?? 1)).toStringAsFixed(0)}',
              '${_stats['pass_rate'] ?? 0}%', Icons.check_circle_rounded,
              const Color(0xFF3B82F6)),
          _statCard('Không đạt', '${_stats['fail_count'] ?? 0}', 'môn',
              Icons.cancel_rounded, const Color(0xFFEF4444)),
        ],
      );
    });
  }

  Widget _statCard(String label, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        )),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(sub,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _filteredSubjectOptions {
    return _subjectOptions;
  }

  // ============ Filter row ============

  Widget _buildFilterRow() {
    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth >= 700;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(width: isWide ? (c.maxWidth - 36) / 4 : c.maxWidth, child: _filterDropdown(
            icon: Icons.school_rounded,
            hint: 'Tất cả lớp',
            value: _selectedClass,
            items: _classOptions,
            onChanged: (v) {
              setState(() {
                _selectedClass = v;
                _selectedSubject = null;
              });
              _reloadSubjectsAndLoad();
            },
          )),
          SizedBox(width: isWide ? (c.maxWidth - 36) / 4 : c.maxWidth, child: _filterDropdown(
            icon: Icons.calendar_month_rounded,
            hint: 'Tất cả kỳ học',
            value: _selectedSemester,
            items: _semesterOptions,
            onChanged: (v) {
              setState(() {
                _selectedSemester = v;
                _selectedSubject = null;
              });
              _reloadSubjectsAndLoad();
            },
          )),
          SizedBox(width: isWide ? (c.maxWidth - 36) / 4 : c.maxWidth, child: _filterDropdown(
            icon: Icons.menu_book_rounded,
            hint: 'Tất cả môn học',
            value: _selectedSubject,
            items: _filteredSubjectOptions,
            onChanged: (v) { setState(() => _selectedSubject = v); _loadData(); },
          )),
          SizedBox(width: isWide ? (c.maxWidth - 36) / 4 : c.maxWidth, child: _searchField()),
        ],
      );
    });
  }

  Widget _filterDropdown({
    required IconData icon,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Loại bỏ trùng lặp để tránh lỗi "exactly one item with value"
    final uniqueItems = items.toSet().toList();
    // Đảm bảo value luôn nằm trong items (tránh DropdownButton crash).
    final safeItems = uniqueItems.isEmpty ? [''] : uniqueItems;
    final safeValue = (value != null && safeItems.contains(value)) ? value : (safeItems.isNotEmpty ? safeItems.first : null);
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
                items: safeItems
                    .map((it) => DropdownMenuItem<String>(
                          value: it,
                          child: Text(it.isEmpty ? hint : it, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => onChanged(v == '' ? null : v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
          hintText: 'Tìm kiếm theo tên, mã SV, môn học...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                  onPressed: () { _searchController.clear(); _loadData(); },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          LayoutBuilder(builder: (ctx, c) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _tableHeaderRow(),
            );
          }),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text('Không có dữ liệu', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._pagedRows.asMap().entries.map((e) {
              final idx = e.key;
              final row = e.value;
              return Column(
                children: [
                  if (idx > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _tableDataRow(row),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _tableHeaderRow() {
    return const Row(
      children: [
        _Hdr(label: 'Mã SV', w: 80),
        _Hdr(label: 'Họ tên', w: null, flex: 2),
        _Hdr(label: 'Lớp', w: 80),
        _Hdr(label: 'Môn học', w: null, flex: 2),
        _Hdr(label: 'CC(10%)', w: 60, align: TextAlign.center),
        _Hdr(label: 'QK(30%)', w: 60, align: TextAlign.center),
        _Hdr(label: 'CK(60%)', w: 60, align: TextAlign.center),
        _Hdr(label: 'Tổng', w: 60, align: TextAlign.center),
        _Hdr(label: 'Xếp loại', w: 70, align: TextAlign.center),
        _Hdr(label: 'Kết quả', w: 80, align: TextAlign.center),
        _Hdr(label: '', w: 80, align: TextAlign.center),
      ],
    );
  }

  Widget _tableDataRow(Map<String, dynamic> r) {
    final pass = r['status'] == 'pass';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text((r['student_code'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF111827))),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (r['full_name'] ?? '').toString().isNotEmpty
                        ? (r['full_name'] as String).substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text((r['full_name'] ?? '').toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827))),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text((r['class_name'] ?? '').toString(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((r['subject_name'] ?? '').toString(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                Text((r['subject_code'] ?? '').toString(),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          _scoreCell(r['cc_score']),
          _scoreCell(r['qkt_score']),
          _scoreCell(r['ckt_score']),
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                r['total_score']?.toString() ?? '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: (r['total_score'] != null) ? (pass ? const Color(0xFF15803D) : const Color(0xFFB91C1C)) : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r['grade'] != null ? _gradeBg(r['grade'] as String) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r['grade']?.toString() ?? '—',
                  style: TextStyle(
                    color: r['grade'] != null ? _gradeFg(r['grade'] as String) : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(pass ? 'Đạt' : 'Không đạt',
                    style: TextStyle(
                      color: pass ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    )),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iconAction(Icons.visibility_rounded, const Color(0xFF3B82F6),
                      () => _showRowDetail(r)),
                  if (_canEditGrades) ...[
                    const SizedBox(width: 6),
                    _iconAction(Icons.edit_rounded, const Color(0xFFF59E0B), () => _showEditDialog(r)),
                  ],
                  if (_canDeleteGrades) ...[
                    const SizedBox(width: 6),
                    _iconAction(Icons.delete_rounded, const Color(0xFFEF4444), () => _confirmDelete(r)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCell(dynamic v) {
    if (v == null || v.toString() == 'null') {
      return const SizedBox(
        width: 60,
        child: Center(
          child: Text('—', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF9CA3AF))),
        ),
      );
    }
    final i = double.tryParse(v.toString()) ?? 0;
    return SizedBox(
      width: 60,
      child: Center(
        child: Text(v.toString(), style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: i >= 5 ? const Color(0xFF111827) : const Color(0xFFB91C1C),
        )),
      ),
    );
  }

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }

  Widget _buildPagination() {
    if (_rows.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (ctx, c) {
      final isWide = c.maxWidth >= 600;
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          Text(
            'Hiển thị ${(_currentPage - 1) * _pageSize + 1}-${(_currentPage * _pageSize).clamp(0, _rows.length)} / ${_rows.length} bản ghi',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageBtn(Icons.chevron_left_rounded, _currentPage > 1, () {
                setState(() => _currentPage = (_currentPage - 1).clamp(1, _totalPages));
              }),
              const SizedBox(width: 4),
              for (int i = 1; i <= _totalPages && i <= 5; i++) ...[
                _pageNumber(i),
                const SizedBox(width: 4),
              ],
              if (isWide) const Text('...', style: TextStyle(color: Color(0xFF6B7280))),
              if (isWide) ...[
                const SizedBox(width: 4),
                _pageNumber(_totalPages),
                const SizedBox(width: 4),
              ],
              _pageBtn(Icons.chevron_right_rounded, _currentPage < _totalPages, () {
                setState(() => _currentPage = (_currentPage + 1).clamp(1, _totalPages));
              }),
            ],
          ),
        ],
      );
    });
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: enabled ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB)),
      ),
    );
  }

  Widget _pageNumber(int p) {
    final selected = _currentPage == p;
    return InkWell(
      onTap: () => setState(() => _currentPage = p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF59E0B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? [
            BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
          ] : [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Text('$p',
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF374151),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            )),
      ),
    );
  }

  // ===== Action handlers =====

  void _showAddGradeDialog() async {
    // Lấy danh sách SV của lớp đang chọn để chọn
    final students = _apiStudents.isNotEmpty ? _apiStudents : MockDataService.canonicalStudents;
    final className = (_selectedClass == null || _selectedClass!.isEmpty)
        ? null
        : _selectedClass;
    final filteredStudents = students
        .where((s) => className == null || (s['class_name'] ?? '').toString().trim() == className)
        .toList();

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: _AddGradeDialog(
            classOptions: _classOptions,
            semesterOptions: _semesterOptions,
            subjectOptions: _filteredSubjectOptions,
            semesterIdMap: _semesterIdMap,
            students: filteredStudents,
            // Pre-fill từ filter hiện tại
            initialClass: _selectedClass,
            initialSemester: _selectedSemester,
            initialSubject: _selectedSubject,
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;

    final studentsByCode = {for (final s in students) s['student_code'] as String: s};
    final stu = studentsByCode[result['student_code']];
    final semesterId = _semesterIdMap[result['semester']] ?? 0;
    final subjectCode = (result['subject'] as String? ?? '').split(' - ').first;
    Map<String, dynamic>? matchingRow;
    for (final row in _rows) {
      if (row['subject_code'] == subjectCode &&
          row['semester_id'] == semesterId &&
          row['class_name'] == stu?['class_name']) {
        matchingRow = row;
        break;
      }
    }
    final courseId = matchingRow?['course_id'] as int? ?? 0;
    if (courseId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được môn học trong cơ sở dữ liệu')),
      );
      return;
    }

    await MockDataService.saveGrade(
      studentId: (stu?['id'] ?? stu?['student_id'] ?? 0) as int,
      courseId: courseId,
      semesterId: semesterId,
      subjectCode: subjectCode,
      ccScore: (result['cc_score'] as num?)?.toDouble() ?? 0,
      qktScore: (result['qkt_score'] as num?)?.toDouble() ?? 0,
      cktScore: (result['ckt_score'] as num?)?.toDouble() ?? 0,
      note: result['note'] as String?,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã lưu: ${result['student_code']} - Tổng ${(result['total_score'] as num).toStringAsFixed(2)} • ${result['grade']}',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    await _loadData();
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

  Widget _scoreField(TextEditingController c, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  String _gradeOf(double v) {
    if (v >= 8.5) return 'A';
    if (v >= 7.0) return 'B';
    if (v >= 5.5) return 'C';
    if (v >= 4.0) return 'D';
    return 'F';
  }

  Color _gradeColor(double v) {
    if (v >= 8.5) return const Color(0xFF10B981);
    if (v >= 7.0) return const Color(0xFF3B82F6);
    if (v >= 5.5) return const Color(0xFFF59E0B);
    if (v >= 4.0) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  void _showEditDialog(Map<String, dynamic> r) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: _AddGradeDialog(
            classOptions: _classOptions,
            semesterOptions: _semesterOptions,
            subjectOptions: _filteredSubjectOptions,
            semesterIdMap: _semesterIdMap,
            students: const [],
            initial: r,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;

    final studentId = r['student_id'] as int? ?? 0;
    final semesterId = r['semester_id'] as int? ?? 0;
    final subjectCode = r['subject_code'] as String? ?? '';

    await MockDataService.saveGrade(
      studentId: studentId,
      courseId: r['course_id'] as int? ?? 0,
      semesterId: semesterId,
      subjectCode: subjectCode,
      ccScore: (result['cc_score'] as num?)?.toDouble() ?? 0,
      qktScore: (result['qkt_score'] as num?)?.toDouble() ?? 0,
      cktScore: (result['ckt_score'] as num?)?.toDouble() ?? 0,
      note: result['note'] as String?,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã cập nhật: ${r['student_code']} - Tổng ${(result['total_score'] as num).toStringAsFixed(2)} • ${result['grade']}',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    await _loadData();
  }

  void _showRowDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFB923C)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (r['full_name'] as String).substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['full_name'] as String,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      Text('${r['student_code']} • ${r['class_name']}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _detailRow('Môn học', '${r['subject_name']} (${r['subject_code']})'),
                  _detailRow('Tín chỉ', '${r['credits']}'),
                  _detailRow('Chuyên cần (10%)', '${r['cc_score']}'),
                  _detailRow('Quá trình (30%)', '${r['qkt_score']}'),
                  _detailRow('Cuối kỳ (60%)', '${r['ckt_score']}'),
                  const Divider(),
                  _detailRow('Tổng kết', '${r['total_score']} • ${r['grade']}', highlight: true),
                  _detailRow('Kết quả', (r['status'] == 'pass') ? 'Đạt' : 'Không đạt',
                      color: (r['status'] == 'pass') ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const Spacer(),
          Text(value, style: TextStyle(
            fontSize: highlight ? 16 : 13,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: color ?? const Color(0xFF111827),
          )),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa điểm của ${r['full_name']} - môn ${r['subject_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final studentId = r['student_id'] as int? ?? 0;
              final semesterId = r['semester_id'] as int? ?? 0;
              final subjectCode = r['subject_code'] as String? ?? '';
              await MockDataService.deleteGrade(
                studentId: studentId,
                semesterId: semesterId,
                subjectCode: subjectCode,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa điểm'), backgroundColor: Color(0xFF10B981)),
              );
              await _loadData();
            },
            child: const Text('Xóa', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  // ===== Color helpers =====

  Color _gradeFg(String g) {
    if (g == 'A+' || g == 'A') return const Color(0xFF15803D);
    if (g == 'B+' || g == 'B') return const Color(0xFF2563EB);
    if (g == 'C') return const Color(0xFFD97706);
    return const Color(0xFFB91C1C);
  }

  Color _gradeBg(String g) {
    if (g == 'A+' || g == 'A') return const Color(0xFFDCFCE7);
    if (g == 'B+' || g == 'B') return const Color(0xFFDBEAFE);
    if (g == 'C') return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }
}

class _Hdr extends StatelessWidget {
  final String label;
  final double? w;
  final int? flex;
  final TextAlign align;
  const _Hdr({required this.label, this.w, this.flex, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final child = Text(label,
        textAlign: align,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: Color(0xFF6B7280),
          letterSpacing: 0.3,
        ));
    if (w != null) {
      return SizedBox(width: w, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}

// ============ Add / Edit Grade Dialog ============

class _AddGradeDialog extends StatefulWidget {
  final List<String> classOptions;
  final List<String> semesterOptions;
  final List<String> subjectOptions;
  final Map<String, int> semesterIdMap;
  final List<Map<String, dynamic>> students;
  final String? initialClass;
  final String? initialSemester;
  final String? initialSubject;
  final Map<String, dynamic>? initial;

  const _AddGradeDialog({
    required this.classOptions,
    required this.semesterOptions,
    required this.subjectOptions,
    required this.semesterIdMap,
    required this.students,
    this.initialClass,
    this.initialSemester,
    this.initialSubject,
    this.initial,
  });

  @override
  State<_AddGradeDialog> createState() => _AddGradeDialogState();
}

class _AddGradeDialogState extends State<_AddGradeDialog> {
  final _studentCodeC = TextEditingController();
  final _noteC = TextEditingController();
  final _ccC = TextEditingController();
  final _qktC = TextEditingController();
  final _cktC = TextEditingController();
  String? _selectedStudentCode;
  String? _selectedSubject;
  String? _selectedSemester;

  bool get _isEdit => widget.initial != null;

  static const double _wCC = 0.10;
  static const double _wQK = 0.30;
  static const double _wCK = 0.60;

  double? _cc;
  double? _qkt;
  double? _ckt;
  double? _total;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;

    if (init != null) {
      _studentCodeC.text = (init['student_code'] ?? '').toString();
      _noteC.text = (init['note'] ?? '').toString();
      _ccC.text = _fmtIfNum(init['cc_score']);
      _qktC.text = _fmtIfNum(init['qkt_score']);
      _cktC.text = _fmtIfNum(init['ckt_score']);
      _recalc();

      final sem = (init['semester_name'] ?? init['semester'] ?? '').toString();
      if (widget.semesterOptions.contains(sem)) _selectedSemester = sem;
      final subjRaw = (init['subject_code'] ?? '').toString();
      final subjFull = init['subject_name'] ?? '';
      final subjMatch = widget.subjectOptions.firstWhere(
        (s) => s.startsWith('$subjRaw - '),
        orElse: () => subjRaw.isNotEmpty ? '$subjRaw - $subjFull' : widget.subjectOptions.first,
      );
      if (widget.subjectOptions.contains(subjMatch)) _selectedSubject = subjMatch;
      _selectedStudentCode = _studentCodeC.text;
    } else {
      _selectedSemester ??= widget.initialSemester;
      _selectedSubject ??= widget.initialSubject;
    }

    _ccC.addListener(_recalc);
    _qktC.addListener(_recalc);
    _cktC.addListener(_recalc);
  }

  String _fmtIfNum(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    if (s == 'null') return '';
    return s;
  }

  void _recalc() {
    setState(() {
      _cc = double.tryParse(_ccC.text.trim());
      _qkt = double.tryParse(_qktC.text.trim());
      _ckt = double.tryParse(_cktC.text.trim());
      if (_cc != null && _qkt != null && _ckt != null) {
        _total = _cc! * _wCC + _qkt! * _wQK + _ckt! * _wCK;
      } else {
        _total = null;
      }
    });
  }

  @override
  void dispose() {
    _studentCodeC.dispose();
    _ccC.dispose();
    _qktC.dispose();
    _cktC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Widget _dlgLabel(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
      );

  InputDecoration _dlgDec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _dlgScoreField(TextEditingController c, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  String _dlgGradeOf(double v) {
    if (v >= 8.5) return 'A';
    if (v >= 7.0) return 'B';
    if (v >= 5.5) return 'C';
    if (v >= 4.0) return 'D';
    return 'F';
  }

  Color _dlgGradeColor(double v) {
    if (v >= 8.5) return const Color(0xFF10B981);
    if (v >= 7.0) return const Color(0xFF3B82F6);
    if (v >= 5.5) return const Color(0xFFF59E0B);
    if (v >= 4.0) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final semesterOptions = widget.semesterOptions.where((s) => s.isNotEmpty).toSet().toList();
    final subjectOptions = widget.subjectOptions.where((s) => s.isNotEmpty).toSet().toList();
    final studentsByCode = <String, Map<String, dynamic>>{};
    for (final student in widget.students) {
      final code = (student['student_code'] ?? '').toString();
      if (code.isNotEmpty) studentsByCode[code] = student;
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isEdit ? const Color(0xFFEEF2FF) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isEdit ? Icons.edit_rounded : Icons.add_chart_rounded,
                color: _isEdit ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isEdit ? 'Sửa bảng điểm' : 'Thêm bảng điểm mới',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ]),
          const SizedBox(height: 20),
          _dlgLabel('Sinh viên'),
          if (_isEdit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                const Icon(Icons.person_rounded, size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_studentCodeC.text} — ${widget.initial?['full_name'] ?? ''}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedStudentCode,
              isExpanded: true,
              decoration: _dlgDec('Chọn sinh viên'),
              items: studentsByCode.values.map((s) {
                return DropdownMenuItem(
                  value: s['student_code'] as String,
                  child: Text(
                    '${s['student_code']} — ${s['full_name']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _selectedStudentCode = v);
                _studentCodeC.text = v ?? '';
              },
            ),
          const SizedBox(height: 12),
          _dlgLabel('Học kỳ'),
          DropdownButtonFormField<String>(
            value: _selectedSemester,
            isExpanded: true,
            decoration: _dlgDec('Chọn học kỳ'),
            items: semesterOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _isEdit ? null : (v) => setState(() => _selectedSemester = v),
          ),
          const SizedBox(height: 12),
          _dlgLabel('Môn học'),
          DropdownButtonFormField<String>(
            value: _selectedSubject,
            isExpanded: true,
            decoration: _dlgDec('Chọn môn'),
            items: subjectOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _isEdit ? null : (v) => setState(() => _selectedSubject = v),
          ),
          const SizedBox(height: 12),
          // Bốn ô điểm phải khớp với 4 cột trong bảng hiển thị
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.calculate_rounded, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  const Text('Bảng điểm',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF334155))),
                  const Spacer(),
                  if (_total != null)
                    Text(
                      'Tổng: ${_total!.toStringAsFixed(2)} • ${_dlgGradeOf(_total!)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _dlgGradeColor(_total!)),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _dlgScoreField(_ccC, 'CC (10%)', '8')),
                  const SizedBox(width: 8),
                  Expanded(child: _dlgScoreField(_qktC, 'QK (30%)', '7')),
                  const SizedBox(width: 8),
                  Expanded(child: _dlgScoreField(_cktC, 'CK (60%)', '8.5')),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _total != null
                        ? _dlgGradeColor(_total!).withValues(alpha: 0.08)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _total != null
                          ? _dlgGradeColor(_total!).withValues(alpha: 0.3)
                          : const Color(0xFFE0E7FF),
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.functions_rounded,
                        size: 14,
                        color: _total != null ? _dlgGradeColor(_total!) : const Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    const Text('Tổng kết',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      _total == null ? '—' : _total!.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    if (_total != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _dlgGradeColor(_total!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _dlgGradeOf(_total!),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _dlgLabel('Ghi chú'),
          TextField(
            controller: _noteC,
            maxLines: 2,
            decoration: _dlgDec('Ghi chú tuỳ chọn...'),
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
                onPressed: _onSubmit,
                icon: Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                label: Text(_isEdit ? 'Lưu thay đổi' : 'Thêm điểm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEdit ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _onSubmit() {
    final code = _studentCodeC.text.trim();

    if (_isEdit) {
      if (_ccC.text.isEmpty && _qktC.text.isEmpty && _cktC.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập ít nhất 1 cột điểm'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    } else {
      if (code.isEmpty || _selectedSemester == null || _selectedSubject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn đầy đủ Sinh viên, Học kỳ và Môn học'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
      if (_ccC.text.isEmpty && _qktC.text.isEmpty && _cktC.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập ít nhất 1 cột điểm (CC / QK / CK)'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    final cc = double.tryParse(_ccC.text.trim());
    final qk = double.tryParse(_qktC.text.trim());
    final ck = double.tryParse(_cktC.text.trim());

    for (final pair in [('CC', cc), ('QK', qk), ('CK', ck)]) {
      final v = pair.$2;
      if (v != null && (v < 0 || v > 10)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Điểm ${pair.$1} phải nằm trong khoảng 0 - 10'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    Navigator.pop(context, {
      'student_code': code,
      'subject': _selectedSubject,
      'semester': _selectedSemester,
      'cc_score': cc,
      'qkt_score': qk,
      'ckt_score': ck,
      'total_score': _total,
      'grade': _total != null ? _dlgGradeOf(_total!) : null,
      'status': _total != null ? (_total! >= 4.0 ? 'pass' : 'fail') : null,
      'note': _noteC.text.trim(),
    });
  }
}
