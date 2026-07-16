import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'grades_screen.dart';

class StudentsScreen extends StatefulWidget {
  final bool embedded;
  const StudentsScreen({super.key, this.embedded = false});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _students = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  String _role = '';
  String _search = '';
  String _classFilter = 'all';
  String _statusFilter = 'all';
  int _page = 1;
  final int _pageSize = 8;
  late final TabController _tabController;

  bool get _embedded => widget.embedded;
  final _searchController = TextEditingController();

  final _addNameC = TextEditingController();
  final _addCodeC = TextEditingController();
  final _addEmailC = TextEditingController();
  final _addPhoneC = TextEditingController();
  final _addClassC = TextEditingController();
  final _addBirthC = TextEditingController();
  String _addGender = 'Nam';
  List<String> _dbClasses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRole();
    _loadStudents();
    _searchController.addListener(_onSearchChanged);
  }

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _addNameC.dispose();
    _addCodeC.dispose();
    _addEmailC.dispose();
    _addPhoneC.dispose();
    _addClassC.dispose();
    _addBirthC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _search = _searchController.text.toLowerCase().trim();
      _page = 1;
      _applyFilters();
    });
  }

  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _role = prefs.getString('role') ?? '');
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);

    try {
      final classData = await ApiService.getClasses();
      if (!mounted) return;
      setState(() {
        _dbClasses = classData.map((c) => (c['name'] ?? '').toString()).where((c) => c.isNotEmpty).toList();
        _dbClasses.sort();
      });
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }

    try {
      final data = await ApiService.getStudents();
      if (!mounted) return;
      setState(() {
        if (data is List) {
          _students = data;
        } else if (data is Map) {
          _students = [data];
        } else {
          _students = [];
        }
        
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (!mounted) return;
      setState(() {
        _students = [];
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  String _statusOf(Map s) {
    final raw = (s['academic_status'] ?? s['status'] ?? '').toString().toLowerCase();
    if (raw == 'suspended' || raw.contains('bảo lưu')) return 'paused';
    if (raw == 'graduated' || raw.contains('tốt nghiệp')) return 'graduated';
    if (raw == 'dropout' || raw.contains('thôi')) return 'dropout';
    return 'studying';
  }

  String _statusLabel(String key) {
    switch (key) {
      case 'paused': return 'Bảo lưu';
      case 'graduated': return 'Tốt nghiệp';
      case 'dropout': return 'Thôi học';
      default: return 'Đang học';
    }
  }

  Color _statusColor(String key) {
    switch (key) {
      case 'paused': return const Color(0xFFF59E0B);
      case 'graduated': return const Color(0xFF8B5CF6);
      case 'dropout': return const Color(0xFFEF4444);
      default: return const Color(0xFF10B981);
    }
  }

  Color _statusBg(String key) {
    switch (key) {
      case 'paused': return const Color(0xFFFFFBEB);
      case 'graduated': return const Color(0xFFF5F3FF);
      case 'dropout': return const Color(0xFFFEF2F2);
      default: return const Color(0xFFECFDF5);
    }
  }

  void _applyFilters() {
    _filtered = _students.where((s) {
      final name = (s['full_name'] ?? '').toString().toLowerCase();
      final code = (s['student_code'] ?? '').toString().toLowerCase();
      final className = (s['class_name'] ?? '').toString();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final status = _statusOf(s);

      final matchSearch = _search.isEmpty ||
          name.contains(_search) ||
          code.contains(_search) ||
          className.toLowerCase().contains(_search) ||
          email.contains(_search);
      final matchClass = _classFilter == 'all' || className == _classFilter;
      final matchStatus = _statusFilter == 'all' || status == _statusFilter;
      return matchSearch && matchClass && matchStatus;
    }).toList();
  }

  List<String> _getUniqueClasses() {
    if (_dbClasses.isNotEmpty) return _dbClasses;
    final set = <String>{};
    for (final s in _students) {
      final c = (s['class_name'] ?? '').toString().trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  Future<void> _deleteStudent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa sinh viên'),
        content: const Text('Bạn có chắc muốn xóa sinh viên này? Hành động không thể hoàn tác.'),
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
      await ApiService.deleteStudent(id);
      await _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa sinh viên')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _showEditForm(Map<String, dynamic> s) => _openStudentForm(existing: s);

  Future<void> _openStudentForm({Map<String, dynamic>? existing}) async {
    final codeC = TextEditingController(text: existing?['student_code']?.toString() ?? '');
    final nameC = TextEditingController(text: existing?['full_name']?.toString() ?? '');
    final emailC = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phoneC = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final classC = TextEditingController(text: existing?['class_name']?.toString() ?? '');
    final rawBirth = existing?['birth_date']?.toString() ?? '';
    final birthC = TextEditingController(
        text: rawBirth.length >= 10 ? rawBirth.substring(0, 10) : rawBirth);
    String gender = existing?['gender']?.toString() ?? 'Nam';
    String status = existing != null ? _statusLabel(_statusOf(existing)) : 'Đang học';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 600,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          const Text('Chỉnh sửa sinh viên', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(child: _inputField('Mã sinh viên *', codeC, readOnly: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _inputField('Họ tên *', nameC)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: gender,
                            decoration: const InputDecoration(
                              labelText: 'Giới tính',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                              DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                              DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                            ],
                            onChanged: (v) => setLocal(() => gender = v ?? 'Nam'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: birthC,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Ngày sinh',
                              border: OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            onTap: () async {
                              DateTime init = DateTime(2000);
                              try {
                                if (birthC.text.isNotEmpty) init = DateTime.parse(birthC.text);
                              } catch (_) {}
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: init,
                                firstDate: DateTime(1970),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                birthC.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _inputField('Email', emailC, type: TextInputType.emailAddress)),
                        const SizedBox(width: 12),
                        Expanded(child: _inputField('Số điện thoại', phoneC, type: TextInputType.phone)),
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _dbClasses.contains(classC.text) && classC.text.isNotEmpty ? classC.text : null,
                        decoration: const InputDecoration(
                          labelText: 'Lớp',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _dbClasses.isEmpty 
                            ? [const DropdownMenuItem(value: '', child: Text('Chưa có lớp nào'))] 
                            : _dbClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setLocal(() => classC.text = v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Đang học', child: Text('Đang học')),
                          DropdownMenuItem(value: 'Bảo lưu', child: Text('Bảo lưu')),
                          DropdownMenuItem(value: 'Tốt nghiệp', child: Text('Tốt nghiệp')),
                          DropdownMenuItem(value: 'Thôi học', child: Text('Thôi học')),
                        ],
                        onChanged: (v) => setLocal(() => status = v ?? 'Đang học'),
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
                              if (codeC.text.trim().isEmpty || nameC.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Vui lòng nhập mã SV và họ tên')),
                                );
                                return;
                              }
                              try {
                                final payload = <String, dynamic>{
                                  'student_code': codeC.text.trim(),
                                  'full_name': nameC.text.trim(),
                                  'gender': gender,
                                  'birth_date': birthC.text.isNotEmpty ? birthC.text : null,
                                  'email': emailC.text.trim(),
                                  'phone': phoneC.text.trim(),
                                  'class_name': classC.text.trim(),
                                  'status': status == 'Đang học' ? 'active' : (status == 'Bảo lưu' ? 'suspended' : (status == 'Tốt nghiệp' ? 'graduated' : 'dropout')),
                                };
                                await ApiService.updateStudent(existing!['id'] as int, payload);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                await _loadStudents();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã cập nhật sinh viên'),
                                      backgroundColor: Color(0xFF10B981),
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
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Lưu thay đổi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
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
            );
          },
        );
      },
    );
  }

  Widget _inputField(String label, TextEditingController c, {TextInputType? type, bool readOnly = false}) {
    return TextField(
      controller: c,
      keyboardType: type,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_embedded) {
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
        title: const Text('Quản lý sinh viên'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearToken();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.people_alt, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sinh viên', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Text('Quản lý hồ sơ, thêm mới và tra cứu', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          const Spacer(),
          if (_role == 'admin')
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFFF97316),
                unselectedLabelColor: const Color(0xFF6B7280),
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                padding: const EdgeInsets.all(4),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Icon(Icons.list_alt, size: 18), SizedBox(width: 8), Text('Danh sách')]))),
                  Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Icon(Icons.person_add_alt, size: 18), SizedBox(width: 8), Text('Thêm mới')]))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final padding = EdgeInsets.symmetric(horizontal: _embedded ? 20 : 16);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat cards
          _buildStatCards(),
          const SizedBox(height: 20),
          
          Expanded(
            child: _role == 'admin' 
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListTab(),
                    _buildAddTab(),
                  ],
                )
              : _buildListTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final total = _students.length;
    final studying = _students.where((s) => _statusOf(s) == 'studying').length;
    final paused = _students.where((s) => _statusOf(s) == 'paused').length;
    final graduated = _students.where((s) => _statusOf(s) == 'graduated').length;

    final cards = [
      _statCard('Tổng sinh viên', '$total', 'Tất cả hồ sơ',
          const Color(0xFFF97316), const Color(0xFFFFEDD5), Icons.people_alt_rounded),
      _statCard('Đang học', '$studying', 'Hoạt động',
          const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.school_rounded),
      _statCard('Bảo lưu', '$paused', 'Tạm dừng',
          const Color(0xFFF59E0B), const Color(0xFFFFFBEB), Icons.pause_circle_outline_rounded),
      _statCard('Tốt nghiệp', '$graduated', 'Đã hoàn thành',
          const Color(0xFF8B5CF6), const Color(0xFFF5F3FF), Icons.workspace_premium_rounded),
    ];

    return LayoutBuilder(
      builder: (ctx, c) {
        final width = c.maxWidth;
        final cardWidth = ((width - 14 * 3) / 4).clamp(160.0, 9999.0);
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.map((w) => SizedBox(width: cardWidth, child: w)).toList(),
        );
      },
    );
  }

  Widget _statCard(String title, String value, String subtitle, Color color, Color bg, IconData icon) {
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
          Text(value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Không tìm thấy sinh viên nào', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
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
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo tên, mã SV, email...',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              InkWell(
                                onTap: () => _searchController.clear(),
                                child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _filterDropdown(
                      'Lớp',
                      _classFilter,
                      {'all': 'Tất cả lớp', ...{for (final c in _getUniqueClasses()) c: c}},
                      (v) {
                        setState(() {
                          _classFilter = v ?? 'all';
                          _page = 1;
                          _applyFilters();
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _filterDropdown(
                      'Trạng thái',
                      _statusFilter,
                      const {
                        'all': 'Tất cả',
                        'studying': 'Đang học',
                        'paused': 'Bảo lưu',
                        'graduated': 'Tốt nghiệp',
                        'dropout': 'Thôi học',
                      },
                      (v) {
                        setState(() {
                          _statusFilter = v ?? 'all';
                          _page = 1;
                          _applyFilters();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTable(),
              ],
            ),
          );
  }

  Widget _filterDropdown(String label, String value, Map<String, String> opts, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: opts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTable() {
    final totalPages = (_filtered.length / _pageSize).ceil().clamp(1, 9999);
    final start = (_page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    final pageRows = _filtered.sublist(start, end);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280), fontSize: 13))),
                    Expanded(flex: 3, child: Text('Sinh viên', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280), fontSize: 13))),
                    Expanded(flex: 2, child: Text('Mã SV', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280), fontSize: 13))),
                    Expanded(flex: 2, child: Text('Lớp', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280), fontSize: 13))),
                    Expanded(flex: 2, child: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280), fontSize: 13))),
                    SizedBox(width: 100, child: Text('Thao tác', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280), fontSize: 13))),
                  ],
                ),
              ),
              // Rows
              ...pageRows.asMap().entries.map((e) {
                final idx = start + e.key + 1;
                final s = e.value;
                final name = (s['full_name'] ?? '').toString();
                final code = (s['student_code'] ?? '').toString();
                final className = (s['class_name'] ?? '').toString();
                final email = (s['email'] ?? '').toString();
                final status = _statusOf(s);
                
                return Container(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text('$idx', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13))),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade50,
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis),
                                  Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(code, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF4B5563)))),
                      Expanded(flex: 2, child: Text(className, style: const TextStyle(color: Color(0xFF4B5563)))),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusBg(status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_role == 'admin') ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6B7280)),
                                onPressed: () => _showEditForm(s),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                tooltip: 'Sửa',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                onPressed: () => _deleteStudent(s['id']),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                tooltip: 'Xóa',
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF3B82F6)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GradesScreen(
                                      studentId: s['id'],
                                      studentName: name,
                                      role: _role,
                                    ),
                                  ),
                                );
                              },
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              tooltip: 'Điểm số',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        
        // Pagination
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hiển thị $start - ${end} trong số ${_filtered.length} kết quả', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                Row(
                  children: [
                    InkWell(
                      onTap: _page > 1 ? () => setState(() => _page--) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          color: _page > 1 ? Colors.white : const Color(0xFFF9FAFB),
                        ),
                        child: Text('Trước', style: TextStyle(color: _page > 1 ? const Color(0xFF374151) : const Color(0xFF9CA3AF), fontSize: 13)),
                      ),
                    ),
                    for (int i = 1; i <= totalPages; i++)
                      if (i == 1 || i == totalPages || (i >= _page - 1 && i <= _page + 1))
                        InkWell(
                          onTap: () => setState(() => _page = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: const BorderSide(color: Color(0xFFE5E7EB)),
                                bottom: const BorderSide(color: Color(0xFFE5E7EB)),
                                left: i > 1 ? BorderSide.none : const BorderSide(color: Color(0xFFE5E7EB)),
                                right: i < totalPages ? const BorderSide(color: Color(0xFFE5E7EB)) : BorderSide.none,
                              ),
                              color: _page == i ? const Color(0xFFEFF6FF) : Colors.white,
                            ),
                            child: Text('$i', style: TextStyle(color: _page == i ? const Color(0xFF2563EB) : const Color(0xFF374151), fontSize: 13, fontWeight: _page == i ? FontWeight.w600 : FontWeight.normal)),
                          ),
                        )
                      else if (i == 2 || i == totalPages - 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFE5E7EB))),
                            color: Colors.white,
                          ),
                          child: const Text('...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                        ),
                    InkWell(
                      onTap: _page < totalPages ? () => setState(() => _page++) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                          color: _page < totalPages ? Colors.white : const Color(0xFFF9FAFB),
                        ),
                        child: Text('Tiếp', style: TextStyle(color: _page < totalPages ? const Color(0xFF374151) : const Color(0xFF9CA3AF), fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: Color(0xFFF97316), size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Tạo hồ sơ sinh viên mới',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Điền các thông tin bên dưới để thêm sinh viên vào hệ thống.',
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
                      label: 'Họ và tên *',
                      hint: 'Nguyễn Văn A',
                      icon: Icons.person,
                      controller: _addNameC,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _inlineFormField(
                      label: 'Mã sinh viên *',
                      hint: 'SV001',
                      icon: Icons.badge,
                      controller: _addCodeC,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _inlineFormField(
                      label: 'Email',
                      hint: 'sv@example.com',
                      icon: Icons.email,
                      controller: _addEmailC,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _inlineFormField(
                      label: 'Số điện thoại',
                      hint: '0901234567',
                      icon: Icons.phone,
                      controller: _addPhoneC,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _dbClasses.contains(_addClassC.text) && _addClassC.text.isNotEmpty ? _addClassC.text : null,
                      decoration: InputDecoration(
                        labelText: 'Lớp *',
                        prefixIcon: const Icon(Icons.class_, color: Color(0xFFF97316), size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        isDense: true,
                      ),
                      items: _dbClasses.isEmpty
                          ? [const DropdownMenuItem(value: '', child: Text('Chưa có lớp nào'))]
                          : _dbClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _addClassC.text = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _addGender,
                      decoration: InputDecoration(
                        labelText: 'Giới tính',
                        prefixIcon: const Icon(Icons.wc, color: Color(0xFFF97316), size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                        DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                        DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      ],
                      onChanged: (v) => setState(() => _addGender = v ?? 'Nam'),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _addBirthC,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ngày sinh',
                        prefixIcon: const Icon(Icons.cake, color: Color(0xFFF97316), size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        isDense: true,
                      ),
                      onTap: () async {
                        DateTime init = DateTime(2000);
                        try {
                          if (_addBirthC.text.isNotEmpty) init = DateTime.parse(_addBirthC.text);
                        } catch (_) {}
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: init,
                          firstDate: DateTime(1970),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          _addBirthC.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFFF97316)),
                          const SizedBox(width: 10),
                          const Text('Trạng thái mặc định: Đang học', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_addNameC.text.trim().isEmpty || _addCodeC.text.trim().isEmpty || _addClassC.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập Họ tên, Mã SV và chọn Lớp')));
                        return;
                      }
                      
                      try {
                        final payload = {
                          'student_code': _addCodeC.text.trim(),
                          'full_name': _addNameC.text.trim(),
                          'gender': _addGender,
                          'email': _addEmailC.text.trim(),
                          'phone': _addPhoneC.text.trim(),
                          'class_name': _addClassC.text.trim(),
                          'birth_date': _addBirthC.text.trim().isNotEmpty ? _addBirthC.text.trim() : null,
                          'status': 'active',
                        };
                        await ApiService.addStudent(payload);
                        if (!mounted) return;
                        
                        _addNameC.clear();
                        _addCodeC.clear();
                        _addEmailC.clear();
                        _addPhoneC.clear();
                        _addClassC.clear();
                        _addBirthC.clear();
                        setState(() => _addGender = 'Nam');
                        
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm sinh viên')));
                        _tabController.animateTo(0);
                        _loadStudents();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    },
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Thêm sinh viên'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFFF97316), size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
