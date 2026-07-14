import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';

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
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _stats = {};
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
    _loadFilters();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final results = await Future.wait([
      MockDataService.getGradeBookClasses(),
      MockDataService.getGradeBookSemesters(),
      MockDataService.getGradeBookSubjects(),
    ]);
    if (!mounted) return;
    setState(() {
      _classOptions = results[0];
      _semesterOptions = results[1];
      _subjectOptions = results[2];
      // Map name → id để truyền đúng vào service
      _semesterIdMap.clear();
      for (var i = 0; i < MockDataService.canonicalSemesters.length; i++) {
        final m = MockDataService.canonicalSemesters[i];
        _semesterIdMap[m['semester_name'] as String] = m['semester_id'] as int;
      }
    });
  }

  Future<void> _loadData() async {
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
        Container(
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
            onChanged: (v) { setState(() => _selectedClass = v); _loadData(); },
          )),
          SizedBox(width: isWide ? (c.maxWidth - 36) / 4 : c.maxWidth, child: _filterDropdown(
            icon: Icons.calendar_month_rounded,
            hint: 'Tất cả kỳ học',
            value: _selectedSemester,
            items: _semesterOptions,
            onChanged: (v) { setState(() => _selectedSemester = v); _loadData(); },
          )),
          SizedBox(width: isWide ? (c.maxWidth - 36) / 4 : c.maxWidth, child: _filterDropdown(
            icon: Icons.menu_book_rounded,
            hint: 'Tất cả môn học',
            value: _selectedSubject,
            items: _subjectOptions,
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
    // Đảm bảo value luôn nằm trong items (tránh DropdownButton crash).
    final safeItems = items.isEmpty ? [''] : items;
    final safeValue = (value != null && safeItems.contains(value)) ? value : '';
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
            child: Text(r['student_code'] as String,
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
                    (r['full_name'] as String).substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r['full_name'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827))),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(r['class_name'] as String,
                style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['subject_name'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                Text(r['subject_code'] as String,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          _scoreCell('${r['cc_score']}'),
          _scoreCell('${r['qkt_score']}'),
          _scoreCell('${r['ckt_score']}'),
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                '${r['total_score']}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: pass ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
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
                  color: _gradeBg(r['grade'] as String),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r['grade'] as String,
                    style: TextStyle(color: _gradeFg(r['grade'] as String), fontWeight: FontWeight.w900, fontSize: 11)),
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
                  const SizedBox(width: 6),
                  _iconAction(Icons.edit_rounded, const Color(0xFFF59E0B),
                      () => _showEditDialog(r)),
                  const SizedBox(width: 6),
                  _iconAction(Icons.delete_rounded, const Color(0xFFEF4444),
                      () => _confirmDelete(r)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCell(String v) {
    final i = int.tryParse(v) ?? 0;
    return SizedBox(
      width: 60,
      child: Center(
        child: Text(v, style: TextStyle(
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
            subjectOptions: _subjectOptions,
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    // Thêm row vào cache để UI hiển thị tức thì, khớp 4 cột bảng
    final subjectRaw = (result['subject'] ?? '').toString();
    final subjectSplit = subjectRaw.contains(' - ')
        ? subjectRaw.split(' - ')
        : [subjectRaw, subjectRaw];
    final newRow = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'student_code': result['student_code'],
      'full_name': result['student_code'],
      'class_name': '',
      'subject_code': subjectSplit[0],                       // "IT001"
      'subject_name': subjectSplit.length > 1 ? subjectSplit[1] : subjectRaw, // "Lập trình cơ bản"
      'semester': result['semester'],
      'cc_score': result['cc_score'],
      'qkt_score': result['qkt_score'],
      'ckt_score': result['ckt_score'],
      'total_score': result['total_score'],
      'grade': result['grade'],
      'status': result['status'],
      'note': result['note'] ?? '',
    };
    setState(() {
      _rows = [newRow, ..._rows];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã thêm: ${result['student_code']} - Tổng ${(result['total_score'] as num).toStringAsFixed(2)} • ${result['grade']}',
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
            subjectOptions: _subjectOptions,
            initial: r,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    // Cập nhật row trong cache _rows để UI refresh tức thì
    final id = result['id'];
    if (id != null) {
      setState(() {
        _rows = _rows.map((e) {
          if ((e['id'] ?? '').toString() == id.toString()) {
            return {
              ...e,
              'cc_score': result['cc_score'],
              'qkt_score': result['qkt_score'],
              'ckt_score': result['ckt_score'],
              'total_score': result['total_score'],
              'grade': result['grade'],
              'status': result['status'],
              'note': result['note'],
            };
          }
          return e;
        }).toList();
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã cập nhật: ${result['student_code']} - Tổng ${(result['total_score'] as num).toStringAsFixed(2)} • ${result['grade']}',
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa (mock)')),
              );
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
  final Map<String, dynamic>? initial;

  const _AddGradeDialog({
    required this.classOptions,
    required this.semesterOptions,
    required this.subjectOptions,
    this.initial,
  });

  @override
  State<_AddGradeDialog> createState() => _AddGradeDialogState();
}

class _AddGradeDialogState extends State<_AddGradeDialog> {
  final _studentCodeC = TextEditingController();
  final _noteC = TextEditingController();
  // Bốn ô điểm tương ứng 4 cột trong bảng
  final _ccC = TextEditingController();
  final _qktC = TextEditingController();
  final _cktC = TextEditingController();
  String? _selectedClass;
  String? _selectedSubject;
  String? _selectedSemester;

  bool get _isEdit => widget.initial != null;

  // Hằng số trọng số (theo đúng 4 cột bảng hiển thị)
  static const double _wCC = 0.10;
  static const double _wQK = 0.30;
  static const double _wCK = 0.60;

  double? _cc;
  double? _qkt;
  double? _ckt;
  double? _ckc; // cuối khóa check (?)

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      // Edit mode: prefill tất cả field theo đúng cột
      _studentCodeC.text = (init['student_code'] ?? '').toString();
      _noteC.text = (init['note'] ?? '').toString();
      // Bốn cột điểm phải khớp bảng
      _ccC.text = _fmtIfNum(init['cc_score']);
      _qktC.text = _fmtIfNum(init['qkt_score']);
      _cktC.text = _fmtIfNum(init['ckt_score']);
      // Nếu chỉ có 1 ô cũ 'final_score', map sang cuối kỳ
      if (_cktC.text.isEmpty) {
        _cktC.text = _fmtIfNum(init['final_score'] ?? init['score']);
      }
      _recalc();

      final sem = (init['semester'] ?? init['semester_name'] ?? '').toString();
      if (widget.semesterOptions.contains(sem)) _selectedSemester = sem;
      final subj = (init['subject_code'] ?? '').toString();
      if (subj.isNotEmpty) {
        final match = widget.subjectOptions.firstWhere(
          (s) => s.startsWith('$subj - ') || s == subj,
          orElse: () => widget.subjectOptions.isNotEmpty ? widget.subjectOptions.first : subj,
        );
        _selectedSubject = match;
      }
      final cls = (init['class_name'] ?? '').toString();
      if (widget.classOptions.contains(cls)) _selectedClass = cls;
    }
    _selectedClass ??= widget.classOptions.isNotEmpty ? widget.classOptions.first : null;
    _selectedSemester ??= widget.semesterOptions.isNotEmpty ? widget.semesterOptions.first : null;
    _selectedSubject ??= widget.subjectOptions.isNotEmpty ? widget.subjectOptions.first : null;
    // Lắng nghe thay đổi
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
        _ckc = _cc! * _wCC + _qkt! * _wQK + _ckt! * _wCK;
      } else {
        _ckc = null;
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
          _label('Mã sinh viên'),
          TextField(
            controller: _studentCodeC,
            decoration: _dec('Nhập mã SV...'),
          ),
          const SizedBox(height: 12),
          _label('Môn học'),
          DropdownButtonFormField<String>(
            value: widget.subjectOptions.contains(_selectedSubject) ? _selectedSubject : null,
            isExpanded: true,
            decoration: _dec('Chọn môn'),
            items: widget.subjectOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _selectedSubject = v),
          ),
          const SizedBox(height: 12),
          _label('Học kỳ'),
          DropdownButtonFormField<String>(
            value: widget.semesterOptions.contains(_selectedSemester) ? _selectedSemester : null,
            isExpanded: true,
            decoration: _dec('Chọn học kỳ'),
            items: widget.semesterOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _selectedSemester = v),
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
                  const Text('Bảng điểm (khớp 4 cột)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF334155))),
                  const Spacer(),
                  if (_ckc != null)
                    Text(
                      'Tổng: ${_ckc!.toStringAsFixed(2)} • ${_gradeOf(_ckc!)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _gradeColor(_ckc!),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _scoreField(_ccC, 'CC (10%)', '8')),
                  const SizedBox(width: 8),
                  Expanded(child: _scoreField(_qktC, 'QK (30%)', '7')),
                  const SizedBox(width: 8),
                  Expanded(child: _scoreField(_cktC, 'CK (60%)', '8.5')),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _ckc != null
                        ? _gradeColor(_ckc!).withValues(alpha: 0.08)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _ckc != null
                          ? _gradeColor(_ckc!).withValues(alpha: 0.3)
                          : const Color(0xFFE0E7FF),
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.functions_rounded,
                        size: 14,
                        color: _ckc != null ? _gradeColor(_ckc!) : const Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    const Text('Tổng kết',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      _ckc == null ? '—' : _ckc!.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    if (_ckc != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _gradeColor(_ckc!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _gradeOf(_ckc!),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _label('Ghi chú'),
          TextField(
            controller: _noteC,
            maxLines: 2,
            decoration: _dec('Ghi chú tuỳ chọn...'),
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
                  final code = _studentCodeC.text.trim();
                  if (code.isEmpty || _selectedSubject == null || _selectedSemester == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập Mã SV, chọn môn và học kỳ'),
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
                  final cc = double.tryParse(_ccC.text.trim());
                  final qk = double.tryParse(_qktC.text.trim());
                  final ck = double.tryParse(_cktC.text.trim());
                  for (final pair in [
                    ('CC', cc),
                    ('QK', qk),
                    ('CK', ck),
                  ]) {
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
                  if (_ckc == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập đủ 3 cột điểm để tính Tổng kết'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'id': _isEdit ? widget.initial!['id'] : null,
                    'student_code': code,
                    'subject': _selectedSubject,
                    'semester': _selectedSemester,
                    'cc_score': cc,
                    'qkt_score': qk,
                    'ckt_score': ck,
                    'total_score': _ckc,
                    'grade': _gradeOf(_ckc!),
                    'status': _ckc! >= 4.0 ? 'pass' : 'fail',
                    'note': _noteC.text.trim(),
                  });
                },
                icon: Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                label: Text(_isEdit ? 'Lưu thay đổi' : 'Thêm điểm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEdit ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
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
