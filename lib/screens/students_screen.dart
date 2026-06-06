import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List _students = [];
  List _filteredStudents = [];
  bool _isLoading = true;
  String _role = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadRole();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['full_name'] ?? '').toLowerCase();
          final code = (student['student_code'] ?? '').toLowerCase();
          final className = (student['class_name'] ?? '').toLowerCase();
          return name.contains(query) || code.contains(query) || className.contains(query);
        }).toList();
      }
    });
  }

  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _role = prefs.getString('role') ?? '');
  }

  void _loadStudents() async {
    try {
      final data = await ApiService.getStudents();
      setState(() {
        if (data is List) {
          _students = data;
        } else if (data is Map) {
          _students = [data];
        } else {
          _students = [];
        }
        _filteredStudents = List.from(_students);
        _isLoading = false;
      });
    } catch (e) {
      print('Load students error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _deleteStudent(int id) async {
    await ApiService.deleteStudent(id);
    _loadStudents();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    return str.length >= 10 ? str.substring(0, 10) : str;
  }

  void _showForm({Map? student}) {
    final studentCodeController = TextEditingController(text: student?['student_code'] ?? '');
    final fullNameController = TextEditingController(text: student?['full_name'] ?? '');
    final emailController = TextEditingController(text: student?['email'] ?? '');
    final phoneController = TextEditingController(text: student?['phone'] ?? '');
    final classNameController = TextEditingController(text: student?['class_name'] ?? '');
    final birthDateController = TextEditingController(
      text: _formatDate(student?['birth_date']),
    );
    String selectedGender = ['Nam', 'Nữ', 'Khác'].contains(student?['gender'])
        ? student!['gender']
        : 'Nam';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(student == null ? 'Thêm sinh viên' : 'Sửa sinh viên'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: studentCodeController,
                  decoration: const InputDecoration(labelText: 'Mã sinh viên'),
                ),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'Họ tên'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Giới tính',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                    DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                    DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                  ],
                  onChanged: (value) {
                    setStateDialog(() => selectedGender = value!);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Ngày sinh',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    DateTime initial = DateTime(2000);
                    try {
                      if (birthDateController.text.isNotEmpty) {
                        initial = DateTime.parse(birthDateController.text);
                      }
                    } catch (_) {}
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(1970),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      birthDateController.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                TextField(
                  controller: classNameController,
                  decoration: const InputDecoration(labelText: 'Lớp'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'student_code': studentCodeController.text,
                  'full_name': fullNameController.text,
                  'gender': selectedGender,
                  'birth_date': birthDateController.text.isNotEmpty
                      ? birthDateController.text
                      : null,
                  'email': emailController.text,
                  'phone': phoneController.text,
                  'class_name': classNameController.text,
                };

                if (student == null) {
                  await ApiService.addStudent(data);
                } else {
                  await ApiService.updateStudent(student['id'], data);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadStudents();
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: const Text('Quản lý sinh viên'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _role == 'admin'
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm sinh viên'),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade500]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.14), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Danh sách sinh viên', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Tìm kiếm, xem nhanh và quản lý dữ liệu sinh viên theo phong cách dashboard.', style: TextStyle(color: Colors.white70, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip('Tìm theo tên', Colors.blue),
                  _infoChip('Theo mã SV', Colors.teal),
                  _infoChip('Theo lớp', Colors.green),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _onSearchChanged(),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, mã SV, lớp...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isNotEmpty ? 'Không tìm thấy sinh viên' : 'Chưa có sinh viên',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredStudents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              final birthDate = _formatDate(student['birth_date']);
                              final gender = student['gender'] ?? '';
                              final subtitle =
                                  'ID: ${student['id']}  •  MSSV: ${student['student_code']}  •  ${student['class_name']}'
                                  '${gender.isNotEmpty ? ' • $gender' : ''}'
                                  '${birthDate.isNotEmpty ? '\n$birthDate' : ''}';
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.blue.shade50,
                                    child: Text(
                                      (student['full_name'] ?? '?').toString().isNotEmpty ? student['full_name'][0].toString().toUpperCase() : '?',
                                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(student['full_name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(subtitle),
                                  ),
                                  isThreeLine: birthDate.isNotEmpty,
                                  trailing: _role == 'admin'
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () => _showForm(student: student),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteStudent(student['id']),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
