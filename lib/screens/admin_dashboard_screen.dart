import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'account_screen.dart';
import 'attendance_screen.dart';
import 'schedules_screen.dart';
import 'grades_screen.dart';
import 'students_grades_screen.dart';
import 'students_screen.dart';
import 'teacher_management_screen.dart';
import 'tuition_screen.dart';
import 'curriculum_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _role = '';
  String _username = '';
  bool _isLoading = true;
  int? _studentId;

  String _activePage = 'dashboard';

  // Stats
  int _totalStudents = 0;
  int _totalCourses = 0;
  int _totalSemesters = 0;
  int _totalSchedules = 0;
  int _totalInvoices = 0;
  double _paidAmount = 0;
  double _unpaidAmount = 0;
  Map<String, int> _studentsByClass = {};

  // Recent data
  List<Map<String, dynamic>> _recentStudents = [];
  List<Map<String, dynamic>> _recentInvoices = [];

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
      _username = prefs.getString('full_name') ?? prefs.getString('username') ?? 'Admin';
      _studentId = prefs.getInt('student_id');
      _isLoading = false;
    });
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Students
      final studentsData = await ApiService.getStudents();
      final students = studentsData is List
          ? studentsData.map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      // Courses
      final coursesData = await ApiService.getCourses();
      final courses = coursesData is List
          ? coursesData.map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      // Semesters
      final semestersData = await ApiService.getSemesters();
      final semesters = semestersData is List
          ? semestersData.map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      // Schedules
      final schedulesData = await ApiService.getSchedules();
      final schedules = schedulesData is List
          ? schedulesData.map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      // Invoices
      final invoicesData = await ApiService.getTuitionInvoices();
      final invoices = invoicesData is List
          ? invoicesData.map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      double paid = 0;
      double unpaid = 0;
      for (final inv in invoices) {
        final amount = (inv['amount'] as num?)?.toDouble() ?? 0;
        final status = (inv['status'] ?? '').toString().toLowerCase();
        if (status == 'paid') {
          paid += amount;
        } else {
          unpaid += amount;
        }
      }

      final classGroups = <String, int>{};
      for (final s in students) {
        final c = (s['class_name'] ?? '').toString().trim();
        if (c.isNotEmpty) {
          classGroups[c] = (classGroups[c] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _totalStudents = students.length;
        _totalCourses = courses.length;
        _totalSemesters = semesters.length;
        _totalSchedules = schedules.length;
        _totalInvoices = invoices.length;
        _paidAmount = paid;
        _unpaidAmount = unpaid;
        _studentsByClass = classGroups;
        _recentStudents = students.take(5).toList();
        _recentInvoices = invoices.take(5).toList();
      });
    } catch (_) {}
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

  String _formatVND(double amount) {
    final s = amount.toStringAsFixed(0);
    final reversed = s.split('').reversed.join();
    final withDots = '';
    for (var i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        // ignore: use_string_buffers
        // ignore: prefer_typing_uninitialized_variables
        // string concat handled below
      }
    }
    final buffer = StringBuffer();
    for (var i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(reversed[i]);
    }
    return '${buffer.toString().split('').reversed.join()} đ';
  }

  Widget _buildDashboardPage() {
    if (_role == 'student') {
      return _buildStudentDashboard();
    }
    if (_role == 'teacher') {
      return _buildTeacherDashboard();
    }
    return _buildAdminDashboard();
  }

  Widget _buildAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.waving_hand, color: Color(0xFFF59E0B), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào, $_username!',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Chào mừng bạn đến với hệ thống quản lý sinh viên',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadDashboardData,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Làm mới',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                title: 'Sinh viên',
                value: '$_totalStudents',
                icon: Icons.people,
                color: const Color(0xFF3B82F6),
                bg: const Color(0xFFEFF6FF),
              ),
              _StatCard(
                title: 'Môn học',
                value: '$_totalCourses',
                icon: Icons.book,
                color: const Color(0xFF10B981),
                bg: const Color(0xFFECFDF5),
              ),
              _StatCard(
                title: 'Học kỳ',
                value: '$_totalSemesters',
                icon: Icons.calendar_today,
                color: const Color(0xFFF59E0B),
                bg: const Color(0xFFFFFBEB),
              ),
              _StatCard(
                title: 'Lịch học',
                value: '$_totalSchedules',
                icon: Icons.schedule,
                color: const Color(0xFF8B5CF6),
                bg: const Color(0xFFF5F3FF),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Tổng hóa đơn',
                  value: '$_totalInvoices',
                  icon: Icons.receipt_long,
                  color: const Color(0xFFEC4899),
                  bg: const Color(0xFFFDF2F8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Đã thu',
                  value: _formatVND(_paidAmount),
                  icon: Icons.check_circle,
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Chưa thu',
                  value: _formatVND(_unpaidAmount),
                  icon: Icons.pending_actions,
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                        children: const [
                          Icon(Icons.bar_chart, color: Color(0xFF6366F1)),
                          SizedBox(width: 8),
                          Text('Sinh viên theo lớp',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_studentsByClass.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Chưa có dữ liệu')),
                        )
                      else
                        ..._studentsByClass.entries.map((e) => _ClassBar(
                              className: e.key,
                              count: e.value,
                              total: _totalStudents,
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                        children: const [
                          Icon(Icons.flash_on, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('Truy cập nhanh',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _QuickAction(
                        icon: Icons.people,
                        label: 'Quản lý sinh viên',
                        color: const Color(0xFF3B82F6),
                        onTap: () => setState(() => _activePage = 'students'),
                      ),
                      _QuickAction(
                        icon: Icons.school,
                        label: 'Chương trình khung',
                        color: const Color(0xFF10B981),
                        onTap: () => setState(() => _activePage = 'curriculum'),
                      ),
                      _QuickAction(
                        icon: Icons.grade,
                        label: 'Quản lý điểm',
                        color: const Color(0xFFF59E0B),
                        onTap: () => setState(() => _activePage = 'grades'),
                      ),
                      _QuickAction(
                        icon: Icons.event_available,
                        label: 'Điểm danh',
                        color: const Color(0xFF14B8A6),
                        onTap: () => setState(() => _activePage = 'attendance'),
                      ),
                      _QuickAction(
                        icon: Icons.account_balance_wallet,
                        label: 'Học phí',
                        color: const Color(0xFFEC4899),
                        onTap: () => setState(() => _activePage = 'tuition'),
                      ),
                      _QuickAction(
                        icon: Icons.event,
                        label: 'Lịch học / thi',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => setState(() => _activePage = 'schedules'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
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
                    const Icon(Icons.person_add, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    const Text('Sinh viên mới nhất',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _activePage = 'students'),
                      child: const Text('Xem tất cả →'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_recentStudents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('Chưa có sinh viên')),
                  )
                else
                  ..._recentStudents.map((s) => _RecentStudentRow(student: s)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeCard(
            username: _username,
            subtitle: 'Chào mừng bạn đến với hệ thống quản lý sinh viên',
            gradient: const [Color(0xFF14B8A6), Color(0xFF06B6D4)],
            iconColor: const Color(0xFFF59E0B),
            onRefresh: _loadDashboardData,
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                title: 'Môn học phụ trách',
                value: '$_totalCourses',
                icon: Icons.book_rounded,
                color: const Color(0xFF10B981),
                bg: const Color(0xFFECFDF5),
              ),
              _StatCard(
                title: 'Học kỳ hiện tại',
                value: '$_totalSemesters',
                icon: Icons.event_note_rounded,
                color: const Color(0xFF14B8A6),
                bg: const Color(0xFFECFEFF),
              ),
              _StatCard(
                title: 'Lịch giảng dạy',
                value: '$_totalSchedules',
                icon: Icons.schedule_rounded,
                color: const Color(0xFF8B5CF6),
                bg: const Color(0xFFF5F3FF),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.flash_on, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('Truy cập nhanh',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _QuickAction(
                        icon: Icons.school,
                        label: 'Chương trình khung',
                        color: const Color(0xFF10B981),
                        onTap: () => setState(() => _activePage = 'curriculum'),
                      ),
                      _QuickAction(
                        icon: Icons.grade,
                        label: 'Nhập điểm',
                        color: const Color(0xFFF59E0B),
                        onTap: () => setState(() => _activePage = 'grades'),
                      ),
                      _QuickAction(
                        icon: Icons.event_available,
                        label: 'Điểm danh',
                        color: const Color(0xFF14B8A6),
                        onTap: () => setState(() => _activePage = 'attendance'),
                      ),
                      _QuickAction(
                        icon: Icons.event,
                        label: 'Lịch giảng dạy',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => setState(() => _activePage = 'schedules'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.tips_and_updates, color: Color(0xFF14B8A6)),
                          SizedBox(width: 8),
                          Text('Mẹo nhanh',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TipItem(text: 'Vào Điểm danh để mở phiên mới cho buổi học.'),
                      _TipItem(text: 'Dùng Nhập điểm để cập nhật điểm thành phần và thi.'),
                      _TipItem(text: 'Lịch giảng dạy hiển thị theo tuần và học kỳ.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeCard(
            username: _username,
            subtitle: 'Chào mừng bạn đến với hệ thống quản lý sinh viên',
            gradient: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
            iconColor: const Color(0xFFF59E0B),
            onRefresh: _loadDashboardData,
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                title: 'Chương trình khung',
                value: '$_totalCourses',
                icon: Icons.school_rounded,
                color: const Color(0xFF10B981),
                bg: const Color(0xFFECFDF5),
              ),
              _StatCard(
                title: 'Lịch học',
                value: '$_totalSchedules',
                icon: Icons.schedule_rounded,
                color: const Color(0xFF8B5CF6),
                bg: const Color(0xFFF5F3FF),
              ),
              _StatCard(
                title: 'Hóa đơn của tôi',
                value: '$_totalInvoices',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFEC4899),
                bg: const Color(0xFFFDF2F8),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.flash_on, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('Truy cập nhanh',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _QuickAction(
                        icon: Icons.school,
                        label: 'Chương trình khung',
                        color: const Color(0xFF10B981),
                        onTap: () => setState(() => _activePage = 'curriculum'),
                      ),
                      _QuickAction(
                        icon: Icons.grading,
                        label: 'Kỳ thi / KQHT',
                        color: const Color(0xFFF59E0B),
                        onTap: () => setState(() => _activePage = 'my-grades'),
                      ),
                      _QuickAction(
                        icon: Icons.account_balance_wallet,
                        label: 'Học phí của tôi',
                        color: const Color(0xFFEC4899),
                        onTap: () => setState(() => _activePage = 'tuition'),
                      ),
                      _QuickAction(
                        icon: Icons.event,
                        label: 'Lịch học / thi',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => setState(() => _activePage = 'schedules'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.lightbulb, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('Gợi ý cho bạn',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TipItem(text: 'Vào KQHT để xem điểm thành phần và điểm thi.'),
                      _TipItem(text: 'Theo dõi học phí để biết các khoản phải đóng.'),
                      _TipItem(text: 'Lịch học giúp bạn không bỏ lỡ buổi học nào.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      );

  Widget _buildPageContent() {
    switch (_activePage) {
      case 'dashboard':
        return _buildDashboardPage();
      case 'students':
        return const StudentsScreen(embedded: true);
      case 'teachers':
        return const TeacherManagementScreen(embedded: true);
      case 'curriculum':
        return CurriculumScreen(role: _role, embedded: true);
      case 'grades':
        return StudentsGradesScreen(
          studentId: _studentId,
          studentName: _username,
          role: _role,
        );
      case 'my-grades':
        if (_studentId == null) {
          return AccountScreen(
            profile: {
              'username': _username,
              'full_name': _username,
              'student_code': '—',
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
        return GradesScreen(
          studentId: _studentId!,
          studentName: _username,
          role: _role,
        );
      case 'attendance':
        return const AttendanceScreen();
      case 'tuition':
        return TuitionScreen(role: _role, studentId: _studentId);
      case 'schedules':
        return const SchedulesScreen();
      case 'analytics':
        return _buildAnalyticsPage();
      case 'reports':
        return _buildReportsPage();
      case 'profile':
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
      default:
        return _buildDashboardPage();
    }
  }

  Widget _buildAnalyticsPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 48, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),
            const Text('Phân tích & Thống kê', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Module đang được phát triển. Vui lòng quay lại sau.',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assessment_rounded, size: 48, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 16),
            const Text('Báo cáo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Module đang được phát triển. Vui lòng quay lại sau.',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
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
        return 'Người dùng';
    }
  }

  List<_NavGroup> _getNavItems() {
    if (_role == 'teacher') {
      return const [
        _NavGroup('TỔNG QUAN', [
          _NavItem('dashboard', Icons.dashboard_rounded, 'Tổng quan', 'overview'),
        ]),
        _NavGroup('GIẢNG DẠY', [
          _NavItem('curriculum', Icons.school_rounded, 'Chương trình khung', 'teaching'),
          _NavItem('grades', Icons.grading_rounded, 'Nhập điểm', 'teaching'),
          _NavItem('attendance', Icons.event_available_rounded, 'Điểm danh', 'teaching'),
        ]),
        _NavGroup('THỜI KHÓA BIỂU', [
          _NavItem('schedules', Icons.event_rounded, 'Lịch giảng dạy', 'schedule'),
        ]),
        _NavGroup('HỆ THỐNG', [
          _NavItem('profile', Icons.person_rounded, 'Thông tin cá nhân', 'system'),
        ]),
      ];
    }
    if (_role == 'student') {
      return const [
        _NavGroup('TỔNG QUAN', [
          _NavItem('dashboard', Icons.dashboard_rounded, 'Tổng quan', 'overview'),
        ]),
        _NavGroup('HỌC TẬP', [
          _NavItem('curriculum', Icons.school_rounded, 'Chương trình khung', 'study'),
          _NavItem('my-grades', Icons.grading_rounded, 'Kỳ thi / KQHT', 'study'),
        ]),
        _NavGroup('TÀI CHÍNH & LỊCH', [
          _NavItem('tuition', Icons.account_balance_wallet_rounded, 'Học phí của tôi', 'finance'),
          _NavItem('schedules', Icons.event_rounded, 'Lịch học / thi', 'finance'),
        ]),
        _NavGroup('HỆ THỐNG', [
          _NavItem('profile', Icons.person_rounded, 'Thông tin cá nhân', 'system'),
        ]),
      ];
    }
    // admin
    return const [
      _NavGroup('TỔNG QUAN', [
        _NavItem('dashboard', Icons.dashboard_rounded, 'Tổng quan', 'overview'),
      ]),
      _NavGroup('QUẢN LÝ', [
        _NavItem('students', Icons.people_alt_rounded, 'Quản lý sinh viên', 'manage'),
        _NavItem('teachers', Icons.badge, 'Quản lý giáo viên', 'manage'),
        _NavItem('curriculum', Icons.school_rounded, 'Chương trình khung', 'manage'),
        _NavItem('grades', Icons.grading_rounded, 'Quản lý điểm', 'manage'),
        _NavItem('attendance', Icons.event_available_rounded, 'Điểm danh', 'manage'),
        _NavItem('tuition', Icons.account_balance_wallet_rounded, 'Học phí', 'manage'),
      ]),
      _NavGroup('PHÂN TÍCH', [
        _NavItem('analytics', Icons.bar_chart_rounded, 'Thống kê', 'analytics'),
        _NavItem('reports', Icons.assessment_rounded, 'Báo cáo', 'analytics'),
      ]),
      _NavGroup('HỆ THỐNG', [
        _NavItem('schedules', Icons.event_rounded, 'Lịch học / thi', 'system'),
        _NavItem('profile', Icons.person_rounded, 'Thông tin cá nhân', 'system'),
      ]),
    ];
  }

  String _getPageTitle() {
    for (final group in _getNavItems()) {
      for (final item in group.items) {
        if (item.id == _activePage) return item.label;
      }
    }
    return 'Tổng quan';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1024;
          return Row(
            children: [
              if (isWide)
                _Sidebar(
                  activePage: _activePage,
                  items: _getNavItems(),
                  onPageChanged: (p) => setState(() => _activePage = p),
                  onLogout: _logout,
                  username: _username,
                  role: _getRoleLabel(),
                  onSwitchRole: _role == 'admin' || _role == 'teacher' ? () {} : null,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: _getPageTitle(),
                      username: _username,
                      onMenuTap: () {},
                      onProfileTap: () => setState(() => _activePage = 'profile'),
                      onRefresh: _loadDashboardData,
                      showMenu: !isWide,
                    ),
                    Expanded(child: _buildPageContent()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      drawer: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth < 1024
              ? Drawer(
                  child: _Sidebar(
                    activePage: _activePage,
                    items: _getNavItems(),
                    onPageChanged: (p) {
                      setState(() => _activePage = p);
                      Navigator.pop(context);
                    },
                    onLogout: _logout,
                    username: _username,
                    role: _getRoleLabel(),
                    onSwitchRole: null,
                  ),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String activePage;
  final ValueChanged<String> onPageChanged;
  final VoidCallback onLogout;
  final String username;
  final String role;
  final List<_NavGroup> items;
  final VoidCallback? onSwitchRole;

  const _Sidebar({
    required this.activePage,
    required this.onPageChanged,
    required this.onLogout,
    required this.username,
    required this.role,
    required this.items,
    this.onSwitchRole,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'EduManager',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // User info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final group in items) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                    child: Text(
                      group.label,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...group.items.map((item) => _NavTile(
                        item: item,
                        selected: item.id == activePage,
                        onTap: () => onPageChanged(item.id),
                      )),
                ],
              ],
            ),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Đăng xuất',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String id;
  final IconData icon;
  final String label;
  final String group;
  const _NavItem(this.id, this.icon, this.label, this.group);
}

class _NavGroup {
  final String label;
  final List<_NavItem> items;
  const _NavGroup(this.label, this.items);
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF6366F1) : const Color(0xFF374151),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String username;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;
  final VoidCallback onRefresh;
  final bool showMenu;

  const _TopBar({
    required this.title,
    required this.username,
    required this.onMenuTap,
    required this.onProfileTap,
    required this.onRefresh,
    required this.showMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          if (showMenu)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF374151)),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280)),
            tooltip: 'Làm mới',
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 24,
            color: const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF6366F1),
                    child: Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
          ),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ClassBar extends StatelessWidget {
  final String className;
  final int count;
  final int total;
  const _ClassBar({required this.className, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(className, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('$count SV', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentStudentRow extends StatelessWidget {
  final Map<String, dynamic> student;
  const _RecentStudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final name = (student['full_name'] ?? '').toString();
    final code = (student['student_code'] ?? '').toString();
    final className = (student['class_name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEEF2FF),
            child: Text(
              initial,
              style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                Text('MSSV: $code', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              className,
              style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsPanel extends StatelessWidget {
  final String role;
  const _StudentsPanel({required this.role});

  @override
  Widget build(BuildContext context) {
    return StudentsScreen(embedded: true);
  }
}

class _WelcomeCard extends StatelessWidget {
  final String username;
  final String subtitle;
  final List<Color> gradient;
  final Color iconColor;
  final VoidCallback onRefresh;

  const _WelcomeCard({
    required this.username,
    required this.subtitle,
    required this.gradient,
    required this.iconColor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: gradient.first.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.waving_hand, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $username!',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF374151), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}