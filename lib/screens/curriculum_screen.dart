import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';

class CurriculumScreen extends StatefulWidget {
  final String role;
  final bool embedded;
  const CurriculumScreen({super.key, required this.role, this.embedded = false});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  // Class selector
  List<String> _availableClasses = [];
  String? _selectedClass;
  // popup state
  OverlayEntry? _classOverlay;
  OverlayEntry? _semesterOverlay;
  final GlobalKey _classBtnKey = GlobalKey();
  final GlobalKey _semesterBtnKey = GlobalKey();

  // Semesters
  List<Map<String, dynamic>> _semesters = [];
  final Map<int, List<Map<String, dynamic>>> _coursesBySemester = {};
  bool _loading = true;
  String? _loadError;

  // Semester form
  final _semesterNameController = TextEditingController();
  final _semesterStartController = TextEditingController();
  final _semesterEndController = TextEditingController();
  String _selectedSemesterStatus = 'active';
  int? _editingSemesterId;

  // Course form
  final _subjectCodeController = TextEditingController();
  final _subjectNameController = TextEditingController();
  final _creditsController = TextEditingController();
  final _theoryController = TextEditingController();
  final _practiceController = TextEditingController();
  String _courseType = 'Bắt buộc';
  String _examForm = 'Lý thuyết';
  String _selectedFacultyForCourse = 'Công nghệ Thông tin';
  String _selectedClassForCourse = '';
  int? _selectedSemesterIdForCourse;
  String _selectedCourseStatus = 'studying';
  int? _editingCourseId;

  // Filters (UI)
  int? _semesterFilterId; // null = all
  String _search = '';
  int _page = 1;
  final int _pageSize = 8;

  bool get _isStudent => widget.role == 'student';
  bool get _canEdit => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _classOverlay?.remove();
    _classOverlay = null;
    _semesterOverlay?.remove();
    _semesterOverlay = null;
    _semesterNameController.dispose();
    _semesterStartController.dispose();
    _semesterEndController.dispose();
    _subjectCodeController.dispose();
    _subjectNameController.dispose();
    _creditsController.dispose();
    _theoryController.dispose();
    _practiceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      String? targetClass;
      List<String> availableClasses = [];

