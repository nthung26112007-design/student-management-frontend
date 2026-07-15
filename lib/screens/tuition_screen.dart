import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';

class TuitionScreen extends StatefulWidget {
  final int? studentId;
  final String role;
  const TuitionScreen({super.key, this.studentId, this.role = 'student'});

  @override
  State<TuitionScreen> createState() => _TuitionScreenState();
}

class _TuitionScreenState extends State<TuitionScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all | paid | partial | unpaid

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getTuitionInvoices(studentId: widget.studentId),
        ApiService.getTuitionPayments(studentId: widget.studentId),
      ]);
      final invoices = (results[0] as List).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        final amount = num.tryParse((row['amount'] ?? 0).toString()) ?? 0;
        final paid = num.tryParse((row['paid_amount'] ?? 0).toString()) ?? 0;
        return {
          ...row,
          'student_name': row['full_name'] ?? '',
          'class_name': row['class_name'] ?? row['student_class_name'] ?? '',
          'semester': row['semester_name'] ?? (row['semester_id'] == null ? 'Chưa xác định học kỳ' : 'Học kỳ ${row['semester_id']}'),
          'description': row['title'] ?? row['note'] ?? 'Học phí',
          'total_amount': amount,
          'paid_amount': paid,
          'remaining_amount': num.tryParse((row['remaining_amount'] ?? amount - paid).toString()) ?? amount - paid,
          'credits': num.tryParse((row['credits'] ?? 0).toString()) ?? 0,
          'tuition_per_credit': num.tryParse((row['tuition_per_credit'] ?? 350000).toString()) ?? 350000,
        };
      }).toList();
      final payments = (results[1] as List).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return {
          ...row,
          'payment_code': row['payment_code'] ?? 'PAY${row['id'] ?? ''}',
          'date': row['payment_date'] ?? '',
          'method': row['method'] ?? 'Thanh toán',
          'note': row['note'] ?? '',
          'amount': num.tryParse((row['amount'] ?? 0).toString()) ?? 0,
        };
      }).toList();
      final total = invoices.fold<num>(0, (sum, row) => sum + (row['total_amount'] as num));
      final paid = invoices.fold<num>(0, (sum, row) => sum + (row['paid_amount'] as num));
      if (!mounted) return;
      setState(() {
        _summary = {
          'total_amount': total,
          'paid_amount': paid,
          'remaining_amount': total - paid,
          'paid_percent': total == 0 ? 0.0 : paid / total * 100,
          'unpaid_invoices': invoices.where((row) => row['status'] == 'unpaid').length,
          'overdue_invoices': invoices.where((row) {
            final due = DateTime.tryParse((row['due_date'] ?? '').toString());
            return due != null && due.isBefore(DateTime.now()) && row['status'] != 'paid';
          }).length,
        };
        _invoices = invoices;
        _payments = payments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _fmtMoney(num v) {
    final s = v.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildSummaryCard(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabHeaderDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFFF59E0B),
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: const Color(0xFFF59E0B),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      tabs: [
                        Tab(text: 'Hóa đơn (${_invoices.length})'),
                        Tab(text: 'Lịch sử (${_payments.length})'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildInvoicesTab(),
                  _buildPaymentsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: const Color(0xFFF59E0B),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Học phí',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFFB923C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 56),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Quản lý học phí',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.role == 'admin'
                              ? 'Tất cả sinh viên • ${_invoices.length} hóa đơn'
                              : 'Sinh viên • Năm học 2024-2025',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (widget.role == 'admin')
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showAddInvoiceDialog(),
            tooltip: 'Tạo hóa đơn',
          ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final paid = _summary['paid_amount'] ?? 0;
    final total = _summary['total_amount'] ?? 0;
    final remain = _summary['remaining_amount'] ?? 0;
    final percent = total == 0 ? '0.0' : ((paid / total) * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Tổng quan học phí',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_fmtMoney(remain)} đ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Còn phải đóng (trên tổng ${_fmtMoney(total)} đ)',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (num.tryParse(total.toString()) ?? 0) <= 0
                  ? 0
                  : (num.tryParse(paid.toString()) ?? 0) / (num.tryParse(total.toString()) ?? 1),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  Icons.check_circle_rounded,
                  'Đã thanh toán',
                  '${_fmtMoney(paid)} đ',
                  Colors.white,
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _summaryItem(
                  Icons.receipt_long_rounded,
                  'Chưa thanh toán',
                  '${_summary['unpaid_invoices'] ?? 0} hóa đơn',
                  Colors.white,
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _summaryItem(
                  Icons.warning_amber_rounded,
                  'Quá hạn',
                  '${_summary['overdue_invoices'] ?? 0} hóa đơn',
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.85), size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: color.withOpacity(0.85), fontSize: 10)),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    final list = _filterStatus == 'all'
        ? _invoices
        : _invoices.where((i) => i['status'] == _filterStatus).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('all', 'Tất cả', _invoices.length),
                _filterChip('paid', 'Đã đóng', _invoices.where((i) => i['status'] == 'paid').length),
                _filterChip('partial', 'Một phần', _invoices.where((i) => i['status'] == 'partial').length),
                _filterChip('unpaid', 'Chưa đóng', _invoices.where((i) => i['status'] == 'unpaid').length),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Không có hóa đơn nào', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _buildInvoiceCard(list[index]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label, int count) {
    final selected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _filterStatus = value),
        label: Text('$label ($count)'),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF374151),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        selectedColor: const Color(0xFFF59E0B),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB)),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final status = (invoice['status'] ?? 'unpaid').toString();
    final color = _statusColor(status);
    final total = ((invoice['total_amount'] ?? 0) as num).toDouble();
    final paid = ((invoice['paid_amount'] ?? 0) as num).toDouble();
    final remain = ((invoice['remaining_amount'] ?? 0) as num).toDouble();
    final percent = total == 0 ? 0.0 : (paid / total);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showInvoiceDetail(invoice),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'INV',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (invoice['invoice_code'] ?? 'Chưa có mã hóa đơn').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (invoice['semester'] ?? 'Chưa xác định học kỳ').toString(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Tổng học phí',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      const Spacer(),
                      Text(
                        '${_fmtMoney(total)} đ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Đã đóng',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      const Spacer(),
                      Text(
                        '${_fmtMoney(paid)} đ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Còn lại',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        '${_fmtMoney(remain)} đ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: const Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  'Hạn: ${invoice['due_date']}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const Spacer(),
                Text(
                  '${invoice['credits']} tín chỉ',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _buildPaymentCard(_payments[index]),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (payment['payment_code'] ?? 'Chưa có mã thanh toán').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hóa đơn ${payment['invoice_code']} • ${payment['method']}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                if ((payment['note'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    (payment['note'] ?? '').toString(),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmtMoney(((payment['amount'] ?? 0) as num).toInt())} đ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF15803D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (payment['date'] ?? '').toString(),
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetail(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InvoiceDetailSheet(invoice: invoice),
    );
  }

  void _showAddInvoiceDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: const _BulkInvoiceDialog(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      final response = await ApiService.addTuitionInvoicesByClass(result);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message']} • ${response['credits']} tín chỉ × 350.000đ'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tạo được hóa đơn: $error'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return const Color(0xFF10B981);
      case 'partial': return const Color(0xFFF59E0B);
      case 'unpaid': return const Color(0xFFEF4444);
      default: return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'Đã đóng';
      case 'partial': return 'Một phần';
      case 'unpaid': return 'Chưa đóng';
      default: return status;
    }
  }
}

// ============ Create Invoice Dialog ============

class _BulkInvoiceDialog extends StatefulWidget {
  const _BulkInvoiceDialog();

  @override
  State<_BulkInvoiceDialog> createState() => _BulkInvoiceDialogState();
}

class _BulkInvoiceDialogState extends State<_BulkInvoiceDialog> {
  static const int _unitPrice = 350000;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _courses = [];
  String? _className;
  int? _semesterId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _loading = true;

  int get _credits => _courses
      .where((course) => int.tryParse((course['semester_id'] ?? '').toString()) == _semesterId)
      .fold(0, (sum, course) => sum + (int.tryParse((course['credits'] ?? 0).toString()) ?? 0));

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final rows = await ApiService.getClasses();
      _classes = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      _className = _classes.isEmpty ? null : (_classes.first['name'] ?? '').toString();
      await _loadClassData();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClassData() async {
    final className = _className;
    if (className == null || className.isEmpty) return;
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        ApiService.getSemesters(className: className),
        ApiService.getCourses(className: className),
      ]);
      if (!mounted || className != _className) return;
      setState(() {
        _semesters = (values[0] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _courses = (values[1] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _semesterId = _semesters.isEmpty ? null : int.tryParse((_semesters.first['id'] ?? '').toString());
      });
    } finally {
      if (mounted && className == _className) setState(() => _loading = false);
    }
  }

  String _money(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');

  Future<void> _pickDueDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _dueDate = value);
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true);

  @override
  Widget build(BuildContext context) {
    final amount = _credits * _unitPrice;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tạo hóa đơn học phí theo lớp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Hệ thống tạo hóa đơn cho toàn bộ sinh viên trong lớp.', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _classes.any((row) => row['name']?.toString() == _className) ? _className : null,
            decoration: _dec('Lớp học'),
            isExpanded: true,
            items: _classes.map((row) {
              final name = (row['name'] ?? '').toString();
              return DropdownMenuItem(value: name, child: Text(name));
            }).toList(),
            onChanged: _loading ? null : (value) {
              setState(() {
                _className = value;
                _semesterId = null;
                _semesters = [];
                _courses = [];
              });
              _loadClassData();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _semesters.any((row) => int.tryParse((row['id'] ?? '').toString()) == _semesterId) ? _semesterId : null,
            decoration: _dec('Học kỳ'),
            isExpanded: true,
            items: _semesters
                .where((row) => int.tryParse((row['id'] ?? '').toString()) != null)
                .map((row) {
                  final id = int.parse(row['id'].toString());
                  return DropdownMenuItem<int>(value: id, child: Text((row['name'] ?? 'Học kỳ $id').toString()));
                }).toList(),
            onChanged: _loading ? null : (value) => setState(() => _semesterId = value),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDueDate,
            child: InputDecorator(
              decoration: _dec('Hạn đóng'),
              child: Text('${_dueDate.day.toString().padLeft(2, '0')}/${_dueDate.month.toString().padLeft(2, '0')}/${_dueDate.year}'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tổng tín chỉ: $_credits', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Đơn giá: 350.000đ / tín chỉ'),
              const SizedBox(height: 6),
              Text('Học phí mỗi sinh viên: ${_money(amount)}đ', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy'))),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _loading || _className == null || _semesterId == null || _credits <= 0
                    ? null
                    : () => Navigator.pop(context, {
                          'class_name': _className,
                          'semester_id': _semesterId,
                          'due_date': _dueDate.toIso8601String().substring(0, 10),
                          'title': 'Học phí học kỳ $_semesterId',
                          'note': '$_credits tín chỉ × 350.000đ',
                        }),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Tạo hóa đơn cho cả lớp'),
              ),
            ),
          ]),
          if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}

class _CreateInvoiceDialog extends StatefulWidget {
  const _CreateInvoiceDialog();

  @override
  State<_CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends State<_CreateInvoiceDialog> {
  final _studentCodeC = TextEditingController();
  final _studentNameC = TextEditingController();
  final _descriptionC = TextEditingController(text: 'Học phí học kỳ');
  final _amountC = TextEditingController(text: '5000000');
  final _invoiceCodeC = TextEditingController(
    text: 'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
  );

  String? _class;
  String? _semester;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _feeType = 'tuition';

  final _classes = const ['CK-K46A', 'CK-K46B', 'CK-K46C', 'AT-K45A'];
  final _semesters = const ['HK1 2024-2025', 'HK2 2024-2025', 'HK1 2025-2026'];
  final _feeTypes = const [
    {'value': 'tuition', 'label': 'Học phí', 'defaultAmount': '5000000'},
    {'value': 'exam', 'label': 'Phí thi', 'defaultAmount': '200000'},
    {'value': 'material', 'label': 'Phí tài liệu', 'defaultAmount': '300000'},
    {'value': 'other', 'label': 'Khác', 'defaultAmount': '0'},
  ];

  @override
  void initState() {
    super.initState();
    _class = _classes.first;
    _semester = _semesters.first;
  }

  @override
  void dispose() {
    _studentCodeC.dispose();
    _studentNameC.dispose();
    _descriptionC.dispose();
    _amountC.dispose();
    _invoiceCodeC.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF8B5CF6), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Tạo hóa đơn mới',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),
          _label('Mã hóa đơn'),
          TextField(
            controller: _invoiceCodeC,
            decoration: _dec('INV-001'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Mã sinh viên'),
                  TextField(
                    controller: _studentCodeC,
                    decoration: _dec('SV001'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Họ và tên'),
                  TextField(
                    controller: _studentNameC,
                    decoration: _dec('Nguyễn Văn A'),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Lớp'),
                  DropdownButtonFormField<String>(
                    value: _classes.contains(_class) ? _class : null,
                    isExpanded: true,
                    decoration: _dec('Chọn lớp'),
                    items: _classes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _class = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Học kỳ'),
                  DropdownButtonFormField<String>(
                    value: _semesters.contains(_semester) ? _semester : null,
                    isExpanded: true,
                    decoration: _dec('Chọn HK'),
                    items: _semesters
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _semester = v),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _label('Loại phí'),
          DropdownButtonFormField<String>(
            value: _feeType,
            isExpanded: true,
            decoration: _dec('Chọn loại'),
            items: _feeTypes
                .map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _feeType = v;
                final def = _feeTypes.firstWhere((f) => f['value'] == v);
                _amountC.text = def['defaultAmount']!;
              });
            },
          ),
          const SizedBox(height: 12),
          _label('Số tiền (VND)'),
          TextField(
            controller: _amountC,
            keyboardType: TextInputType.number,
            decoration: _dec('5000000'),
          ),
          const SizedBox(height: 12),
          _label('Mô tả'),
          TextField(
            controller: _descriptionC,
            maxLines: 2,
            decoration: _dec('Mô tả chi tiết...'),
          ),
          const SizedBox(height: 12),
          _label('Hạn đóng'),
          InkWell(
            onTap: _pickDueDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Text(
                  '${_dueDate.day.toString().padLeft(2, '0')}/${_dueDate.month.toString().padLeft(2, '0')}/${_dueDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6B7280)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  final code = _studentCodeC.text.trim();
                  final name = _studentNameC.text.trim();
                  final amount = double.tryParse(_amountC.text.trim());
                  if (code.isEmpty || name.isEmpty || amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập đầy đủ Mã SV, họ tên và số tiền hợp lệ'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, () {
                    final sv = MockDataService.canonicalStudents.firstWhere(
                      (s) => (s['student_code'] ?? '') == code,
                      orElse: () => <String, dynamic>{},
                    );
                    return {
                      'invoice_code': _invoiceCodeC.text.trim().isEmpty
                          ? 'INV${DateTime.now().millisecondsSinceEpoch}'
                          : _invoiceCodeC.text.trim(),
                      'student_id': sv['student_id'],
                      'student_code': code,
                      'student_name': name,
                      'class_name': _class,
                      'semester_id': null,
                      'semester': _semester,
                      'description': _descriptionC.text.trim(),
                      'amount': amount,
                      'credits': 0,
                      'tuition_per_credit': 0,
                      'due_date': _dueDate.toIso8601String().substring(0, 10),
                    };
                  }());
                },
                icon: const Icon(Icons.receipt_rounded, size: 18),
                label: const Text('Tạo hóa đơn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ============ Invoice Detail Sheet ============

class _InvoiceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceDetailSheet({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final code = invoice['invoice_code']?.toString() ?? '';
    final studentName = invoice['student_name']?.toString() ?? '';

    final studentCode = invoice['student_code']?.toString() ?? '';
    final className = invoice['class_name']?.toString() ?? '';
    final semester = invoice['semester']?.toString() ?? '';
    final description = invoice['description']?.toString() ?? '';
    final total = (invoice['total_amount'] as num?) ?? 0;
    final paid = (invoice['paid_amount'] as num?) ?? 0;
    final remaining = total - paid;
    final status = (invoice['status'] ?? 'unpaid').toString();
    final rawDueDate = invoice['due_date']?.toString() ?? '';
    final dueDate = rawDueDate.length >= 10 ? rawDueDate.substring(0, 10) : rawDueDate;
    final createdAt = invoice['created_at']?.toString() ?? '';

    late Color statusColor;
    late String statusLabel;
    switch (status) {
      case 'paid':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Đã đóng';
        break;
      case 'partial':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'Một phần';
        break;
      default:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Chưa đóng';
    }

    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hóa đơn $code',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              studentName.isNotEmpty ? '$studentName • $studentCode' : studentCode,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon(status), size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Text(statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 13)),
                    const Spacer(),
                    Text('Hạn: ${_fmtDate(dueDate)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            // Amount card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text('Tổng hóa đơn',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_fmtMoney(total.toDouble()),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Đã đóng', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(_fmtMoney(paid.toDouble()),
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.white24),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Còn lại', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(_fmtMoney(remaining.toDouble()),
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        color: Colors.white,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _sectionTitle('Thông tin chung'),
                  _infoRow(Icons.description_rounded, 'Mô tả', description),
                  _infoRow(Icons.class_rounded, 'Lớp', className),
                  _infoRow(Icons.event_note_rounded, 'Học kỳ', semester),
                  _infoRow(Icons.calendar_today_rounded, 'Ngày tạo', _fmtDate(createdAt)),
                  _infoRow(Icons.alarm_rounded, 'Hạn đóng', _fmtDate(dueDate)),
                  const SizedBox(height: 12),
                  if (paid > 0) ...[
                    _sectionTitle('Lịch sử thanh toán'),
                    _paymentRow('01/11/2024', 'Chuyển khoản', paid.toDouble(), const Color(0xFF10B981)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã xuất PDF hóa đơn'), backgroundColor: Color(0xFF10B981)),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('In PDF'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          foregroundColor: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (status != 'paid')
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã mở form thanh toán cho $code'),
                                backgroundColor: const Color(0xFF8B5CF6),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payments_rounded, size: 16),
                          label: const Text('Thanh toán'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text('Đã thanh toán đủ',
                                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
        child: Text(s,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
      );

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(value.isEmpty ? '—' : value,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentRow(String date, String method, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Text(_fmtMoney(amount),
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  String _fmtMoney(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()}đ';
  }

  String _fmtDate(String date) {
    if (date.isEmpty) return '—';
    if (date.length >= 10) {
      final d = date.substring(8, 10);
      final m = date.substring(5, 7);
      final y = date.substring(0, 4);
      return '$d/$m/$y';
    }
    return date;
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'paid': return Icons.check_circle_rounded;
      case 'partial': return Icons.access_time_rounded;
      default: return Icons.error_outline_rounded;
    }
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabHeaderDelegate(this.tabBar);

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) => false;
}
