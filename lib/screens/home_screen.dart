import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'account_screen.dart';
import 'attendance_screen.dart';
import 'curriculum_screen.dart';
import 'grades_screen.dart';
import 'students_grades_screen.dart';
import 'students_screen.dart';
import 'schedules_screen.dart';
import 'tuition_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _role = '';
  String _username = '';
  bool _isLoading = true;
  int? _studentId;
  int _selectedMenuIndex = 0;
  final GlobalKey<NavigatorState> _contentNavKey = GlobalKey<NavigatorState>();
  final TextEditingController _studentSearchController = TextEditingController();
  List<Map<String, dynamic>> _studentsPanel = [];
  List<Map<String, dynamic>> _studentsPanelFiltered = [];
  bool _studentsPanelLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _role = prefs.getString('role') ?? '';
      _username = prefs.getString('full_name') ?? prefs.getString('username') ?? '';
      _studentId = prefs.getInt('student_id');
      _isLoading = false;
    });
    if (_role == 'admin' || _role == 'teacher') {
      await _loadStudentsPanel();
    }
  }

  Future<void> _loadStudentsPanel() async {
    setState(() => _studentsPanelLoading = true);
    try {
      final data = await ApiService.getStudents();
      final list = data is List ? data.map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _studentsPanel = list;
        _studentsPanelFiltered = List.from(list);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _studentsPanel = [];
        _studentsPanelFiltered = [];
      });
    } finally {
      if (mounted) setState(() => _studentsPanelLoading = false);
    }
  }

  void _filterStudentsPanel(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _studentsPanelFiltered = List.from(_studentsPanel);
      } else {
        _studentsPanelFiltered = _studentsPanel.where((student) {
          final name = (student['full_name'] ?? '').toString().toLowerCase();
          final code = (student['student_code'] ?? '').toString().toLowerCase();
          final className = (student['class_name'] ?? '').toString().toLowerCase();
          return name.contains(q) || code.contains(q) || className.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');
    await prefs.remove('role');
    await prefs.remove('student_id');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _openProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = <String, dynamic>{
      'username': prefs.getString('username') ?? _username,
      'full_name': prefs.getString('full_name') ?? _username,
      'student_code': prefs.getString('student_code') ?? (_studentId?.toString() ?? '—'),
      'class_name': prefs.getString('class_name') ?? '—',
      'gender': prefs.getString('gender') ?? '—',
      'birth_date': prefs.getString('birth_date'),
      'email': prefs.getString('email') ?? '—',
      'phone': prefs.getString('phone') ?? '—',
      'status': prefs.getString('status') ?? 'Đang học',
      'avatar_url': prefs.getString('avatar_url'),
      'role': _role,
    };

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen(profile: profile)));
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Đổi mật khẩu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newController.text.trim() != confirmController.text.trim()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
                      );
                      return;
                    }

                    try {
                      await ApiService.changePassword(
                        currentController.text.trim(),
                        newController.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đổi mật khẩu thành công')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Không đổi được mật khẩu: $e')),
                      );
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<_MenuTileData> _getMenuItems() {
    final list = <_MenuTileData>[];
    if (_role == 'admin') {
      list.addAll([
        _MenuTileData(Icons.dashboard, 'Tổng quan', Colors.purple, () => setState(() => _selectedMenuIndex = 0)),
        _MenuTileData(Icons.people, 'Quản lý sinh viên', Colors.blue, () => setState(() => _selectedMenuIndex = 1)),
        _MenuTileData(Icons.school, 'Chương trình khung', Colors.green, () => setState(() => _selectedMenuIndex = 2)),
        _MenuTileData(Icons.grade, 'Quản lý điểm', Colors.orange, () => setState(() => _selectedMenuIndex = 3)),
        _MenuTileData(Icons.event_available, 'Điểm danh', Colors.teal, () => setState(() => _selectedMenuIndex = 4)),
        _MenuTileData(Icons.account_balance_wallet, 'Học phí', Colors.deepOrange, () => setState(() => _selectedMenuIndex = 5)),
        _MenuTileData(Icons.event, 'Lịch học / thi', Colors.purple, () => setState(() => _selectedMenuIndex = 6)),
        _MenuTileData(Icons.lock_reset, 'Đổi mật khẩu', Colors.indigo, () => setState(() => _selectedMenuIndex = 7)),
      ]);
    } else if (_role == 'teacher') {
      list.addAll([
        _MenuTileData(Icons.dashboard, 'Tổng quan', Colors.purple, () => setState(() => _selectedMenuIndex = 0)),
        _MenuTileData(Icons.school, 'Chương trình khung', Colors.green, () => setState(() => _selectedMenuIndex = 1)),
        _MenuTileData(Icons.grade, 'Nhập điểm', Colors.orange, () => setState(() => _selectedMenuIndex = 2)),
        _MenuTileData(Icons.event_available, 'Điểm danh', Colors.teal, () => setState(() => _selectedMenuIndex = 3)),
        _MenuTileData(Icons.event, 'Lịch học / thi', Colors.purple, () => setState(() => _selectedMenuIndex = 4)),
        _MenuTileData(Icons.lock_reset, 'Đổi mật khẩu', Colors.indigo, () => setState(() => _selectedMenuIndex = 5)),
      ]);
    } else {
      list.addAll([
        _MenuTileData(Icons.dashboard, 'Tổng quan', Colors.purple, () => setState(() => _selectedMenuIndex = 0)),
        _MenuTileData(Icons.school, 'Chương trình khung', Colors.green, () => setState(() => _selectedMenuIndex = 1)),
        _MenuTileData(Icons.grade, 'Xem điểm', Colors.blue, () => setState(() => _selectedMenuIndex = 2)),
        _MenuTileData(Icons.account_balance_wallet, 'Học phí của tôi', Colors.deepOrange, () => setState(() => _selectedMenuIndex = 3)),
        _MenuTileData(Icons.event, 'Lịch học / thi', Colors.purple, () => setState(() => _selectedMenuIndex = 4)),
        _MenuTileData(Icons.lock_reset, 'Đổi mật khẩu', Colors.indigo, () => setState(() => _selectedMenuIndex = 5)),
        _MenuTileData(Icons.person, 'Thông tin cá nhân', Colors.purple, () => setState(() => _selectedMenuIndex = 6)),
      ]);
    }
    return list;
  }

  String _getRoleLabel() {
    switch (_role) {
      case 'admin':
        return 'Quản trị viên';
      case 'teacher':
        return 'Giáo viên';
      case 'student':
        return 'Sinh viên';
      default:
        return 'Tài khoản';
    }
  }

  Widget _buildDashboardHeader(_MenuTileData item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [item.color.withOpacity(0.95), item.color.withOpacity(0.70)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
            child: Icon(item.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Đang mở mục ${item.label.toLowerCase()}.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedContent(int selected, List<_MenuTileData> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SizedBox(
        height: 720,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _buildFeatureWidget(selected),
        ),
      ),
    );
  }

  Widget _buildStudentsPanel() {
    return Container(
      color: const Color(0xFFF7FAFF),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Quản lý sinh viên', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (_role == 'admin')
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsScreen())),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở màn đầy đủ'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: TextField(
              controller: _studentSearchController,
              onChanged: _filterStudentsPanel,
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên, mã SV, lớp...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _studentsPanelLoading
                ? const Center(child: CircularProgressIndicator())
                : _studentsPanelFiltered.isEmpty
                    ? const Center(child: Text('Chưa có sinh viên'))
                    : ListView.separated(
                        itemCount: _studentsPanelFiltered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final student = _studentsPanelFiltered[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text((student['full_name'] ?? '?').toString().isNotEmpty ? student['full_name'][0].toString().toUpperCase() : '?'),
                              ),
                              title: Text((student['full_name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('MSSV: ${student['student_code'] ?? ''} • Lớp: ${student['class_name'] ?? ''}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePanel(String title, String description, IconData icon, Color color) {
    return Container(
      color: const Color(0xFFF7FAFF),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 32, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 32)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurriculumPanel() {
    return CurriculumScreen(role: _role);
  }

  Widget _buildAttendancePanel() {
    return const AttendanceScreen();
  }

  Widget _buildFeatureWidget(int selected) {
    switch (_role) {
      case 'admin':
        switch (selected) {
          case 0:
            return _buildDashboardOverview();
          case 1:
            return _buildStudentsPanel();
          case 2:
            return _buildCurriculumPanel();
          case 3:
            return _buildGradesPanel();
          case 4:
            return _buildAttendancePanel();
          case 5:
            return _buildTuitionPanel();
          case 6:
            return _buildSchedulesPanel();
          case 7:
            return _buildPasswordCard();
        }
        break;
      case 'teacher':
        switch (selected) {
          case 0:
            return _buildDashboardOverview();
          case 1:
            return _buildCurriculumPanel();
          case 2:
            return _buildSimplePanel('Nhập điểm', 'Màn nhập điểm sẽ được hiển thị tại đây.', Icons.grade, Colors.orange);
          case 3:
            return _buildAttendancePanel();
          case 4:
            return _buildSchedulesPanel();
          case 5:
            return _buildPasswordCard();
        }
        break;
      default:
        switch (selected) {
          case 0:
            return _buildDashboardOverview();
          case 1:
            return _buildCurriculumPanel();
          case 2:
            return _buildStudentGradesPanel();
          case 3:
            return _buildTuitionPanel();
          case 4:
            return _buildSchedulesPanel();
          case 5:
            return _buildPasswordCard();
          case 6:
            return _buildProfileCard();
        }
        break;
    }
    return _buildDashboardOverview();
  }

  Widget _buildDashboardOverview() {
    final cards = _getMenuItems().map((e) => _MenuCard(data: e)).toList();
    return Container(
      color: const Color(0xFFF7FAFF),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bảng điều khiển', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Chọn một chức năng bên trái hoặc bấm thẻ bên dưới.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              itemCount: cards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2),
              itemBuilder: (_, i) => cards[i],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesPanel() {
    return const SchedulesScreen();
  }

  Widget _buildStudentGradesPanel() {
    if (_studentId == null) {
      return _buildInfoPlaceholder('Không tìm thấy sinh viên trong phiên đăng nhập.');
    }
    return GradesScreen(studentId: _studentId!, studentName: _username, role: _role);
  }

  Widget _buildGradesPanel() {
    return StudentsGradesScreen(role: _role);
  }

  Widget _buildTuitionPanel() {
    return TuitionScreen(studentId: _studentId, role: _role);
  }

  Widget _buildPasswordCard() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_reset, size: 48, color: Colors.indigo),
            const SizedBox(height: 12),
            const Text('Đổi mật khẩu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Nhấn nút bên dưới để mở hộp thoại đổi mật khẩu.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _changePassword, child: const Text('Đổi mật khẩu')),
          ],
        ),
      ),
    );
  }

  Widget _studentGradesWidget() {
    if (_studentId == null) {
      return _buildInfoPlaceholder('Không tìm thấy mã sinh viên trong phiên đăng nhập.');
    }
    return GradesScreen(studentId: _studentId!, studentName: _username, role: _role);
  }

  Widget _buildProfileCard() {
    return AccountScreen(
      profile: {
        'username': _username,
        'full_name': _username,
        'student_code': _studentId?.toString() ?? '—',
        'class_name': '—',
        'gender': '—',
        'birth_date': null,
        'email': '—',
        'phone': '—',
        'status': 'Đang học',
        'avatar_url': null,
        'role': _role,
      },
    );
  }

  Widget _buildInfoPlaceholder(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = _getMenuItems();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final selected = _selectedMenuIndex.clamp(0, items.length - 1);

            final sidebar = Container(
              width: isWide ? 300 : double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.purple.shade900, Colors.purple.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 24, backgroundColor: Colors.white.withOpacity(0.18), child: const Icon(Icons.school, color: Colors.white)),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Student Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Xin chào, ${_username.isNotEmpty ? _username : _getRoleLabel()}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
                      child: Text(_getRoleLabel(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _SideMenuTile(data: items[index], selected: index == selected),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.35))),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Đăng xuất'),
                      ),
                    ),
                  ),
                ],
              ),
            );

            final content = SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDashboardHeader(items[selected]),
                  const SizedBox(height: 18),
                  _buildSelectedContent(selected, items),
                ],
              ),
            );

            if (isWide) return Row(children: [sidebar, Expanded(child: content)]);
            return Column(children: [sidebar, Expanded(child: content)]);
          },
        ),
      ),
    );
  }
}

class _MenuTileData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _MenuTileData(this.icon, this.label, this.color, this.onTap);
}

class _SideMenuTile extends StatelessWidget {
  final _MenuTileData data;
  final bool selected;
  const _SideMenuTile({required this.data, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Colors.white.withOpacity(0.30) : Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.label,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final _MenuTileData data;
  const _MenuCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: data.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: data.color.withOpacity(0.10)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: data.color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(data.icon, size: 24, color: data.color),
                ),
                const SizedBox(height: 10),
                Text(data.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
