import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getStatsOverview(),
        ApiService.getAcademicReport(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = Map<String, dynamic>.from(results[0] as Map);
        _classes = (results[1] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
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

  double _number(dynamic value) => double.tryParse((value ?? 0).toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Không tải được dữ liệu thống kê: $_error'));
    }

    final passed = _number(_overview['passed']);
    final failed = _number(_overview['failed']);
    final totalResults = passed + failed;
    final passRate = totalResults == 0 ? 0.0 : passed * 100 / totalResults;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thống kê tổng quan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Dữ liệu được tổng hợp trực tiếp từ hệ thống.', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 900 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric('Sinh viên', _overview['students'], Icons.people_alt_rounded, const Color(0xFF2563EB), width),
                  _metric('Lớp học', _overview['classes'], Icons.class_rounded, const Color(0xFF7C3AED), width),
                  _metric('Môn học', _overview['courses'], Icons.menu_book_rounded, const Color(0xFF059669), width),
                  _metric('Buổi điểm danh', _overview['attendance_sessions'], Icons.fact_check_rounded, const Color(0xFFEA580C), width),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _panel(
                  title: 'Kết quả học tập',
                  child: Column(
                    children: [
                      _resultRow('Điểm trung bình', _number(_overview['average_score']).toStringAsFixed(2), const Color(0xFF2563EB)),
                      _resultRow('Số lượt đạt', passed.toInt().toString(), const Color(0xFF059669)),
                      _resultRow('Số lượt chưa đạt', failed.toInt().toString(), const Color(0xFFDC2626)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: passRate / 100,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(99),
                        backgroundColor: const Color(0xFFFEE2E2),
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerRight, child: Text('Tỷ lệ đạt ${passRate.toStringAsFixed(1)}%')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _panel(
                  title: 'Quy mô dữ liệu',
                  child: Column(
                    children: [
                      _resultRow('Học kỳ', '${_overview['semesters'] ?? 0}', const Color(0xFF7C3AED)),
                      _resultRow('Lịch học / thi', '${_overview['schedules'] ?? 0}', const Color(0xFF0891B2)),
                      _resultRow('Bản ghi điểm', '${_overview['grade_records'] ?? 0}', const Color(0xFFEA580C)),
                      _resultRow('Hóa đơn học phí', '${_overview['invoices'] ?? 0}', const Color(0xFFDB2777)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _panel(
            title: 'Điểm trung bình theo lớp',
            child: _classes.isEmpty
                ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Chưa có dữ liệu điểm theo lớp')))
                : Column(children: _classes.map(_classBar).toList()),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, dynamic value, IconData icon, Color color, double width) => SizedBox(
        width: width,
        child: _panel(
          title: label,
          child: Row(children: [
            CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
            const SizedBox(width: 14),
            Text('${value ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
        ),
      );

  Widget _panel({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          child,
        ]),
      );

  Widget _resultRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF4B5563)))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        ]),
      );

  Widget _classBar(Map<String, dynamic> row) {
    final average = _number(row['average_score']).clamp(0, 10).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 110, child: Text((row['class_name'] ?? 'Chưa xếp lớp').toString(), overflow: TextOverflow.ellipsis)),
        Expanded(child: LinearProgressIndicator(value: average / 10, minHeight: 10, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 12),
        SizedBox(width: 42, child: Text(average.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }
}
