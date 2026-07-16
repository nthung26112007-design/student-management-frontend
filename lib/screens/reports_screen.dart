import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _academic = [];
  List<Map<String, dynamic>> _tuition = [];
  String _classFilter = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        ApiService.getAcademicReport(),
        ApiService.getTuitionSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _academic = (values[0] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _tuition = (values[1] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<String> get _classes => {
        ..._academic.map((row) => (row['class_name'] ?? '').toString()),
        ..._tuition.map((row) => (row['class_name'] ?? '').toString()),
      }.where((value) => value.isNotEmpty).toList()..sort();

  List<Map<String, dynamic>> get _academicRows => _classFilter == 'all'
      ? _academic
      : _academic.where((row) => row['class_name']?.toString() == _classFilter).toList();

  List<Map<String, dynamic>> get _tuitionRows => _classFilter == 'all'
      ? _tuition
      : _tuition.where((row) => row['class_name']?.toString() == _classFilter).toList();

  double _number(dynamic value) => double.tryParse((value ?? 0).toString()) ?? 0;

  String _money(dynamic value) {
    final digits = _number(value).round().toString();
    return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} ₫';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Không tải được báo cáo: $_error'));

    final totalDebt = _tuitionRows.fold<double>(0, (sum, row) => sum + _number(row['balance']));
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Báo cáo hệ thống', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('Báo cáo học tập và công nợ từ dữ liệu Aiven.', style: TextStyle(color: Color(0xFF6B7280))),
                ]),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  value: _classFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lọc theo lớp', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Tất cả lớp')),
                    ..._classes.map((value) => DropdownMenuItem(value: value, child: Text(value))),
                  ],
                  onChanged: (value) => setState(() => _classFilter = value ?? 'all'),
                ),
              ),
            ]),
          ),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.school_rounded), text: 'Kết quả học tập'),
              Tab(icon: Icon(Icons.account_balance_wallet_rounded), text: 'Công nợ học phí'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _academicTable(),
              Column(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Chip(label: Text('Tổng công nợ: ${_money(totalDebt)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  ),
                ),
                Expanded(child: _tuitionTable()),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _academicTable() => _table(
        columns: const ['Lớp', 'Sinh viên', 'Bản ghi điểm', 'Điểm TB', 'Đạt', 'Chưa đạt', 'Tỷ lệ đạt'],
        rows: _academicRows.map((row) {
          final passed = _number(row['passed']);
          final failed = _number(row['failed']);
          final rate = passed + failed == 0 ? 0 : passed * 100 / (passed + failed);
          return [
            row['class_name'] ?? '—', row['student_count'] ?? 0, row['grade_records'] ?? 0,
            _number(row['average_score']).toStringAsFixed(2), passed.toInt(), failed.toInt(), '${rate.toStringAsFixed(1)}%',
          ];
        }).toList(),
      );

  Widget _tuitionTable() => _table(
        columns: const ['Mã SV', 'Họ tên', 'Lớp', 'Phải thu', 'Đã đóng', 'Còn nợ'],
        rows: _tuitionRows.map((row) => [
          row['student_code'] ?? '—', row['full_name'] ?? '—', row['class_name'] ?? '—',
          _money(row['total_invoiced']), _money(row['total_paid']), _money(row['balance']),
        ]).toList(),
      );

  Widget _table({required List<String> columns, required List<List<dynamic>> rows}) {
    if (rows.isEmpty) return const Center(child: Text('Chưa có dữ liệu báo cáo'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
          columns: columns.map((column) => DataColumn(label: Text(column, style: const TextStyle(fontWeight: FontWeight.w800)))).toList(),
          rows: rows.map((row) => DataRow(cells: row.map((value) => DataCell(Text(value.toString()))).toList())).toList(),
        ),
      ),
    );
  }
}
