import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class TeacherManagementScreen extends StatefulWidget {
  final bool embedded;
  const TeacherManagementScreen({super.key, this.embedded = false});

  @override
  State<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _teachers = [];
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRole();
    _loadTeachers();
    _searchController.addListener(_onSearchChanged);
  }

  void _onTabChanged() => setState(() {});

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
      _page = 1;
      _applyFilters();
    });
  }

  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _role = prefs.getString('role') ?? '');
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getTeachers();
      if (!mounted) return;
      setState(() {
        if (data is List) {
          _teachers = data.isNotEmpty ? data : _mockTeachers();
        } else if (data is Map) {
          _teachers = [data];
        } else {
          _teachers = _mockTeachers();
        }
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teachers = _mockTeachers();
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockTeachers() {
    final names = [
      ['SV001', 'Nguyễn Văn An', 'Nam', '2003-05-12', 'an.nv@teacher.edu.vn', '0901234567', 'CNTT01', 'Đang dạy'],
      ['SV002', 'Trần Thị Bình', 'Nữ', '2003-08-21', 'binh.tt@teacher.edu.vn', '0901234568', 'CNTT01', 'Đang dạy'],
      ['SV003', 'Lê Hoàng Cường', 'Nam', '2002-11-03', 'cuong.lh@teacher.edu.vn', '0901234569', 'CNTT01', 'Đang dạy'],
      ['SV004', 'Phạm Thị Dung', 'Nữ', '2003-02-14', 'dung.pt@teacher.edu.vn', '0901234570', 'CNTT01', 'Đang dạy'],
      ['SV005', 'Hoàng Minh Đức', 'Nam', '2002-07-09', 'duc.hm@teacher.edu.vn', '0901234571', 'CNTT01', 'Đang dạy'],
      ['SV006', 'Võ Thị Hoa', 'Nữ', '2003-09-25', 'hoa.vt@teacher.edu.vn', '0901234572', 'CNTT01', 'Đang dạy'],
      ['SV007', 'Đặng Quốc Huy', 'Nam', '2002-04-18', 'huy.dq@teacher.edu.vn', '0901234573', 'CNTT01', 'Đang dạy'],
      ['SV008', 'Bùi Thị Lan', 'Nữ', '2003-12-07', 'lan.bt@teacher.edu.vn', '0901234574', 'CNTT01', 'Bảo lưu'],
      ['SV009', 'Ngô Văn Khánh', 'Nam', '2002-03-22', 'khanh.nv@teacher.edu.vn', '0901234575', 'CNTT01', 'Đang dạy'],
      ['SV010', 'Đinh Thị Linh', 'Nữ', '2003-06-30', 'linh.dt@teacher.edu.vn', '0901234576', 'CNTT01', 'Đang dạy'],
      ['SV011', 'Trương Văn Minh', 'Nam', '2002-10-11', 'minh.tv@teacher.edu.vn', '0901234577', 'CNTT02', 'Đang dạy'],
      ['SV012', 'Phan Thị Ngọc', 'Nữ', '2003-01-19', 'ngoc.pt@teacher.edu.vn', '0901234578', 'CNTT02', 'Đang dạy'],
      ['SV013', 'Lý Hoàng Phúc', 'Nam', '2002-08-08', 'phuc.lh@teacher.edu.vn', '0901234579', 'CNTT02', 'Đang dạy'],
      ['SV014', 'Vũ Thị Quỳnh', 'Nữ', '2003-04-15', 'quynh.vt@teacher.edu.vn', '0901234580', 'CNTT02', 'Đang dạy'],
      ['SV015', 'Tô Văn Sơn', 'Nam', '2002-12-28', 'son.tv@teacher.edu.vn', '0901234581', 'CNTT02', 'Đang dạy'],
      ['SV016', 'Hồ Thị Trang', 'Nữ', '2003-07-04', 'trang.ht@teacher.edu.vn', '0901234582', 'CNTT02', 'Đang dạy'],
      ['SV017', 'Châu Văn Tùng', 'Nam', '2002-05-17', 'tung.cv@teacher.edu.vn', '0901234583', 'CNTT02', 'Đang dạy'],
      ['SV018', 'Dương Thị Uyên', 'Nữ', '2003-11-23', 'uyen.dt@teacher.edu.vn', '0901234584', 'CNTT02', 'Đang dạy'],
      ['SV019', 'Lâm Văn Vinh', 'Nam', '2002-09-06', 'vinh.lv@teacher.edu.vn', '0901234585', 'CNTT02', 'Tốt nghiệp'],
      ['SV020', 'Cao Thị Xuân', 'Nữ', '2003-03-14', 'xuan.ct@teacher.edu.vn', '0901234586', 'CNTT02', 'Đang dạy'],
      ['SV021', 'Đỗ Hoàng Yên', 'Nam', '2002-06-29', 'yen.dh@teacher.edu.vn', '0901234587', 'ATTT01', 'Đang dạy'],
      ['SV022', 'Mai Thị Hằng', 'Nữ', '2003-10-02', 'hang.mt@teacher.edu.vn', '0901234588', 'ATTT01', 'Đang dạy'],
      ['SV023', 'Hà Văn Khôi', 'Nam', '2002-02-26', 'khoi.hv@teacher.edu.vn', '0901234589', 'ATTT01', 'Đang dạy'],
      ['SV024', 'Kiều Thị Mai', 'Nữ', '2003-05-19', 'mai.kt@teacher.edu.vn', '0901234590', 'ATTT01', 'Đang dạy'],
      ['SV025', 'Thái Văn Nam', 'Nam', '2002-11-11', 'nam.tv@teacher.edu.vn', '0901234591', 'ATTT01', 'Đang dạy'],
      ['SV026', 'Lưu Thị Oanh', 'Nữ', '2003-08-05', 'oanh.lt@teacher.edu.vn', '0901234592', 'ATTT01', 'Bảo lưu'],
      ['SV027', 'Tăng Văn Phát', 'Nam', '2002-01-30', 'phat.tv@teacher.edu.vn', '0901234593', 'ATTT01', 'Đang dạy'],
      ['SV028', 'Quách Thị Quy', 'Nữ', '2003-12-16', 'quy.qt@teacher.edu.vn', '0901234594', 'ATTT01', 'Đang dạy'],
      ['SV029', 'Tiêu Văn Rôn', 'Nam', '2002-07-23', 'ron.tv@teacher.edu.vn', '0901234595', 'KTPM01', 'Đang dạy'],
      ['SV030', 'Âu Thị Sen', 'Nữ', '2003-04-08', 'sen.at@teacher.edu.vn', '0901234596', 'KTPM01', 'Đang dạy'],
      ['SV031', 'Chung Văn Tài', 'Nam', '2002-10-25', 'tai.cv@teacher.edu.vn', '0901234597', 'KTPM01', 'Đang dạy'],
      ['SV032', 'Mạc Thị Vân', 'Nữ', '2003-06-12', 'van.mt@teacher.edu.vn', '0901234598', 'KTPM01', 'Đang dạy'],
      ['SV033', 'Nhâm Văn Ưng', 'Nam', '2002-03-09', 'ung.nv@teacher.edu.vn', '0901234599', 'KTPM01', 'Tốt nghiệp'],
      ['SV034', 'Quan Thị Yến', 'Nữ', '2003-09-28', 'yen.qt@teacher.edu.vn', '0901234600', 'KTPM01', 'Đang dạy'],
      ['SV035', 'Từ Văn Bảo', 'Nam', '2002-12-04', 'bao.tv@teacher.edu.vn', '0901234601', 'KTPM01', 'Đang dạy'],
      ['SV036', 'Ứng Thị Cẩm', 'Nữ', '2003-02-21', 'cam.ut@teacher.edu.vn', '0901234602', 'CNTT01', 'Đang dạy'],
      ['SV037', 'Vương Văn Đạt', 'Nam', '2002-05-15', 'dat.vv@teacher.edu.vn', '0901234603', 'CNTT02', 'Đang dạy'],
      ['SV038', 'Hứa Thị Giang', 'Nữ', '2003-11-09', 'giang.ht@teacher.edu.vn', '0901234604', 'CNTT02', 'Đang dạy'],
      ['SV039', 'Kha Văn Hào', 'Nam', '2002-04-02', 'hao.kv@teacher.edu.vn', '0901234605', 'ATTT01', 'Đang dạy'],
      ['SV040', 'La Thị Kim', 'Nữ', '2003-08-17', 'kim.lt@teacher.edu.vn', '0901234606', 'KTPM01', 'Đang dạy'],
    ];
    return List.generate(names.length, (i) {
      return {
        'id': i + 1,
        'teacher_code': names[i][0],
        'full_name': names[i][1],
        'gender': names[i][2],
        'birth_date': names[i][3],
        'email': names[i][4],
        'phone': names[i][5],
        'department': names[i][6],
        'status': names[i][7],
      };
    });
  }

  String _statusOf(Map s) {
    final raw = (s['status'] ?? '').toString().toLowerCase();
    if (raw.contains('bảo lưu') || raw.contains('baolu') || raw == 'paused') return 'paused';
    if (raw.contains('tốt nghiệp') || raw.contains('totnghiep') || raw == 'graduated') return 'graduated';
    if (raw.contains('thôi') || raw.contains('nghỉ') || raw == 'quit') return 'quit';
    return 'teaching';
  }

  String _statusLabel(String key) {
    switch (key) {
      case 'paused':
        return 'Bảo lưu';
      case 'graduated':
        return 'Tốt nghiệp';
      case 'quit':
        return 'Đã nghỉ';
      default:
        return 'Đang dạy';
    }
  }

  Color _statusColor(String key) {
    switch (key) {
      case 'paused':
        return const Color(0xFFF59E0B);
      case 'graduated':
        return const Color(0xFF8B5CF6);
      case 'quit':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }

  Color _statusBg(String key) {
    switch (key) {
      case 'paused':
        return const Color(0xFFFFFBEB);
      case 'graduated':
        return const Color(0xFFF5F3FF);
      case 'quit':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFECFDF5);
    }
  }

  void _applyFilters() {
    _filtered = _teachers.where((s) {
      final name = (s['full_name'] ?? '').toString().toLowerCase();
      final code = (s['teacher_code'] ?? '').toString().toLowerCase();
      final className = (s['department'] ?? '').toString();
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
    final set = <String>{};
    for (final s in _teachers) {
      final c = (s['department'] ?? '').toString().trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  String _formatDate(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _ageOf(dynamic birth) {
    if (birth == null) return '';
    try {
      final d = DateTime.parse(birth.toString());
      final now = DateTime.now();
      var age = now.year - d.year;
      if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
      return '$age tuổi';
    } catch (_) {
      return '';
    }
  }

  Future<void> _deleteTeacher(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa giáo viên'),
        content: const Text('Bạn có chắc muốn xóa giáo viên này? Hành động không thể hoàn tác.'),
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
      await ApiService.deleteTeacher(id);
      await _loadTeachers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa giáo viên')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _showAddForm() => _openTeacherForm();
  void _showEditForm(Map<String, dynamic> s) => _openTeacherForm(existing: s);

  Future<void> _openTeacherForm({Map<String, dynamic>? existing}) async {
    final codeC = TextEditingController(text: existing?['teacher_code']?.toString() ?? '');
    final nameC = TextEditingController(text: existing?['full_name']?.toString() ?? '');
    final emailC = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phoneC = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final classC = TextEditingController(text: existing?['department']?.toString() ?? '');
    final birthC = TextEditingController(text: existing?['birth_date']?.toString() ?? '');
    String gender = existing?['gender']?.toString() ?? 'Nam';
    String status = existing != null ? _statusLabel(_statusOf(existing)) : 'Đang dạy';
    final classes = _getUniqueClasses();
    final isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 520,
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
                        color: isEdit ? const Color(0xFFEEF2FF) : const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.person_add,
                        color: isEdit ? const Color(0xFF6366F1) : const Color(0xFFF97316),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Sửa giáo viên' : 'Thêm giáo viên mới',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _inputField(isEdit ? 'Mã giáo viên' : 'Mã giáo viên *', codeC)),
                    const SizedBox(width: 12),
                    Expanded(child: _inputField(isEdit ? 'Họ và tên' : 'Họ và tên *', nameC)),
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
                            birthC.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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
                  if (classes.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: classes.contains(classC.text) ? classC.text : null,
                      decoration: const InputDecoration(
                        labelText: 'Phòng ban',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: classes
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setLocal(() => classC.text = v ?? ''),
                    )
                  else
                    _inputField('Phòng ban', classC),
                  if (isEdit) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Đang dạy', child: Text('Đang dạy')),
                        
                        
                        DropdownMenuItem(value: 'Đã nghỉ', child: Text('Đã nghỉ')),
                      ],
                      onChanged: (v) => setLocal(() => status = v ?? 'Đang dạy'),
                    ),
                  ],
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
                              'teacher_code': codeC.text.trim(),
                              'full_name': nameC.text.trim(),
                              'gender': gender,
                              'birth_date': birthC.text.isNotEmpty ? birthC.text : null,
                              'email': emailC.text.trim(),
                              'phone': phoneC.text.trim(),
                              'department': classC.text.trim(),
                              'status': status == 'Đang dạy' ? 'active' : 'quit',
                            };
                            if (isEdit) {
                              await ApiService.updateTeacher(existing['id'] as int, payload);
                } else {
                              await ApiService.addTeacher(payload);
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            await _loadTeachers();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Đã cập nhật giáo viên' : 'Đã thêm giáo viên'),
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
                        icon: Icon(isEdit ? Icons.save_rounded : Icons.person_add_alt, size: 18),
                        label: Text(isEdit ? 'Lưu thay đổi' : 'Thêm giáo viên'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEdit ? const Color(0xFF6366F1) : const Color(0xFFF97316),
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

  Widget _inputField(String label, TextEditingController c, {TextInputType? type}) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
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
        title: const Text('Quản lý giáo viên'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_role == 'admin')
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _showAddForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm giáo viên'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade700,
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
      margin: EdgeInsets.fromLTRB(_embedded ? 20 : 0, _embedded ? 20 : 0, _embedded ? 20 : 0, 0),
          padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFFBA959)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
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
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Quản lý giáo viên',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Theo dõi, tìm kiếm và quản lý hồ sơ giáo viên trong hệ thống',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadTeachers,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _teachers.isEmpty) {
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
          const SizedBox(height: 18),

          // Tabs
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFFF97316),
                    unselectedLabelColor: const Color(0xFF6B7280),
                    indicatorColor: const Color(0xFFF97316),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Danh sách giáo viên'),
                      Tab(icon: Icon(Icons.person_add, size: 18), text: 'Thêm giáo viên'),
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
    final total = _teachers.length;
    final teaching = _teachers.where((s) => _statusOf(s) == 'teaching').length;
        
    final cards = [
      _statCard('Tổng giáo viên', '$total', 'Tất cả hồ sơ',
          const Color(0xFFF97316), const Color(0xFFFFEDD5), Icons.people_alt_rounded),
      _statCard('Đang dạy', '$teaching', 'Hoạt động',
          const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.school_rounded),
       const Color(0xFFFFFBEB), Icons.pause_circle_outline_rounded),
       const Color(0xFFF5F3FF), Icons.workspace_premium_rounded),
    ];

    return LayoutBuilder(
      builder: (ctx, c) {
        final width = c.maxWidth;
        final cardWidth = ((width - 14 * (cards.length - 1)) / cards.length).clamp(160.0, 9999.0);
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
                Text('Không tìm thấy giáo viên nào', style: TextStyle(color: Colors.grey.shade600)),
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
                                hintText: 'Tìm theo tên, mã SV, email, phòng ban...',
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
                      'Phòng ban',
                      _classFilter,
                      {'all': 'Tất cả phòng ban', ...{for (final c in _getUniqueClasses()) c: c}},
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
                        'teaching': 'Đang dạy',
                        
                        
                        'quit': 'Đã nghỉ',
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
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: const [
                    SizedBox(width: 42, child: Text('ID', style: _headerStyle)),
                    Expanded(flex: 3, child: Text('Giáo viên', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('Liên hệ', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('Phòng ban', style: _headerStyle)),
                    SizedBox(width: 110, child: Text('Ngày sinh', style: _headerStyle)),
                    SizedBox(width: 110, child: Text('Trạng thái', style: _headerStyle)),
                    SizedBox(width: 90, child: Text('Hành động', style: _headerStyle, textAlign: TextAlign.center)),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              ...pageRows.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value as Map;
                return _teacherRow(s, idx);
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildPagination(totalPages, start, end),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.3,
  );

  Widget _teacherRow(Map s, int idx) {
    final code = (s['teacher_code'] ?? '').toString();
    final name = (s['full_name'] ?? '').toString();
    final email = (s['email'] ?? '').toString();
    final phone = (s['phone'] ?? '').toString();
    final className = (s['department'] ?? '—').toString();
    final birthDate = _formatDate(s['birth_date']);
    final age = _ageOf(s['birth_date']);
    final statusKey = _statusOf(s);
    final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text('#${s['id'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7280), fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFFBA959)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis),
                      Text(code, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty)
                  Row(children: [
                    Icon(Icons.email_outlined, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(child: Text(email, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ]),
                if (phone.isNotEmpty)
                  Row(children: [
                    Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(fontSize: 12)),
                  ]),
                if (email.isEmpty && phone.isEmpty)
                  Text('—', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(className, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(birthDate, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                if (age.isNotEmpty) Text(age, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusBg(statusKey),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _statusColor(statusKey).withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor(statusKey), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(_statusLabel(statusKey),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(statusKey))),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: _role == 'admin'
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _showEditForm(Map<String, dynamic>.from(s)),
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
                        onTap: () => _deleteTeacher(s['id'] as int),
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
                  )
                : const Center(child: Text('—', style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages, int start, int end) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _filtered.isEmpty
                ? 'Không có kết quả'
                : 'Hiển thị ${start + 1}-$end của ${_filtered.length} giáo viên',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _page > 1 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$_page / $totalPages',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFF97316))),
              ),
              IconButton(
                onPressed: _page < totalPages ? () => setState(() => _page++) : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
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
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: Color(0xFFF97316), size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Tạo hồ sơ giáo viên mới',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Điền các thông tin bên dưới để thêm giáo viên vào hệ thống. Mật khẩu mặc định sẽ là mã giáo viên.',
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
                      controller: TextEditingController(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _inlineFormField(
                      label: 'Mã giáo viên *',
                      hint: 'SV001',
                      icon: Icons.badge,
                      controller: TextEditingController(),
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
                      controller: TextEditingController(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _inlineFormField(
                      label: 'Số điện thoại',
                      hint: '0901234567',
                      icon: Icons.phone,
                      controller: TextEditingController(),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _inlineFormField(
                      label: 'Phòng ban',
                      hint: 'CNTT-K15',
                      icon: Icons.class_,
                      controller: TextEditingController(),
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
                          const Text('Trạng thái: Đang dạy', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF97316), size: 18),
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