      if (_isStudent) {
        // Student: tự động lấy class_name của bản thân
        final prefs = await SharedPreferences.getInstance();
        targetClass = prefs.getString('class_name')?.trim();
        if (targetClass == null || targetClass.isEmpty) {
          throw Exception('Không tìm thấy lớp của sinh viên trong phiên đăng nhập.');
        }
        availableClasses = [targetClass];
      } else {
        // Admin/Teacher: load danh sách lớp
        try {
          final classesData = await ApiService.getClasses();
          availableClasses = classesData
              .map((e) => (e['name'] ?? '').toString().trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();
          availableClasses.sort();
        } catch (_) {}
        // Fallback mock
        if (availableClasses.isEmpty) {
          availableClasses = ['CNTT01', 'CNTT02', 'ATTT01', 'KTPM01'];
        }
        if (availableClasses.isNotEmpty) {
          targetClass = availableClasses.first;
        }
      }

      if (!mounted) return;
      setState(() {
        _availableClasses = availableClasses;
        _selectedClass = targetClass;
        _loading = false;
      });
      if (targetClass != null) {
        await _loadSemestersForClass();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSemestersForClass() async {
    final isAll = _selectedClass == null;
    setState(() => _loading = true);
    try {
      List semesters;
      try {
        semesters = await ApiService.getSemesters(
          className: isAll ? null : _selectedClass,
        );
      } catch (_) {
        semesters = [];
      }
      // Fallback sang mock khi backend rỗng hoặc lỗi
      if (semesters.isEmpty) {
        semesters = await MockDataService.getCurriculumSemesters(
          className: _selectedClass,
        );
      }
      final semesterList = semesters.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      _coursesBySemester.clear();
      for (final sem in semesterList) {
        final semesterId = sem['id'] as int;
        List courses;
        try {
          courses = await ApiService.getCourses(semesterId: semesterId);
        } catch (_) {
          courses = [];
        }
        if (courses.isEmpty) {
          courses = await MockDataService.getCurriculumCourses(
            semesterId: semesterId,
            className: _selectedClass,
          );
        }
        _coursesBySemester[semesterId] = courses.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      }
      if (!mounted) return;
      setState(() {
        _semesters = semesterList;
        _loading = false;
        if (_semesterFilterId == null && _semesters.isNotEmpty) {
          _semesterFilterId = _semesters.first['id'] as int?;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải học kỳ: $e')));
    }
  }

  void _onClassChanged(String? cls) {
    setState(() {
      _selectedClass = (cls == null || cls == '__all__') ? null : cls;
      _clearSemesterForm();
      _clearCourseForm();
      _semesters = [];
      _coursesBySemester.clear();
      _semesterFilterId = null;
    });
    _loadSemestersForClass();
  }

  Future<void> _saveSemester() async {
    final name = _semesterNameController.text.trim();
    final startDate = _semesterStartController.text.trim();
    final endDate = _semesterEndController.text.trim();
    if (name.isEmpty || startDate.isEmpty || endDate.isEmpty || _selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin học kỳ và chọn lớp')));
      return;
    }
    final payload = {
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'status': _selectedSemesterStatus,
      'class_name': _selectedClass,
    };
    try {
      if (_editingSemesterId == null) {
        await ApiService.addSemester(payload);
      } else {
        await ApiService.updateSemester(_editingSemesterId!, payload);
      }
      _clearSemesterForm();
      await _loadSemestersForClass();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingSemesterId == null ? 'Đã thêm học kỳ' : 'Đã lưu học kỳ')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được học kỳ: $e')));
    }
  }

  void _clearSemesterForm() {
    _editingSemesterId = null;
    _semesterNameController.clear();
    _semesterStartController.clear();
    _semesterEndController.clear();
    _selectedSemesterStatus = 'active';
  }

  Future<void> _deleteSemester(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa học kỳ'),
        content: const Text('Bạn có chắc muốn xóa học kỳ này? Tất cả môn học trong học kỳ cũng sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteSemester(id);
      await _loadSemestersForClass();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa học kỳ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xóa được: $e')));
    }
  }

  void _openAddCourseSheet(int semesterId) {
    _clearCourseForm();
    _selectedSemesterIdForCourse = semesterId;
    _showCourseBottomSheet();
  }

  void _openEditCourseSheet(Map<String, dynamic> course, int semesterId) {
    _editingCourseId = course['id'] as int;
    _selectedSemesterIdForCourse = semesterId;
    _subjectCodeController.text = course['subject_code']?.toString() ?? course['code']?.toString() ?? '';
    _subjectNameController.text = course['subject_name']?.toString() ?? '';
    _creditsController.text = (course['credits'] ?? course['credit'] ?? '').toString();
    _theoryController.text = (course['theory_hours'] ?? course['theory'] ?? '').toString();
    _practiceController.text = (course['practice_hours'] ?? course['practice'] ?? '').toString();
    _courseType = (course['course_type']?.toString().contains('Tự chọn') ?? false) ? 'Tự chọn' : 'Bắt buộc';
    _examForm = _normalizeExamForm(course['exam_form']?.toString());
    final raw = (course['status'] ?? '').toString();
    _selectedCourseStatus = (raw == 'pass' || raw == 'passed' || raw == 'đạt')
        ? 'pass'
        : (raw == 'fail' || raw == 'failed' || raw == 'chưa đạt')
            ? 'fail'
            : 'studying';
    _showCourseBottomSheet();
  }

  void _showCourseBottomSheet() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _buildCourseDialogContent(ctx),
    );
  }

  Widget _buildCourseDialogContent(BuildContext ctx) {
    return StatefulBuilder(
      builder: (ctx2, setSheetState) {
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: MediaQuery.of(ctx2).size.height * 0.04,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFB923C), Color(0xFFF97316)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _editingCourseId == null ? Icons.add_rounded : Icons.edit_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editingCourseId == null ? 'Thêm môn học mới' : 'Sửa môn học',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _editingCourseId == null
                                  ? 'Nhập thông tin chi tiết cho môn học'
                                  : 'Cập nhật thông tin môn học',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)), onPressed: () => Navigator.pop(ctx)),
                    ]),
                    const SizedBox(height: 16),
                    _formSection(
                      icon: Icons.info_outline_rounded,
                      title: 'Thông tin cơ bản',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _labelField(
                                label: 'MÃ MÔN HỌC',
                                child: TextField(
                                  controller: _subjectCodeController,
                                  style: _fieldTextStyle(),
                                  decoration: _fieldDecoration('VD: IT001, MATH101...'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _labelField(
                                label: 'TÊN MÔN HỌC',
                                child: TextField(
                                  controller: _subjectNameController,
                                  style: _fieldTextStyle(),
                                  decoration: _fieldDecoration('Nhập tên đầy đủ của môn học'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _formSection(
                      icon: Icons.schedule_rounded,
                      title: 'Phân bổ thời lượng',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _labelField(
                                label: 'SỐ TÍN CHỈ',
                                child: _stepperField(
                                  controller: _creditsController,
                                  step: 1,
                                  min: 0,
                                  max: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labelField(
                                label: 'GIỜ LÝ THUYẾT',
                                child: _stepperField(
                                  controller: _theoryController,
                                  step: 1,
                                  min: 0,
                                  max: 200,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labelField(
                                label: 'GIỜ THỰC HÀNH',
                                child: _stepperField(
                                  controller: _practiceController,
                                  step: 1,
                                  min: 0,
                                  max: 200,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _formSection(
                      icon: Icons.tune_rounded,
                      title: 'Phân loại & trực thuộc',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _labelField(
                                label: 'KHOA',
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: _dropdownDecoration(),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedFacultyForCourse,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                                      items: const [
                                        DropdownMenuItem(value: 'Công nghệ Thông tin', child: Text('Công nghệ Thông tin')),
                                      ],
                                      onChanged: (v) => setSheetState(() => _selectedFacultyForCourse = v ?? 'Công nghệ Thông tin'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labelField(
                                label: 'LỚP ÁP DỤNG',
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: _dropdownDecoration(),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedClassForCourse.isNotEmpty
                                          ? _selectedClassForCourse
                                          : (_availableClasses.isNotEmpty ? _availableClasses.first : null),
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                                      items: _availableClasses.isEmpty
                                          ? const [DropdownMenuItem(value: '', child: Text('-- Chọn lớp --'))]
                                          : _availableClasses
                                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                              .toList(),
                                      onChanged: _availableClasses.isEmpty
                                          ? null
                                          : (v) => setSheetState(() => _selectedClassForCourse = v ?? _selectedClassForCourse),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _labelField(
                                label: 'KỲ HỌC',
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: _dropdownDecoration(),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _selectedSemesterIdForCourse != null &&
                                              _semesters.any((s) => s['id'] == _selectedSemesterIdForCourse)
                                          ? _selectedSemesterIdForCourse
                                          : (_semesters.isNotEmpty ? _semesters.first['id'] as int : null),
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                                      items: _semesters.isEmpty
                                          ? const [DropdownMenuItem(value: 0, child: Text('-- Chọn kỳ học --'))]
                                          : _semesters
                                              .map((s) => DropdownMenuItem<int>(
                                                    value: s['id'] as int,
                                                    child: Text(s['name']?.toString() ?? 'Kỳ học'),
                                                  ))
                                              .toList(),
                                      onChanged: _semesters.isEmpty
                                          ? null
                                          : (v) {
                                              if (v != null && v != 0) setSheetState(() => _selectedSemesterIdForCourse = v);
                                            },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labelField(
                                label: 'HÌNH THỨC THI',
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: _dropdownDecoration(),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _examForm,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                                      items: const [
                                        DropdownMenuItem(value: 'Lý thuyết', child: Text('Lý thuyết')),
                                        DropdownMenuItem(value: 'Thực hành', child: Text('Thực hành')),
                                        DropdownMenuItem(value: 'Thực hành + Lý thuyết', child: Text('Thực hành + Lý thuyết')),
                                        DropdownMenuItem(value: 'Đồ án', child: Text('Đồ án')),
                                        DropdownMenuItem(value: 'Tiểu luận', child: Text('Tiểu luận')),
                                      ],
                                      onChanged: (v) => setSheetState(() => _examForm = v ?? 'Lý thuyết'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: _courseType == 'Bắt buộc' ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _courseType == 'Bắt buộc' ? const Color(0xFFFED7AA) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _courseType == 'Bắt buộc' ? const Color(0xFFF97316) : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _courseType == 'Bắt buộc' ? Icons.lock_rounded : Icons.lock_open_rounded,
                              color: _courseType == 'Bắt buộc' ? Colors.white : const Color(0xFF9CA3AF),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Môn học bắt buộc',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Sinh viên phải học và hoàn thành môn này',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _courseType == 'Bắt buộc',
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFFF97316),
                            inactiveTrackColor: const Color(0xFFE5E7EB),
                            onChanged: (v) => setSheetState(() {
                              _courseType = v ? 'Bắt buộc' : 'Tự chọn';
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              foregroundColor: const Color(0xFF374151),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _saveCourseAndClose(ctx),
                            icon: Icon(
                              _editingCourseId == null ? Icons.add_rounded : Icons.save_rounded,
                              size: 18,
                            ),
                            label: Text(_editingCourseId == null ? 'Thêm môn học' : 'Lưu thay đổi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF97316),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _formSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: const Color(0xFFF97316)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9A3412),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _labelField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  TextStyle _fieldTextStyle() => const TextStyle(
        fontSize: 14,
        color: Color(0xFF111827),
        fontWeight: FontWeight.w600,
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
        ),
      );

  BoxDecoration _dropdownDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      );

  String _normalizeExamForm(String? raw) {
    const allowed = {
      'Lý thuyết',
      'Thực hành',
      'Thực hành + Lý thuyết',
      'Đồ án',
      'Tiểu luận',
    };
    final s = (raw ?? '').trim();
    if (allowed.contains(s)) return s;
    final lower = s.toLowerCase();
    if (lower.contains('lý thuyết') && lower.contains('thực hành')) return 'Thực hành + Lý thuyết';
    if (lower.contains('thực hành')) return 'Thực hành';
    if (lower.contains('đồ án')) return 'Đồ án';
    if (lower.contains('tiểu luận')) return 'Tiểu luận';
    if (lower.contains('trắc nghiệm') || lower.contains('vấn đáp') || lower.contains('tự luận') || lower.contains('lý thuyết')) {
      return 'Lý thuyết';
    }
    return 'Lý thuyết';
  }

  Widget _stepperField({
    required TextEditingController controller,
    int min = 0,
    int max = 999,
    int step = 1,
  }) {
    int parse(String s) => int.tryParse(s) ?? 0;
    void setValue(int v) {
      final clamped = v.clamp(min, max);
      controller.text = clamped.toString();
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _stepperButton(
            icon: Icons.remove_rounded,
            onTap: () => setValue(parse(controller.text) - step),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: _fieldTextStyle(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                  fontStyle: FontStyle.italic,
                ),
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && (n < min || n > max)) {
                  setValue(n);
                }
              },
            ),
          ),
          _stepperButton(
            icon: Icons.add_rounded,
            onTap: () => setValue(parse(controller.text) + step),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFFFF7ED),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFFF97316), size: 20),
        ),
      ),
    );
  }

  Future<void> _saveCourseAndClose(BuildContext sheetCtx) async {
    final semesterId = _selectedSemesterIdForCourse;
    final subjectName = _subjectNameController.text.trim();
    final subjectCode = _subjectCodeController.text.trim();
    final credits = int.tryParse(_creditsController.text.trim()) ?? 0;

    if (semesterId == null || subjectName.isEmpty || subjectCode.isEmpty || credits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin môn học')));
      return;
    }

    // Validate semester exists in current list
    final semesterExists = _semesters.any((s) => s['id'] == semesterId);
    if (!semesterExists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Học kỳ không hợp lệ. Vui lòng chọn lại học kỳ.'),
        backgroundColor: Colors.red,
      ));
      await _loadSemestersForClass();
      return;
    }

    final className = _selectedClassForCourse.isNotEmpty
        ? _selectedClassForCourse
        : (_selectedClass ?? '');
    if (className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng chọn lớp áp dụng cho môn học'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final payload = {
      'semester_id': semesterId,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'class_name': className,
      'faculty': _selectedFacultyForCourse,
      'credits': credits,
      'theory_hours': int.tryParse(_theoryController.text.trim()) ?? 0,
      'practice_hours': int.tryParse(_practiceController.text.trim()) ?? 0,
      'course_type': _courseType,
      'exam_form': _examForm,
      'status': _selectedCourseStatus,
    };

    try {
      if (_editingCourseId == null) {
        await ApiService.addCourse(payload);
      } else {
        await ApiService.updateCourse(_editingCourseId!, payload);
      }
      // Đóng bottom sheet trước khi reload
      if (!sheetCtx.mounted) return;
      Navigator.pop(sheetCtx);
      _clearCourseForm();
      await _loadSemestersForClass();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingCourseId == null ? 'Đã thêm môn học' : 'Đã lưu môn học')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được: $e')));
    }
  }

  void _clearCourseForm() {
    _editingCourseId = null;
    _subjectCodeController.clear();
    _subjectNameController.clear();
    _creditsController.clear();
    _theoryController.clear();
    _practiceController.clear();
    _courseType = 'Bắt buộc';
    _examForm = 'Lý thuyết';
    _selectedFacultyForCourse = 'Công nghệ Thông tin';
    _selectedClassForCourse = _selectedClass ?? '';
    _selectedCourseStatus = 'studying';
    _selectedSemesterIdForCourse = null;
  }

  void _editSemester(Map<String, dynamic> semester) {
    _editingSemesterId = semester['id'] as int;
    _semesterNameController.text = semester['name']?.toString() ?? semester['semester_name']?.toString() ?? '';
    _semesterStartController.text = _formatDate(semester['start_date']);
    _semesterEndController.text = _formatDate(semester['end_date']);
    _selectedSemesterStatus = semester['status']?.toString() == 'finished' ? 'finished' : 'active';
    setState(() {});
  }

  Future<void> _deleteCourse(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa môn học'),
        content: const Text('Bạn có chắc muốn xóa môn học này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteCourse(id);
      await _loadSemestersForClass();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa môn học')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xóa được: $e')));
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is DateTime) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    final str = date.toString().trim();
    if (str.length >= 10) return str.substring(0, 10);
    return str;
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final parts = controller.text.isNotEmpty ? controller.text.split('-') : [];
    final initial = parts.length == 3
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      controller.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    if (_loading && _selectedClass != null && _semesters.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $_loadError', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final padding = EdgeInsets.symmetric(horizontal: embedded ? 20 : 16);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToolbarRow(),
                  const SizedBox(height: 14),
                  _buildActiveSemesterBanner(),
                  const SizedBox(height: 18),
                  _buildSemesterGrid(),
                  const SizedBox(height: 22),
                  _buildCoursesSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildToolbarRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return _buildFiltersAndActionsNew();
      },
    );
  }

  Widget _buildFiltersAndActionsNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, color: Color(0xFFF97316), size: 18),
            const SizedBox(width: 6),
            const Text('BỘ LỌC',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF9A3412),
                )),
            const Spacer(),
            if (_canEdit)
              _actionButton(
                icon: Icons.event_note_rounded,
                label: 'Thêm học kỳ',
                bg: const Color(0xFFFFF7ED),
                fg: const Color(0xFFF97316),
                border: const Color(0xFFFED7AA),
                onTap: _showAddSemesterSheet,
              ),
            if (_canEdit) const SizedBox(width: 8),
            if (_canEdit)
              _actionButton(
                icon: Icons.menu_book_rounded,
                label: 'Thêm môn học',
                bg: const Color(0xFFF97316),
                fg: Colors.white,
                border: const Color(0xFFF97316),
                onTap: _semesterFilterId != null
                    ? () => _openAddCourseSheet(_semesterFilterId!)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth > 900;
            if (!isWide) {
              return Column(
                children: [
                  if (!_isStudent) ...[
                    _popupDropdownButton(
                      btnKey: _classBtnKey,
                      icon: Icons.class_,
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      label: 'LỚP HỌC',
                      value: _selectedClass ?? 'Tất cả lớp',
                      accentColor: const Color(0xFFF97316),
                      onTap: _toggleClassOverlay,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _popupDropdownButton(
                    btnKey: _semesterBtnKey,
                    icon: Icons.school_outlined,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF7C3AED),
                    label: 'KỲ HỌC',
                    value: _semesters.isEmpty
                        ? 'Chưa có kỳ học'
                        : (_semesterFilterId == null
                            ? 'Tất cả kỳ học'
                            : (_semesters.firstWhere(
                                  (s) => s['id'] == _semesterFilterId,
                                  orElse: () => {'name': 'Kỳ ${_semesterFilterId}'},
                                )['name'] ??
                                'Kỳ $_semesterFilterId')),
                    accentColor: const Color(0xFF7C3AED),
                    onTap: _toggleSemesterOverlay,
                  ),
                  const SizedBox(height: 12),
                  _standaloneSearchField(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isStudent) ...[
                  Expanded(
                    flex: 4,
                    child: _popupDropdownButton(
                      btnKey: _classBtnKey,
                      icon: Icons.class_,
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      label: 'LỚP HỌC',
                      value: _selectedClass ?? 'Tất cả lớp',
                      accentColor: const Color(0xFFF97316),
                      onTap: _toggleClassOverlay,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 4,
                  child: _popupDropdownButton(
                    btnKey: _semesterBtnKey,
                    icon: Icons.school_outlined,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF7C3AED),
                    label: 'KỲ HỌC',
                    value: _semesters.isEmpty
                        ? 'Chưa có kỳ học'
                        : (_semesterFilterId == null
                            ? 'Tất cả kỳ học'
                            : (_semesters.firstWhere(
                                  (s) => s['id'] == _semesterFilterId,
                                  orElse: () => {'name': 'Kỳ ${_semesterFilterId}'},
                                )['name'] ??
                                'Kỳ $_semesterFilterId')),
                    accentColor: const Color(0xFF7C3AED),
                    onTap: _toggleSemesterOverlay,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _standaloneSearchField(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _popupDropdownButton({
    required GlobalKey btnKey,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      key: btnKey,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 44, 14),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 56,
                top: 6,
                child: IgnorePointer(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _standaloneSearchField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 44, 14),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.search, size: 17, color: Color(0xFFF97316)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _search = v.toLowerCase().trim();
                      _page = 1;
                    }),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên kỳ học...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 56,
            top: 6,
            child: IgnorePointer(
              child: Text(
                'TÌM KIẾM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleClassOverlay() {
    if (_classOverlay != null) {
      _classOverlay!.remove();
      _classOverlay = null;
      return;
    }
    _semesterOverlay?.remove();
    _semesterOverlay = null;
    _classOverlay = _showPopupOverlay(
      anchorKey: _classBtnKey,
      maxHeight: 320,
      child: _classPopupList(),
    );
  }

  void _toggleSemesterOverlay() {
    if (_semesterOverlay != null) {
      _semesterOverlay!.remove();
      _semesterOverlay = null;
      return;
    }
    _classOverlay?.remove();
    _classOverlay = null;
    _semesterOverlay = _showPopupOverlay(
      anchorKey: _semesterBtnKey,
      maxHeight: 360,
      child: _semesterPopupList(),
    );
  }

  OverlayEntry _showPopupOverlay({
    required GlobalKey anchorKey,
    required Widget child,
    required double maxHeight,
  }) {
    final renderObject = anchorKey.currentContext?.findRenderObject();
    final overlayState = Overlay.of(context, rootOverlay: false);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  entry.remove();
                  if (identical(entry, _classOverlay)) _classOverlay = null;
                  if (identical(entry, _semesterOverlay)) _semesterOverlay = null;
                },
                child: const SizedBox.expand(),
              ),
            ),
            if (renderObject is RenderBox)
              Builder(builder: (ctx) {
                final topLeft = renderObject.localToGlobal(Offset.zero);
                final size = renderObject.size;
                final mediaH = MediaQuery.of(ctx).size.height;
                final showBelow = topLeft.dy + size.height + 8 + maxHeight + 60 < mediaH;
                return Positioned(
                  left: topLeft.dx,
                  top: showBelow ? topLeft.dy + size.height + 8 : null,
                  bottom: showBelow ? null : mediaH - topLeft.dy + 8,
                  width: size.width,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: child,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
    overlayState.insert(entry);
    return entry;
  }

  Widget _classPopupList() {
    final selected = _selectedClass;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        _popupListItem(
          label: 'Tất cả lớp',
          subtitle: '${_availableClasses.length} lớp',
          icon: Icons.class_,
          iconBg: const Color(0xFFEEF2FF),
          iconColor: const Color(0xFF4F46E5),
          selected: selected == null,
          onTap: () {
            setState(() {
              _selectedClass = null;
              _classOverlay?.remove();
              _classOverlay = null;
            });
            _onClassChanged(null);
          },
        ),
        for (final c in _availableClasses)
          _popupListItem(
            label: c,
            icon: Icons.class_outlined,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4F46E5),
            selected: selected == c,
            onTap: () {
              setState(() {
                _classOverlay?.remove();
                _classOverlay = null;
              });
              _onClassChanged(c);
            },
          ),
      ],
    );
  }

  Widget _semesterPopupList() {
    final selected = _semesterFilterId;
    final list = _semesters
        .where((s) => _search.isEmpty ||
            (s['name'] ?? s['semester_name'] ?? '').toString().toLowerCase().contains(_search))
        .toList();
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        _popupListItem(
          label: 'Tất cả kỳ học',
          subtitle: '${_semesters.length} kỳ',
          icon: Icons.all_inclusive_rounded,
          iconBg: const Color(0xFFF5F3FF),
          iconColor: const Color(0xFF7C3AED),
          selected: selected == null,
          onTap: () {
            setState(() {
              _semesterFilterId = null;
              _semesterOverlay?.remove();
              _semesterOverlay = null;
              _page = 1;
            });
          },
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Text(
              'Không có kỳ học nào',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ),
        for (final s in list)
          _popupListItem(
            label: (s['name'] ?? s['semester_name'] ?? 'Kỳ ${s['id']}').toString(),
            subtitle:
                '${_formatDate(s['start_date'])} → ${_formatDate(s['end_date'])}',
            icon: Icons.school_outlined,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            selected: selected == s['id'],
            onTap: () {
              setState(() {
                _semesterFilterId = s['id'] as int;
                _semesterOverlay?.remove();
                _semesterOverlay = null;
                _page = 1;
              });
            },
          ),
      ],
    );
  }

  Widget _popupListItem({
    required String label,
    String? subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFFF7ED) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Radio dot
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? const Color(0xFFF97316) : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  color: selected ? const Color(0xFFF97316) : Colors.white,
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? const Color(0xFFC2410C) : const Color(0xFF111827),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 18, color: Color(0xFFF97316)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    final effBg = disabled ? const Color(0xFFF3F4F6) : bg;
    final effFg = disabled ? const Color(0xFF9CA3AF) : fg;
    final effBorder = disabled ? const Color(0xFFE5E7EB) : border;
    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: Material(
        color: effBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: effBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: effFg, size: 18),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: effFg, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.menu_book_rounded, color: Color(0xFFF97316), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Chương trình khung',
                    style: TextStyle(color: Color(0xFF1F2937), fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Quản lý các kỳ học và môn học trong chương trình đào tạo',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassAndFilterRow() {
    final isStudent = _isStudent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (isStudent)
            _pillBadge(
              icon: Icons.class_,
              iconBg: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF4F46E5),
              text: 'Lớp: ${_selectedClass ?? "—"}',
              textColor: const Color(0xFF4F46E5),
              bg: const Color(0xFFEEF2FF),
              border: const Color(0xFFE0E7FF),
            )
          else
_filterDropdown(
            icon: Icons.class_,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4F46E5),
            label: 'CHỌN LỚP',
            value: _selectedClass,
            opts: {
              '__all__': 'Tất cả lớp',
              for (final c in _availableClasses) c: c,
            },
            onChanged: _onClassChanged,
            width: 240,
          ),
          _filterDropdown(
            icon: Icons.school_outlined,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            label: 'CHỌN KỲ HỌC',
            value: _semesterFilterId?.toString(),
            opts: {
              '__all__': 'Tất cả kỳ học',
              for (final s in _semesters)
                s['id'].toString(): (s['name'] ?? s['semester_name'] ?? 'Kỳ ${s['id']}').toString(),
            },
            onChanged: (v) {
              setState(() {
                _semesterFilterId = (v == null || v == '__all__') ? null : int.tryParse(v);
                _page = 1;
              });
            },
            width: 260,
          ),
          _searchField(
            icon: Icons.search,
            iconBg: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFF97316),
            label: 'TÌM KIẾM',
            hint: 'Nhập tên kỳ học hoặc niên khóa...',
            width: 260,
            onChanged: (v) => setState(() {
              _search = v.toLowerCase().trim();
              _page = 1;
            }),
          ),
        ],
      ),
    );
  }

  Widget _pillBadge({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String text,
    required Color textColor,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
        ],
      ),
    );
  }

  Widget _searchField({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String hint,
    required double width,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: width,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 36, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: onChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 56,
            top: 6,
            child: IgnorePointer(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String? value,
    required Map<String, String> opts,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    final selectedLabel = (value != null && opts.containsKey(value)) ? opts[value]! : null;
    return Container(
      width: width,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 36, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      isDense: true,
                      icon: const SizedBox.shrink(),
                      selectedItemBuilder: (context) => opts.values
                          .map((t) => Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 0),
                                  child: Text(
                                    t,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                      items: opts.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(icon, size: 16, color: iconColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          e.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF374151),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 56,
            top: 6,
            child: IgnorePointer(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: const IgnorePointer(
              child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Color(0xFF6B7280)),
            ),
          ),
          if (selectedLabel == null)
            Positioned(
              left: 56,
              top: 16,
              child: IgnorePointer(
                child: Text(
                  'Chọn...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSemesterBanner() {
    if (_semesters.isEmpty) return const SizedBox.shrink();
    final activeIdx = _semesters.indexWhere((s) => s['status']?.toString() == 'active');
    final idx = activeIdx >= 0 ? activeIdx : 0;
    final active = _semesters[idx];
    final courses = _coursesBySemester[active['id']] ?? [];
    final totalCredits = courses.fold<int>(0, (sum, c) => sum + ((c['credits'] ?? c['credit'] ?? 0) as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bolt, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kỳ học đang hoạt động',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  (active['name'] ?? active['semester_name'] ?? 'Kỳ hiện tại').toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(active['start_date'])} → ${_formatDate(active['end_date'])} • ${courses.length} môn • $totalCredits tín chỉ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        ],
      ),
    );
  }

  Widget _buildSemesterGrid() {
    if (_selectedClass == null) {
      return _emptyHint('Vui lòng chọn lớp học để xem chương trình khung.');
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    }
    final filtered = _semesters.where((s) {
      final name = (s['name'] ?? s['semester_name'] ?? '').toString().toLowerCase();
      return _search.isEmpty || name.contains(_search);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.school, color: Color(0xFFF97316), size: 20),
            const SizedBox(width: 8),
            Text('DANH SÁCH KỲ HỌC (${filtered.length})',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF374151), letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _emptyHint('Chưa có kỳ học nào cho lớp này.')
        else
          LayoutBuilder(builder: (ctx, c) {
            final cross = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
            final cardWidth = (c.maxWidth - 14 * (cross - 1)) / cross;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: filtered.map((s) => SizedBox(width: cardWidth, child: _semesterCard(s))).toList(),
            );
          }),
      ],
    );
  }

  Widget _semesterCard(Map<String, dynamic> s) {
    final id = s['id'] as int;
    final isActive = s['status']?.toString() == 'active';
    final isFinished = s['status']?.toString() == 'finished';
    final courses = _coursesBySemester[id] ?? [];
    final totalCredits = courses.fold<int>(0, (sum, c) => sum + ((c['credits'] ?? c['credit'] ?? 0) as int));
    final name = (s['name'] ?? s['semester_name'] ?? 'Kỳ học').toString();

    final dotColor = isActive
        ? const Color(0xFF10B981)
        : (isFinished ? Colors.grey : const Color(0xFFF59E0B));
    final bg = isActive
        ? const Color(0xFFECFDF5)
        : (isFinished ? const Color(0xFFF3F4F6) : const Color(0xFFFFFBEB));
    final border = isActive
        ? const Color(0xFFA7F3D0)
        : (isFinished ? const Color(0xFFE5E7EB) : const Color(0xFFFDE68A));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.event_note, color: dotColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_canEdit)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey.shade600, size: 18),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'edit') {
                      _editSemester(s);
                      _showAddSemesterSheet();
                    } else if (v == 'delete') {
                      _deleteSemester(id);
                    } else if (v == 'add_course') {
                      _openAddCourseSheet(id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'add_course', child: Text('Thêm môn học')),
                    PopupMenuItem(value: 'edit', child: Text('Sửa kỳ học')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa kỳ học')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(isActive ? 'Đang hoạt động' : (isFinished ? 'Đã kết thúc' : 'Tạm dừng'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dotColor)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.calendar_today, size: 12, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_formatDate(s['start_date'])} → ${_formatDate(s['end_date'])}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.book_outlined, size: 12, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text('${courses.length} môn học • $totalCredits tín chỉ',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.touch_app, size: 12, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              const Expanded(
                  child: Text('Nhấn để lọc môn học',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
              InkWell(
                onTap: () => setState(() => _semesterFilterId = id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_semesterFilterId == id) ? const Color(0xFFFFEDD5) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Text(
                    _semesterFilterId == id ? 'Đang lọc' : 'Xem môn',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF97316)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _allCourses() {
    final out = <Map<String, dynamic>>[];
    _coursesBySemester.forEach((semId, list) {
      final sem = _semesters.firstWhere(
        (s) => s['id'] == semId,
        orElse: () => <String, dynamic>{},
      );
      final semName = (sem['name'] ?? sem['semester_name'] ?? '').toString();
      for (final c in list) {
        out.add({...c, '_semester_id': semId, '_semester_name': semName});
      }
    });
    return out;
  }

  List<Map<String, dynamic>> _filterCourses(List<Map<String, dynamic>> all) {
    return all.where((c) {
      final code = (c['subject_code'] ?? c['code'] ?? '').toString().toLowerCase();
      final name = (c['subject_name'] ?? c['name'] ?? '').toString().toLowerCase();
      final semId = c['_semester_id'];
      final matchSearch = _search.isEmpty || code.contains(_search) || name.contains(_search);
      final matchSemester = _semesterFilterId == null || semId == _semesterFilterId;
      return matchSearch && matchSemester;
    }).toList();
  }

  Widget _buildCoursesSection() {
    if (_selectedClass == null) return const SizedBox.shrink();
    if (_loading) return const SizedBox.shrink();
    final all = _allCourses();
    final filtered = _filterCourses(all);

    final required = all.where((c) => !(c['course_type']?.toString().contains('Tự chọn') ?? false)).toList();
    final elective = all.where((c) => c['course_type']?.toString().contains('Tự chọn') ?? false).toList();
    int credits(List<Map<String, dynamic>> list) =>
        list.fold<int>(0, (sum, c) => sum + ((c['credits'] ?? c['credit'] ?? 0) as int));
    final totalCredits = credits(all);
    final reqCredits = credits(required);
    final elecCredits = credits(elective);
    final totalTheory = all.fold<int>(0, (sum, c) => sum + ((c['theory_hours'] ?? c['theory'] ?? 0) as int));
    final totalPractice = all.fold<int>(0, (sum, c) => sum + ((c['practice_hours'] ?? c['practice'] ?? 0) as int));
    final totalHours = totalTheory + totalPractice;

    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final start = (_page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageRows = filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (ctx, c) {
          final items = [
            ('Tổng tín chỉ', '$totalCredits', 'Tín chỉ toàn khóa', const Color(0xFFF97316), const Color(0xFFFFEDD5), Icons.calculate_outlined),
            ('Bắt buộc', '${required.length}', '$reqCredits TC', const Color(0xFF10B981), const Color(0xFFECFDF5), Icons.assignment_turned_in_outlined),
            ('Tự chọn', '${elective.length}', '$elecCredits TC', const Color(0xFF8B5CF6), const Color(0xFFF5F3FF), Icons.tune),
            ('Tổng giờ học', '$totalHours', '$totalTheory LT + $totalPractice TH', const Color(0xFF3B82F6), const Color(0xFFEFF6FF), Icons.schedule),
          ];
          final w = ((c.maxWidth - 12 * 3) / 4).clamp(150.0, 9999.0);
          return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map((it) => SizedBox(width: w, child: _miniStat(it.$1, it.$2, it.$3, it.$4, it.$5, it.$6))).toList());
        }),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.book, color: Color(0xFFF97316), size: 20),
            const SizedBox(width: 8),
            Text('DANH SÁCH MÔN HỌC (${filtered.length})',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF374151), letterSpacing: 0.5)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 90, child: Text('MÃ MH', style: _hStyle)),
                    Expanded(flex: 3, child: Text('TÊN MÔN HỌC', style: _hStyle)),
                    SizedBox(width: 60, child: Text('TÍN CHỈ', style: _hStyle, textAlign: TextAlign.center)),
                    SizedBox(width: 60, child: Text('LÝ THUYẾT', style: _hStyle, textAlign: TextAlign.center)),
                    SizedBox(width: 60, child: Text('THỰC HÀNH', style: _hStyle, textAlign: TextAlign.center)),
                    SizedBox(width: 110, child: Text('HÌNH THỨC THI', style: _hStyle, textAlign: TextAlign.center)),
                    SizedBox(width: 90, child: Text('LOẠI', style: _hStyle, textAlign: TextAlign.center)),
                    SizedBox(width: 90, child: Text('THAO TÁC', style: _hStyle, textAlign: TextAlign.center)),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              if (pageRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(child: Text('Chưa có môn học nào', style: TextStyle(color: Colors.grey.shade500))),
                )
              else
                ...pageRows.asMap().entries.map((e) => _courseRow(e.value, e.key)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _paginationRow(filtered.length, start, end, totalPages),
      ],
    );
  }

  static const _hStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Color(0xFF6B7280),
    letterSpacing: 0.4,
  );

  Widget _miniStat(String title, String value, String sub, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18)),
            const Spacer(),
          ]),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _courseRow(Map<String, dynamic> c, int idx) {
    final code = (c['subject_code'] ?? c['code'] ?? '—').toString();
    final name = (c['subject_name'] ?? c['name'] ?? '').toString();
    final credits = (c['credits'] ?? c['credit'] ?? 0).toString();
    final theory = (c['theory_hours'] ?? c['theory'] ?? 0).toString();
    final practice = (c['practice_hours'] ?? c['practice'] ?? 0).toString();
    final exam = (c['exam_form'] ?? 'Tự luận').toString();
    final type = (c['course_type'] ?? 'Bắt buộc').toString();
    final isElective = type.contains('Tự chọn');

    Color examBg, examFg;
    if (exam.contains('Trắc')) {
      examBg = const Color(0xFFEFF6FF);
      examFg = const Color(0xFF2563EB);
    } else if (exam.contains('Thực') || exam.contains('Đồ')) {
      examBg = const Color(0xFFFEF3C7);
      examFg = const Color(0xFFB45309);
    } else {
      examBg = const Color(0xFFECFDF5);
      examFg = const Color(0xFF047857);
    }

    return Container(
      decoration: BoxDecoration(
        color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(6)),
              child: Text(code,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFF97316))),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis),
                if ((c['_semester_name'] ?? '').toString().isNotEmpty)
                  Text(c['_semester_name'].toString(),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
              child: Text(credits,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF4F46E5))),
            ),
          ),
          SizedBox(
              width: 60,
              child: Center(
                  child: Text(theory,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)))),
          SizedBox(
              width: 60,
              child: Center(
                  child: Text(practice,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)))),
          SizedBox(
            width: 110,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: examBg, borderRadius: BorderRadius.circular(999)),
                child: Text(exam, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: examFg)),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isElective ? const Color(0xFFF5F3FF) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: isElective ? const Color(0xFFDDD6FE) : const Color(0xFFA7F3D0)),
                ),
                child: Text(isElective ? 'Tự chọn' : 'Bắt buộc',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isElective ? const Color(0xFF7C3AED) : const Color(0xFF047857),
                    )),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: _canEdit
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _openEditCourseSheet(c, c['_semester_id'] as int),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.edit, color: Color(0xFF6366F1), size: 14),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _deleteCourse(c['id'] as int),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 14),
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

  Widget _paginationRow(int total, int start, int end, int totalPages) {
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
            total == 0 ? 'Không có kết quả' : 'Hiển thị ${start + 1}-$end / $total môn',
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
                decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(6)),
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

  Widget _emptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ),
    );
  }

  void _showAddSemesterSheet() {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn lớp trước khi thêm kỳ học')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(10)),
                    child: Icon(_editingSemesterId == null ? Icons.add_circle : Icons.edit,
                        color: const Color(0xFFF97316), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(_editingSemesterId == null ? 'Thêm kỳ học' : 'Sửa kỳ học',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _semesterNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên kỳ học (VD: HK1 2025-2026)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _semesterStartController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ngày bắt đầu',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            onPressed: () => _selectDate(ctx, _semesterStartController)),
                      ),
                      onTap: () => _selectDate(ctx, _semesterStartController),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _semesterEndController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ngày kết thúc',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            onPressed: () => _selectDate(ctx, _semesterEndController)),
                      ),
                      onTap: () => _selectDate(ctx, _semesterEndController),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedSemesterStatus,
                  decoration: const InputDecoration(
                      labelText: 'Trạng thái', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Đang hoạt động')),
                    DropdownMenuItem(value: 'finished', child: Text('Đã kết thúc')),
                  ],
                  onChanged: (v) => setSheetState(() => _selectedSemesterStatus = v ?? 'active'),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearSemesterForm();
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _saveSemester();
                      },
                      icon: const Icon(Icons.save),
                      label: Text(_editingSemesterId == null ? 'Thêm kỳ học' : 'Lưu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
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
    );
  }

  // (Removed old _buildClassSelector - replaced by _buildClassAndFilterRow)
}
