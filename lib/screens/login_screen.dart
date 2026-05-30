import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Vui lòng nhập đầy đủ thông tin';
          _isLoading = false;
        });
        return;
      }

      final result = await ApiService.login(username, password);

      if (result['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('role');
        await prefs.remove('username');
        await prefs.remove('student_id');
        await prefs.remove('full_name');
        await prefs.remove('student_code');
        await prefs.remove('class_name');
        await prefs.remove('gender');
        await prefs.remove('birth_date');
        await prefs.remove('email');
        await prefs.remove('phone');
        await prefs.remove('status');
        await prefs.remove('avatar_url');
        await ApiService.saveToken(result['token'].toString().trim());

        final user = result['user'] as Map<String, dynamic>;
        await prefs.setString('role', user['role']?.toString() ?? '');
        await prefs.setString('username', user['username']?.toString() ?? '');
        await prefs.setString('full_name', user['full_name']?.toString() ?? '');
        await prefs.setString('student_code', user['student_code']?.toString() ?? '');
        await prefs.setString('class_name', user['class_name']?.toString() ?? '');
        await prefs.setString('gender', user['gender']?.toString() ?? '');
        await prefs.setString('birth_date', user['birth_date']?.toString() ?? '');
        await prefs.setString('email', user['email']?.toString() ?? '');
        await prefs.setString('phone', user['phone']?.toString() ?? '');
        await prefs.setString('status', user['status']?.toString() ?? '');
        await prefs.setString('avatar_url', user['avatar_url']?.toString() ?? '');

        final studentId = user['student_id'];
        if (studentId != null) {
          await prefs.setInt('student_id', studentId is int ? studentId : int.tryParse(studentId.toString()) ?? 0);
        } else {
          await prefs.remove('student_id');
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = result['message'] ?? result['error'] ?? 'Sai tài khoản hoặc mật khẩu';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể kết nối server';
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (isWide)
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFF0F172A),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -60,
                          left: -40,
                          child: _glowCircle(const Color(0xFF2563EB).withOpacity(0.20), 220),
                        ),
                        Positioned(
                          bottom: -80,
                          right: -30,
                          child: _glowCircle(const Color(0xFF38BDF8).withOpacity(0.16), 260),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: const [
                              Text(
                                'Student Management',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Quản lý sinh viên, điểm, điểm danh và học phí trong một giao diện hiện đại.',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.school, color: Color(0xFF2563EB), size: 28),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Đăng nhập',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Đăng nhập để tiếp tục vào hệ thống.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 28),
                            TextField(
                              controller: _usernameController,
                              enabled: !_isLoading,
                              decoration: const InputDecoration(
                                labelText: 'Tên đăng nhập',
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              enabled: !_isLoading,
                              onSubmitted: (_) => _login(),
                              decoration: const InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: Icon(Icons.lock),
                              ),
                            ),
                            const SizedBox(height: 14),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              child: _errorMessage.isNotEmpty
                                  ? Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.red.shade100),
                                      ),
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(color: Colors.red.shade700, fontSize: 13.5),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Đăng nhập', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glowCircle(Color color, double size) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
