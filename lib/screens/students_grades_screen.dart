import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'grades_screen.dart';

class StudentsGradesScreen extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  final String? role;

  const StudentsGradesScreen({
    super.key,
    this.studentId,
    this.studentName,
    this.role,
  });

  @override
  State<StudentsGradesScreen> createState() => _StudentsGradesScreenState();
}

class _StudentsGradesScreenState extends State<StudentsGradesScreen> {
  List _students = [];
  List _filteredStudents = [];
  List<String> _classOptions = [];
  String _selectedClass = 'Tất cả';
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredStudents = _students.where((student) {
        final name = (student['full_name'] ?? '').toString().toLowerCase();
        final code = (student['student_code'] ?? '').toString().toLowerCase();
        final className = (student['class_name'] ?? '').toString().toLowerCase();
        final matchesQuery = query.isEmpty || name.contains(query) || code.contains(query) || className.contains(query);
        final matchesClass = _selectedClass == 'Tất cả' || className.trim().toUpperCase() == _selectedClass.trim().toUpperCase();
        return matchesQuery && matchesClass;
      }).toList();
    });
  }

  void _onSearchChanged() {
    _applyFilters();
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

        final classes = _students
            .map((s) => (s['class_name'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _classOptions = ['Tất cả', ...classes];

        _filteredStudents = List.from(_students);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    return str.length >= 10 ? str.substring(0, 10) : str;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Danh sách sinh viên & điểm'),
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, mã SV, lớp...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_classOptions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedClass,
                        isExpanded: true,
                        items: _classOptions
                            .map(
                              (className) => DropdownMenuItem<String>(
                                value: className,
                                child: Text(className),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedClass = value);
                          _applyFilters();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có sinh viên',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filteredStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final birthDate = _formatDate(student['birth_date']);
                          final gender = student['gender'] ?? '';
                          final subtitle =
                              '${student['student_code']} • ${student['class_name']}'
                              '${gender.isNotEmpty ? ' • $gender' : ''}'
                              '${birthDate.isNotEmpty ? '\n$birthDate' : ''}';
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.orange.shade50,
                                child: Text(
                                  (student['full_name'] ?? '?').toString().isNotEmpty
                                      ? student['full_name'][0].toString().toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                student['full_name'],
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(subtitle),
                              ),
                              isThreeLine: birthDate.isNotEmpty,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GradesScreen(
                                      studentId: student['id'],
                                      studentName: student['full_name'],
                                      role: widget.role ?? 'teacher',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
