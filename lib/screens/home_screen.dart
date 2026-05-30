import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'account_screen.dart';
import 'attendance_screen.dart';
import 'curriculum_screen.dart';
import 'grades_screen.dart';
import 'students_grades_screen.dart';
import 'students_screen.dart';
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
    if (_role == 'admin') {
      return [
        _MenuTileData(Icons.people, 'Quản lý sinh viên', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsScreen()))),
        _MenuTileData(Icons.school, 'Chương trình khung', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CurriculumScreen(role: _role)))),
        _MenuTileData(Icons.grade, 'Quản lý điểm', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsGradesScreen()))),
        _MenuTileData(Icons.event_available, 'Điểm danh', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()))),
        _MenuTileData(Icons.account_balance_wallet, 'Học phí', Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TuitionScreen()))),
        _MenuTileData(Icons.lock_reset, 'Đổi mật khẩu', Colors.indigo, _changePassword),
      ];
    }

    if (_role == 'teacher') {
      return [
        _MenuTileData(Icons.school, 'Chương trình khung', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CurriculumScreen(role: _role)))),
        _MenuTileData(Icons.grade, 'Nhập điểm', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsGradesScreen()))),
        _MenuTileData(Icons.event_available, 'Điểm danh', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()))),
        _MenuTileData(Icons.lock_reset, 'Đổi mật khẩu', Colors.indigo, _changePassword),
      ];
    }

    return [
      _MenuTileData(Icons.school, 'Chương trình khung', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CurriculumScreen(role: _role)))),
      _MenuTileData(Icons.grade, 'Xem điểm', Colors.blue, () {
        if (_studentId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GradesScreen(
                studentId: _studentId!,
                studentName: _username,
                role: _role,
              ),
            ),
          );
        }
      }),
      _MenuTileData(Icons.account_balance_wallet, 'Học phí của tôi', Colors.deepOrange, () {
        if (_studentId != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TuitionScreen(studentId: _studentId, role: _role)));
        }
      }),
      _MenuTileData(Icons.lock_reset, 'Đổi mật khẩu', Colors.indigo, _changePassword),
      _MenuTileData(Icons.person, 'Thông tin cá nhân', Colors.purple, _openProfile),
    ];
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

            final sidebar = Container(
              width: isWide ? 300 : double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withOpacity(0.18),
                          child: const Icon(Icons.school, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Student Management',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Xin chào, ${_username.isNotEmpty ? _username : _getRoleLabel()}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _getRoleLabel(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _SideMenuTile(data: item);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.35)),
                        ),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.blue.shade700,
                          child: const Icon(Icons.dashboard, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Bảng điều khiển', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text(
                                'Quản lý sinh viên, điểm, điểm danh và học phí trong một nơi.',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Chức năng chính', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.34 : 1.16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return _MenuCard(data: item);
                    },
                  ),
                ],
              ),
            );

            if (isWide) {
              return Row(children: [sidebar, Expanded(child: content)]);
            }

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
  const _SideMenuTile({required this.data});

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
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
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
              const Icon(Icons.chevron_right, color: Colors.white70),
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
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, size: 24, color: data.color),
                ),
                const SizedBox(height: 10),
                Text(
                  data.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
