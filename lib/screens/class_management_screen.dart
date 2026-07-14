import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ClassManagementScreen extends StatefulWidget {
  final bool embedded;
  const ClassManagementScreen({super.key, this.embedded = false});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _search = '';
  String? _yearFilter;
  String? _facultyFilter;
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadClasses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _search = _searchController.text.toLowerCase().trim();
      _applyFilters();
    });
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getClasses();
      if (!mounted) return;
      setState(() {
        _classes = data is List ? data.map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _classes = _mockClasses();
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockClasses() {
    return [
      {'id': 1, 'name': 'CNTT01', 'course_year': 'K47', 'faculty': 'Công nghệ thông tin', 'student_count': 40, 'description': 'Lớp CNTT K47A'},
      {'id': 2, 'name': 'CNTT02', 'course_year': 'K47', 'faculty': 'Công nghệ thông tin', 'student_count': 38, 'description': 'Lớp CNTT K47B'},
      {'id': 3, 'name': 'ATTT01', 'course_year': 'K47', 'faculty': 'An toàn thông tin', 'student_count': 35, 'description': 'Lớp ATTT K47A'},
      {'id': 4, 'name': 'KTPM01', 'course_year': 'K47', 'faculty': 'Kỹ thuật phần mềm', 'student_count': 36, 'description': 'Lớp KTPM K47A'},
      {'id': 5, 'name': 'CNTT03', 'course_year': 'K46', 'faculty': 'Công nghệ thông tin', 'student_count': 42, 'description': 'Lớp CNTT K46A'},
      {'id': 6, 'name': 'CNTT04', 'course_year': 'K46', 'faculty': 'Công nghệ thông tin', 'student_count': 40, 'description': 'Lớp CNTT K46B'},
      {'id': 7, 'name': 'ATTT02', 'course_year': 'K46', 'faculty': 'An toàn thông tin', 'student_count': 33, 'description': 'Lớp ATTT K46A'},
      {'id': 8, 'name': 'KTPM02', 'course_year': 'K46', 'faculty': 'Kỹ thuật phần mềm', 'student_count': 37, 'description': 'Lớp KTPM K46A'},
    ];
  }

  void _applyFilters() {
    _filtered = _classes.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      final year = (c['course_year'] ?? '').toString();
      final fac = (c['faculty'] ?? '').toString();
      final matchSearch = _search.isEmpty || name.contains(_search) || desc.contains(_search);
      final matchYear = _yearFilter == null || _yearFilter!.isEmpty || year == _yearFilter;
      final matchFaculty = _facultyFilter == null || _facultyFilter!.isEmpty || fac == _facultyFilter;
      return matchSearch && matchYear && matchFaculty;
    }).toList();
  }

  List<String> _getUniqueYears() {
    final set = <String>{};
    for (final c in _classes) {
      final y = (c['course_year'] ?? '').toString().trim();
      if (y.isNotEmpty) set.add(y);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> _getUniqueFaculties() {
    final set = <String>{};
    for (final c in _classes) {
      final f = (c['faculty'] ?? '').toString().trim();
      if (f.isNotEmpty) set.add(f);
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> _deleteClass(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa lớp'),
        content: Text('Bạn có chắc muốn xóa lớp "$name"? Hành động không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteClass(id);
      await _loadClasses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa lớp')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _showAddForm() => _openClassForm();
  void _showEditForm(Map<String, dynamic> c) => _openClassForm(existing: c);

  Future<void> _openClassForm({Map<String, dynamic>? existing}) async {
    final nameC = TextEditingController(text: existing?['name']?.toString() ?? '');
    final yearC = TextEditingController(text: existing?['course_year']?.toString() ?? '');
    final facultyC = TextEditingController(text: existing?['faculty']?.toString() ?? '');
    final descC = TextEditingController(text: existing?['description']?.toString() ?? '');
    final isEdit = existing != null;
    final years = _getUniqueYears();
    final faculties = _getUniqueFaculties();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isEdit ? const Color(0xFFEEF2FF) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.class_rounded,
                        color: isEdit ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Sửa lớp học' : 'Thêm lớp học mới',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameC,
                    decoration: InputDecoration(
                      labelText: 'Tên lớp *',
                      hintText: 'VD: CNTT01, CK-K47A',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.class_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: years.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: years.contains(yearC.text) ? yearC.text : null,
                              decoration: const InputDecoration(
                                labelText: 'Khóa',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              items: [...years, 'K48', 'K45'].where((y) => !years.contains(y)).toList()
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                  .toList(),
                              onChanged: (v) => setLocal(() => yearC.text = v ?? ''),
                            )
                          : TextField(
                              controller: yearC,
                              decoration: const InputDecoration(
                                labelText: 'Khóa',
                                hintText: 'VD: K47',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: faculties.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: faculties.contains(facultyC.text) ? facultyC.text : null,
                              decoration: const InputDecoration(
                                labelText: 'Khoa',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_balance_rounded),
                              ),
                              items: [...faculties, 'Khoa học máy tính'].where((f) => !faculties.contains(f)).toList()
                                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                  .toList(),
                              onChanged: (v) => setLocal(() => facultyC.text = v ?? ''),
                            )
                          : TextField(
                              controller: facultyC,
                              decoration: const InputDecoration(
                                labelText: 'Khoa',
                                hintText: 'VD: Công nghệ thông tin',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_balance_rounded),
                              ),
                            ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descC,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      hintText: 'Mô tả lớp học...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (nameC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập tên lớp')),
                            );
                            return;
                          }
                          try {
                            final payload = {
                              'name': nameC.text.trim(),
                              'course_year': yearC.text.trim(),
                              'faculty': facultyC.text.trim(),
                              'description': descC.text.trim(),
                            };
                            if (isEdit) {
                              await ApiService.updateClass(existing['id'] as int, payload);
                            } else {
                              await ApiService.addClass(payload);
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            await _loadClasses();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Đã cập nhật lớp' : 'Đã thêm lớp mới'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
                              );
                            }
                          }
                        },
                        icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                        label: Text(isEdit ? 'Lưu thay đổi' : 'Thêm lớp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEdit ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: const Text('Quản lý lớp học'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _showAddForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm lớp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6366F1),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(widget.embedded ? 20 : 0, widget.embedded ? 20 : 0, widget.embedded ? 20 : 0, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.class_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quản lý lớp học',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_classes.length} lớp • ${_getUniqueYears().length} khóa • ${_getUniqueFaculties().length} khoa',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadClasses,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.embedded ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCards(),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF6366F1),
                    unselectedLabelColor: const Color(0xFF6B7280),
                    indicatorColor: const Color(0xFF6366F1),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Danh sách lớp'),
                      Tab(icon: Icon(Icons.add_rounded, size: 18), text: 'Thêm lớp mới'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildListTab(),
                        _buildAddTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final total = _classes.length;
    final years = _getUniqueYears().length;
    final faculties = _getUniqueFaculties().length;
    final totalStudents = _classes.fold<int>(0, (sum, c) => sum + ((c['student_count'] ?? 0) as num).toInt());

    final cards = [
      _statCard('Tổng lớp', '$total', const Color(0xFF6366F1), const Color(0xFFEEF2FF), Icons.class_rounded),
      _statCard('Tổng khóa', '$years', const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.calendar_month_rounded),
      _statCard('Tổng khoa', '$faculties', const Color(0xFFF59E0B), const Color(0xFFFFFBEB), Icons.account_balance_rounded),
      _statCard('SV đăng ký', '$totalStudents', const Color(0xFF3B82F6), const Color(0xFFEFF6FF), Icons.groups_2_rounded),
    ];

    return LayoutBuilder(
      builder: (ctx, c) {
        final cardWidth = ((c.maxWidth - 14 * 3) / 4).clamp(160.0, 9999.0);
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.map((w) => SizedBox(width: cardWidth, child: w)).toList(),
        );
      },
    );
  }

  Widget _statCard(String title, String value, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    return _filtered.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.class_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Không tìm thấy lớp nào', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Tìm theo tên, mô tả lớp...',
                                border: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (_search.isNotEmpty)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              icon: Icon(Icons.clear, color: Colors.grey.shade500, size: 18),
                              onPressed: () => _searchController.clear(),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _filterDropdown(
                      _yearFilter,
                      {'all': 'Tất cả khóa', ...{for (final y in _getUniqueYears()) y: y}},
                      (v) => setState(() { _yearFilter = v == 'all' ? null : v; _applyFilters(); }),
                    ),
                    const SizedBox(width: 10),
                    _filterDropdown(
                      _facultyFilter,
                      {'all': 'Tất cả khoa', ...{for (final f in _getUniqueFaculties()) f: f}},
                      (v) => setState(() { _facultyFilter = v == 'all' ? null : v; _applyFilters(); }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTable(),
              ],
            ),
          );
  }

  Widget _filterDropdown(String? value, Map<String, String> opts, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: opts.containsKey(value) ? value : opts.keys.first,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: opts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: const Row(
              children: [
                SizedBox(width: 42, child: Text('ID', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Tên lớp', style: _headerStyle)),
                SizedBox(width: 80, child: Text('Khóa', style: _headerStyle)),
                SizedBox(width: 160, child: Text('Khoa', style: _headerStyle)),
                SizedBox(width: 80, child: Text('SV', style: _headerStyle, textAlign: TextAlign.center)),
                SizedBox(width: 100, child: Text('Hành động', style: _headerStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ..._filtered.asMap().entries.map((e) => _classRow(e.value, e.key)),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.3,
  );

  Widget _classRow(Map<String, dynamic> c, int idx) {
    final name = (c['name'] ?? '').toString();
    final year = (c['course_year'] ?? '—').toString();
    final faculty = (c['faculty'] ?? '—').toString();
    final count = (c['student_count'] ?? 0).toString();

    return Container(
      decoration: BoxDecoration(
        color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text('#${c['id'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7280), fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis),
                      if ((c['description'] ?? '').toString().isNotEmpty)
                        Text((c['description'] ?? '').toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(year, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
            ),
          ),
          SizedBox(
            width: 160,
            child: Text(faculty, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _showEditForm(Map<String, dynamic>.from(c)),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.edit, color: Color(0xFF6366F1), size: 16),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _deleteClass(c['id'] as int, name),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.class_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Tạo lớp học mới', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Điền thông tin bên dưới để thêm lớp học vào hệ thống.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: _inlineFormField(
                      label: 'Tên lớp *',
                      hint: 'VD: CNTT01',
                      icon: Icons.class_rounded,
                      controller: TextEditingController(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _inlineFormField(
                      label: 'Khóa',
                      hint: 'VD: K47',
                      icon: Icons.calendar_today_rounded,
                      controller: TextEditingController(),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _inlineFormField(
                      label: 'Khoa',
                      hint: 'VD: Công nghệ thông tin',
                      icon: Icons.account_balance_rounded,
                      controller: TextEditingController(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _inlineFormField(
                      label: 'Số sinh viên',
                      hint: 'VD: 40',
                      icon: Icons.groups_2_rounded,
                      controller: TextEditingController(),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAddForm,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Mở form nhập chi tiết'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineFormField({required String label, required String hint, required IconData icon, required TextEditingController controller}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
