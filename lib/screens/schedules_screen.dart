import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  List<Map<String, dynamic>> _items = [];
  List<String> _classOptions = [];
  List<Map<String, dynamic>> _availableSubjects = [];
  bool _loading = true;
  String _role = '';
  String? _selectedType;
  String? _selectedClass;
  String? _selectedSubject;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  String _calendarMode = 'month';

  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();
  final _noteController = TextEditingController();
  final _classController = TextEditingController();
  final _timeController = TextEditingController();
  String _editType = 'study';
  int? _editingId;
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;

  bool get _canEdit => _role == 'admin' || _role == 'teacher';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    _noteController.dispose();
    _classController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('role') ?? '';
    await _loadClasses();
    await _loadItems();
  }

  Future<void> _loadClasses() async {
    try {
      final data = await ApiService.getStudents();
      List<String> classes = <String>[];
      if (data is List) {
        classes = data
            .map((e) => (e['class_name'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        classes.sort();
      }
      if (!mounted) return;
      setState(() {
        _classOptions = classes;
        if (_selectedClass == null && _classOptions.isNotEmpty) {
          _selectedClass = _classOptions.first;
          _classController.text = _selectedClass!;
        }
      });
      await _loadSubjectsForClass();
    } catch (_) {}
  }

  Future<void> _loadSubjectsForClass() async {
    try {
      if (_selectedClass == null || _selectedClass!.isEmpty) {
        if (!mounted) return;
        setState(() => _availableSubjects = []);
        return;
      }
      final courses = await ApiService.getCourses();
      final subjects = courses is List
          ? courses
              .map((e) => Map<String, dynamic>.from(e))
              .where((c) => (c['class_name'] ?? '').toString().trim() == _selectedClass)
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _availableSubjects = subjects;
        if (_selectedSubject != null && !_availableSubjects.any((s) => (s['subject_name'] ?? '').toString() == _selectedSubject)) {
          _selectedSubject = null;
          _subjectController.clear();
        }
      });
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.getSchedules(
        type: _selectedType,
        className: _selectedClass,
      );
      if (!mounted) return;
      setState(() {
        _items = (items is List) ? items.map((e) => Map<String, dynamic>.from(e)).toList() : [];
        if (_selectedDay == null && _items.isNotEmpty) {
          _selectedDay = _parseDate(_items.first['schedule_date']);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được lịch: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _editingId = null;
    _editType = 'study';
    _titleController.clear();
    _subjectController.clear();
    _roomController.clear();
    _noteController.clear();
    _classController.clear();
    _selectedSubject = null;
    _pickedDate = null;
    _pickedTime = null;
    _timeController.clear();
  }

  Future<void> _saveSchedule() async {
    final date = _pickedDate;
    final time = _pickedTime;
    if (_titleController.text.trim().isEmpty || _classController.text.trim().isEmpty || date == null || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ tiêu đề, lớp, ngày và giờ')));
      return;
    }

    final payload = {
      'type': _editType,
      'title': _titleController.text.trim(),
      'class_name': _classController.text.trim(),
      'subject_name': _subjectController.text.trim(),
      'schedule_date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'schedule_time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'room': _roomController.text.trim(),
      'note': _noteController.text.trim(),
    };

    try {
      if (_editingId == null) {
        await ApiService.addSchedule(payload);
      } else {
        await ApiService.updateSchedule(_editingId!, payload);
      }
      _resetForm();
      await _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu lịch')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được lịch: $e')));
    }
  }

  void _editItem(Map<String, dynamic> item) {
    _editingId = item['id'] as int;
    _editType = (item['type'] ?? 'study').toString();
    _titleController.text = item['title']?.toString() ?? '';
    _classController.text = item['class_name']?.toString() ?? '';
    _subjectController.text = item['subject_name']?.toString() ?? '';
    _selectedSubject = _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim();
    _pickedDate = _parseDate(item['schedule_date']);
    final rawTime = item['schedule_time']?.toString() ?? '';
    _timeController.text = rawTime;
    if (rawTime.contains(':')) {
      final parts = rawTime.split(':');
      final hh = int.tryParse(parts[0]);
      final mm = int.tryParse(parts.length > 1 ? parts[1] : '0');
      if (hh != null && mm != null) _pickedTime = TimeOfDay(hour: hh, minute: mm);
    }
    _roomController.text = item['room']?.toString() ?? '';
    _noteController.text = item['note']?.toString() ?? '';
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chọn lịch để sửa')));
  }

  Future<void> _deleteItem(int id) async {
    try {
      await ApiService.deleteSchedule(id);
      await _loadItems();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa lịch')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xóa được lịch: $e')));
    }
  }

  DateTime? _parseDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.length >= 10) {
      final y = int.tryParse(raw.substring(0, 4));
      final m = int.tryParse(raw.substring(5, 7));
      final d = int.tryParse(raw.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return null;
  }

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Lịch học / Lịch thi'), backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (_canEdit) ...[
                    _buildEditorCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildModeSelector(),
                  const SizedBox(height: 16),
                  if (_calendarMode == 'month') _buildMonthView(),
                  if (_calendarMode == 'week') _buildWeekView(),
                  if (_calendarMode == 'day') _buildDayView(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.purple.shade500]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lịch học - lịch thi', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Theo dõi lịch theo tháng, tuần hoặc ngày.', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            color: Colors.white,
            onSelected: (value) => setState(() => _calendarMode = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'month', child: Text('Lịch Tháng')),
              PopupMenuItem(value: 'week', child: Text('Lịch Tuần')),
              PopupMenuItem(value: 'day', child: Text('Lịch Ngày')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_editingId == null ? 'Tạo lịch mới' : 'Sửa lịch', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_editingId != null) TextButton(onPressed: _resetForm, child: const Text('Hủy sửa')),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _editType,
            decoration: const InputDecoration(labelText: 'Loại lịch', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'study', child: Text('Lịch học')),
              DropdownMenuItem(value: 'exam', child: Text('Lịch thi')),
            ],
            onChanged: (v) => setState(() => _editType = v ?? 'study'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tiêu đề', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _classOptions.contains(_classController.text.trim()) ? _classController.text.trim() : null,
            decoration: const InputDecoration(labelText: 'Lớp', border: OutlineInputBorder()),
            items: _classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              setState(() {
                _classController.text = v ?? '';
                _selectedClass = v;
                _selectedSubject = null;
                _subjectController.clear();
              });
              _loadSubjectsForClass();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSubject,
            decoration: const InputDecoration(labelText: 'Môn học trong lớp', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('Chọn môn học...')),
              ..._availableSubjects
                  .map((s) => (s['subject_name'] ?? '').toString().trim())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .map((subject) => DropdownMenuItem<String>(value: subject, child: Text(subject))),
            ],
            onChanged: (v) => setState(() {
              _selectedSubject = v;
              _subjectController.text = v ?? '';
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _pickedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _pickedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ngày', border: OutlineInputBorder()),
                    child: Text(_pickedDate == null ? 'Chọn ngày' : _formatDate(_pickedDate!)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _pickedTime ?? const TimeOfDay(hour: 7, minute: 0),
                    );
                    if (picked != null) {
                      setState(() {
                        _pickedTime = picked;
                        _timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Giờ', border: OutlineInputBorder()),
                    child: Text(_pickedTime == null ? 'Chọn giờ' : _timeController.text),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _roomController, decoration: const InputDecoration(labelText: 'Phòng', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSchedule,
              icon: Icon(_editingId == null ? Icons.add : Icons.save),
              label: Text(_editingId == null ? 'Tạo lịch' : 'Lưu thay đổi'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        _modeChip('month', 'Tháng'),
        const SizedBox(width: 8),
        _modeChip('week', 'Tuần'),
        const SizedBox(width: 8),
        _modeChip('day', 'Ngày'),
      ],
    );
  }

  Widget _modeChip(String value, String label) {
    final selected = _calendarMode == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _calendarMode = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.purple.shade700 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Colors.purple.shade700 : Colors.grey.shade300),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildMonthView() {
    final monthItems = _items.where((item) {
      final d = _parseDate(item['schedule_date']);
      return d != null && d.year == _focusedMonth.year && d.month == _focusedMonth.month;
    }).toList();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in monthItems) {
      final d = _parseDate(item['schedule_date']);
      if (d == null) continue;
      grouped.putIfAbsent(_dateKey(d), () => []).add(item);
    }
    final days = grouped.keys.toList()..sort();

    return _calendarCard(
      header: Row(
        children: [
          IconButton(onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Center(child: Text('Tháng ${_focusedMonth.month}, ${_focusedMonth.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
          IconButton(onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      child: Column(
        children: [
          _monthGrid(),
          const SizedBox(height: 16),
          if (_selectedDay != null)
            _buildItemsForDay(_selectedDay!)
          else if (days.isNotEmpty)
            _buildItemsForDay(_parseDate(days.first) ?? _focusedMonth)
          else
            _emptyHint('Không có lịch trong tháng này'),
        ],
      ),
    );
  }

  Widget _buildWeekView() {
    final base = _selectedDay ?? DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final monday = base.subtract(Duration(days: (base.weekday + 6) % 7));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    return _calendarCard(
      header: Row(
        children: [
          IconButton(onPressed: () => setState(() => _selectedDay = monday.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Center(child: Text('Tuần ${_formatDate(monday)} - ${_formatDate(monday.add(const Duration(days: 6)))}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))),
          IconButton(onPressed: () => setState(() => _selectedDay = monday.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      child: Column(
        children: [
          ...weekDays.map((day) => _daySummaryTile(day)),
        ],
      ),
    );
  }

  Widget _buildDayView() {
    final day = _selectedDay ?? DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    return _calendarCard(
      header: Row(
        children: [
          Expanded(child: Text(_formatDate(day), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          TextButton(onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (picked != null) setState(() => _selectedDay = picked);
          }, child: const Text('Chọn ngày')),
        ],
      ),
      child: _dayItems(day),
    );
  }

  Widget _calendarCard({required Widget header, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, const SizedBox(height: 12), child]),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekday = first.weekday % 7;
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final cells = <Widget>[];
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final hasEvent = _items.any((item) {
        final d = _parseDate(item['schedule_date']);
        return d != null && d.year == date.year && d.month == date.month && d.day == date.day;
      });
      final selected = _selectedDay != null && _selectedDay!.year == date.year && _selectedDay!.month == date.month && _selectedDay!.day == date.day;
      cells.add(GestureDetector(
        onTap: () => setState(() => _selectedDay = date),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.blue.shade700 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Center(
                child: Text(
                  '$day',
                  style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w700),
                ),
              ),
              if (hasEvent)
                Positioned(
                  bottom: 4,
                  child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      ));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1,
      children: cells,
    );
  }

  List<Map<String, dynamic>> _itemsForDay(DateTime day) {
    return _items.where((item) {
      final d = _parseDate(item['schedule_date']);
      return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  Widget _buildItemsForDay(DateTime day) {
    final items = _itemsForDay(day);
    return _dayItems(day, items: items);
  }

  Widget _buildItemsForKey(String key) {
    final items = _items.where((item) {
      final d = _parseDate(item['schedule_date']);
      return d != null && _dateKey(d) == key;
    }).toList();
    if (items.isEmpty) return _emptyHint('Không có lịch trong ngày này');
    final day = _parseDate(items.first['schedule_date']) ?? DateTime.now();
    return _dayItems(day, items: items);
  }

  Widget _dayItems(DateTime day, {List<Map<String, dynamic>>? items}) {
    final list = items ?? _itemsForDay(day);
    if (list.isEmpty) return _emptyHint('Không có lịch trong ngày này');
    return Column(
      children: list.map(_buildScheduleCard).toList(),
    );
  }

  Widget _daySummaryTile(DateTime day) {
    final list = _itemsForDay(day);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(day), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${list.length} lịch'),
            ],
          ),
          const Spacer(),
          TextButton(onPressed: () => setState(() => _selectedDay = day), child: const Text('Xem')),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lọc danh sách', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Loại', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tất cả')),
                    DropdownMenuItem(value: 'study', child: Text('Lịch học')),
                    DropdownMenuItem(value: 'exam', child: Text('Lịch thi')),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedType = v);
                    _loadItems();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedClass,
                  decoration: const InputDecoration(labelText: 'Lớp', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Tất cả')),
                    ..._classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedClass = v);
                    _loadItems();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item) {
    final isExam = (item['type'] ?? 'study') == 'exam';
    final color = isExam ? Colors.red : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(isExam ? Icons.quiz : Icons.event, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title']?.toString() ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${isExam ? 'Lịch thi' : 'Lịch học'} • ${item['class_name'] ?? ''}', style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              if (_canEdit)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editItem(item);
                    if (v == 'delete') _deleteItem(item['id']);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(Icons.menu_book, item['subject_name']?.toString() ?? '—'),
              _infoChip(Icons.calendar_month, '${item['schedule_date'] ?? ''} • ${item['schedule_time'] ?? ''}'),
              _infoChip(Icons.meeting_room, item['room']?.toString() ?? '—'),
            ],
          ),
          if ((item['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item['note'].toString(), style: TextStyle(color: Colors.grey.shade700)),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FB), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)]),
    );
  }

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(text, style: TextStyle(color: Colors.grey.shade600))),
      );
}
