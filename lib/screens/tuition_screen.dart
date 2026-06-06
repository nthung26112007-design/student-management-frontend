import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TuitionScreen extends StatefulWidget {
  final int? studentId;
  final String role;

  const TuitionScreen({super.key, this.studentId, this.role = 'student'});

  @override
  State<TuitionScreen> createState() => _TuitionScreenState();
}

class _TuitionScreenState extends State<TuitionScreen> {
  final _studentIdController = TextEditingController();
  final _invoiceCodeController = TextEditingController();
  final _invoiceTitleController = TextEditingController();
  final _invoiceAmountController = TextEditingController();
  final _invoiceDueDateController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _paymentNoteController = TextEditingController();

  bool _isLoading = false;
  bool _isSavingInvoice = false;
  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _students = [];
  List<String> _classOptions = ['Tất cả'];
  String _selectedClass = 'Tất cả';
  Map<String, dynamic>? _selectedDebtInvoice;
  String _selectedPaymentMethod = 'atm';
  int _studentStep = 1;

  static const String _bankName = 'Vietcombank';
  static const String _bankAccountName = 'NGUYEN VAN A';
  static const String _bankAccountNumber = '0123456789';
  static const String _bankBin = '970436';

  bool get _isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _studentIdController.text = widget.studentId?.toString() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _invoiceCodeController.dispose();
    _invoiceTitleController.dispose();
    _invoiceAmountController.dispose();
    _invoiceDueDateController.dispose();
    _paymentAmountController.dispose();
    _paymentNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final studentId = widget.studentId ?? int.tryParse(_studentIdController.text.trim());
      if (_isAdmin) {
        final students = await ApiService.getStudents();
        _students = students is List
            ? students.map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final classes = _students
            .map((s) => (s['class_name'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _classOptions = ['Tất cả', ...classes];
        if (!_classOptions.contains(_selectedClass)) _selectedClass = 'Tất cả';
      }

      final summary = await ApiService.getTuitionSummary(studentId: studentId);
      final invoices = await ApiService.getTuitionInvoices(studentId: studentId);
      final payments = await ApiService.getTuitionPayments(studentId: studentId);

      if (!mounted) return;
      setState(() {
        _summary = summary is List
            ? summary.map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        _invoices = invoices is List
            ? invoices.map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        _payments = payments is List
            ? payments.map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        if (_selectedDebtInvoice != null && !_invoices.any((i) => i['id'] == _selectedDebtInvoice!['id'])) {
          _selectedDebtInvoice = null;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _pendingInvoices => _invoices
      .where((i) => (num.tryParse(i['remaining_amount'].toString()) ?? 0) > 0)
      .toList();

  List<Map<String, dynamic>> get _filteredStudents => _selectedClass == 'Tất cả'
      ? _students
      : _students.where((s) => (s['class_name'] ?? '').toString().trim() == _selectedClass).toList();

  Future<void> _createInvoicesForClass() async {
    final className = _selectedClass;
    final amount = double.tryParse(_invoiceAmountController.text.trim()) ?? 0;
    final title = _invoiceTitleController.text.trim();

    if (className == 'Tất cả') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn một lớp cụ thể')));
      return;
    }
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên hóa đơn và số tiền hợp lệ')));
      return;
    }

    final targetStudents = _filteredStudents;
    if (targetStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lớp này chưa có sinh viên')));
      return;
    }

    setState(() => _isSavingInvoice = true);
    try {
      for (final student in targetStudents) {
        await ApiService.addTuitionInvoice({
          'student_id': student['id'],
          'invoice_code': _invoiceCodeController.text.trim().isEmpty ? null : _invoiceCodeController.text.trim(),
          'title': title,
          'amount': amount,
          'due_date': _invoiceDueDateController.text.trim().isEmpty ? null : _invoiceDueDateController.text.trim(),
          'class_name': className,
        });
      }
      _invoiceCodeController.clear();
      _invoiceTitleController.clear();
      _invoiceAmountController.clear();
      _invoiceDueDateController.clear();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo hóa đơn cho ${targetStudents.length} sinh viên của lớp $className')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tạo được hóa đơn: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingInvoice = false);
    }
  }

  Future<void> _createPayment() async {
    final invoice = _selectedDebtInvoice;
    final invoiceId = invoice?['id'] as int?;
    final studentId = invoice?['student_id'] as int?;
    final amount = double.tryParse(_paymentAmountController.text.trim()) ?? 0;

    if (invoiceId == null || studentId == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn công nợ và nhập số tiền hợp lệ')),
      );
      return;
    }

    try {
      await ApiService.addTuitionPayment({
        'invoice_id': invoiceId,
        'student_id': studentId,
        'amount': amount,
        'payment_date': DateTime.now().toIso8601String().substring(0, 10),
        'note': _paymentNoteController.text.trim().isEmpty ? null : _paymentNoteController.text.trim(),
        'method': _selectedPaymentMethod,
        'status': 'pending',
      });

      _paymentAmountController.clear();
      _paymentNoteController.clear();
      _selectedDebtInvoice = null;
      _studentStep = 1;
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu thanh toán')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể thanh toán: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: Text(_isAdmin ? 'Quản lý học phí' : 'Học phí'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 14),
                    if (_isAdmin) ...[
                      _buildAdminToolbar(),
                      const SizedBox(height: 14),
                      _buildSummaryCards(),
                      const SizedBox(height: 14),
                      _buildInvoiceFormCard(),
                      const SizedBox(height: 14),
                      SizedBox(height: 520, child: _buildAdminInvoiceList()),
                    ] else ...[
                      _buildStudentStepper(),
                      const SizedBox(height: 14),
                      SizedBox(height: 760, child: _buildStudentContent()),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.deepOrange.shade700, Colors.deepOrange.shade500]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.14), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isAdmin ? 'Quản lý học phí' : 'Học phí', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _isAdmin
                ? 'Tạo hóa đơn theo lớp, xem danh sách công nợ và quản lý dữ liệu học phí.'
                : 'Xem công nợ và gửi yêu cầu thanh toán học phí của bạn.',
            style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminToolbar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedClass,
                isExpanded: true,
                items: _classOptions.map((c) => DropdownMenuItem(value: c, child: Text('Lớp: $c'))).toList(),
                onChanged: (v) => setState(() => _selectedClass = v ?? 'Tất cả'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại'),
        ),
      ],
    );
  }

  Widget _buildStudentStepper() {
    Color active = Colors.deepOrange.shade700;
    Color inactive = Colors.grey.shade300;

    Widget dot(int index, String label) {
      final selected = _studentStep >= index;
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: selected ? active : inactive, shape: BoxShape.circle),
              child: Center(
                child: Text('$index', style: TextStyle(color: selected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, color: selected ? active : Colors.grey.shade600)),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            dot(1, 'Chọn công nợ'),
            Expanded(child: Container(height: 2, color: _studentStep >= 2 ? active : inactive)),
            dot(2, 'Chọn phương thức'),
            Expanded(child: Container(height: 2, color: _studentStep >= 3 ? active : inactive)),
            dot(3, 'Xác nhận'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_summary.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chưa có dữ liệu học phí'),
        ),
      );
    }

    final item = _summary.first;
    final totalInvoiced = num.tryParse(item['total_invoiced'].toString()) ?? 0;
    final totalPaid = num.tryParse(item['total_paid'].toString()) ?? 0;
    final balance = num.tryParse(item['balance'].toString()) ?? 0;
    final paidRatio = totalInvoiced > 0 ? (totalPaid / totalInvoiced).clamp(0, 1).toDouble() : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng quan học phí', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: paidRatio,
                minHeight: 10,
                backgroundColor: Colors.orange.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange.shade700),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _statChip('Tổng thu', totalInvoiced.toStringAsFixed(0), Colors.deepOrange)),
                const SizedBox(width: 8),
                Expanded(child: _statChip('Đã đóng', totalPaid.toStringAsFixed(0), Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _statChip('Còn nợ', balance.toStringAsFixed(0), Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildInvoiceFormCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tạo hóa đơn theo lớp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedClass,
                    items: _classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedClass = v ?? 'Tất cả'),
                    decoration: const InputDecoration(labelText: 'Chọn lớp', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _invoiceCodeController,
                    decoration: const InputDecoration(labelText: 'Mã hóa đơn', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceTitleController,
              decoration: const InputDecoration(labelText: 'Tên hóa đơn', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _invoiceAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số tiền', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _invoiceDueDateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Hạn thanh toán', border: OutlineInputBorder()),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _invoiceDueDateController.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingInvoice ? null : _createInvoicesForClass,
                icon: const Icon(Icons.receipt_long),
                label: Text(_isSavingInvoice ? 'Đang tạo...' : 'Tạo hóa đơn cho lớp'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminInvoiceList() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Danh sách hóa đơn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: _invoices.where((i) => (i['status'] ?? 'pending').toString() != 'cancelled').isEmpty
                  ? const Center(child: Text('Chưa có hóa đơn'))
                  : ListView.separated(
                      itemCount: _invoices.where((i) => (i['status'] ?? 'pending').toString() != 'cancelled').length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final visibleInvoices = _invoices.where((i) => (i['status'] ?? 'pending').toString() != 'cancelled').toList();
                        return _buildInvoiceCard(visibleInvoices[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> item) {
    final remaining = num.tryParse(item['remaining_amount'].toString()) ?? 0;
    final invoiceId = item['id'] as int?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepOrange.withOpacity(0.12),
          child: const Icon(Icons.receipt_long, color: Colors.deepOrange),
        ),
        title: Text(item['title']?.toString() ?? item['invoice_code']?.toString() ?? 'Hóa đơn'),
        subtitle: Text('${item['full_name'] ?? ''} • Lớp: ${item['class_name'] ?? ''}\nCòn nợ: ${remaining.toStringAsFixed(0)}'),
        trailing: _isAdmin && invoiceId != null
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showInvoiceDialog(existing: item);
                  } else if (value == 'delete') {
                    _deleteInvoice(invoiceId);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _deleteInvoice(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy hóa đơn'),
        content: const Text('Bạn có chắc muốn hủy hóa đơn này không? Hóa đơn sẽ được giữ lại nhưng chuyển sang trạng thái đã hủy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.deleteTuitionInvoice(id);
      if (!mounted) return;
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa hóa đơn')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xóa được hóa đơn: $e')));
      }
    }
  }

  void _showInvoiceDialog({Map<String, dynamic>? existing}) {
    final codeController = TextEditingController(text: existing?['invoice_code']?.toString() ?? '');
    final titleController = TextEditingController(text: existing?['title']?.toString() ?? '');
    final amountController = TextEditingController(text: existing?['amount']?.toString() ?? '');
    final dueDateController = TextEditingController(text: existing?['due_date']?.toString() ?? '');
    String selectedClass = existing?['class_name']?.toString() ?? _selectedClass;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Tạo hóa đơn' : 'Sửa hóa đơn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _classOptions.contains(selectedClass) ? selectedClass : _classOptions.first,
                  items: _classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDlg(() => selectedClass = v ?? 'Tất cả'),
                  decoration: const InputDecoration(labelText: 'Lớp', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Mã hóa đơn', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Tên hóa đơn', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDateController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Hạn thanh toán', border: OutlineInputBorder()),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      dueDateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                if (titleController.text.trim().isEmpty || amount <= 0 || selectedClass == 'Tất cả') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin')));
                  return;
                }
                try {
                  final payload = {
                    'student_id': existing?['student_id'],
                    'invoice_code': codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                    'title': titleController.text.trim(),
                    'amount': amount,
                    'due_date': dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
                    'class_name': selectedClass,
                  };
                  if (existing == null) {
                    final targetStudents = _students.where((s) => (s['class_name'] ?? '').toString().trim() == selectedClass).toList();
                    for (final student in targetStudents) {
                      await ApiService.addTuitionInvoice({...payload, 'student_id': student['id']});
                    }
                  } else {
                    await ApiService.updateTuitionInvoice(existing['id'], payload);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được hóa đơn: $e')));
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentContent() {
    final pendingInvoices = _pendingInvoices;
    return ListView(
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 12),
        if (_studentStep == 1) ...[
          const Text('Màn 1 · Chọn công nợ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (pendingInvoices.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Không có công nợ nào'),
              ),
            )
          else
            ...pendingInvoices.map(_buildDebtCard),
        ],
        if (_studentStep == 2) ...[
          const Text('Màn 2 · Chọn phương thức thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildPaymentMethodCard(),
        ],
        if (_studentStep == 3) ...[
          const Text('Màn 3 · Xác nhận thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildConfirmCard(),
        ],
        const SizedBox(height: 12),
        const Text('Lịch sử thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_payments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có lịch sử thanh toán'),
            ),
          )
        else
          ..._payments.map((item) => _buildPaymentCard(item)),
      ],
    );
  }

  Widget _buildDebtCard(Map<String, dynamic> item) {
    final remaining = num.tryParse(item['remaining_amount'].toString()) ?? 0;
    final selected = _selectedDebtInvoice != null && _selectedDebtInvoice!['id'] == item['id'];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedDebtInvoice = item;
            _paymentAmountController.text = remaining.toStringAsFixed(0);
            _studentStep = 2;
          });
        },
        leading: CircleAvatar(
          backgroundColor: selected ? Colors.deepOrange.withOpacity(0.12) : Colors.red.withOpacity(0.12),
          child: Icon(selected ? Icons.check_circle : Icons.warning_amber_rounded, color: selected ? Colors.deepOrange : Colors.red),
        ),
        title: Text('Công nợ #${item['id']}'),
        subtitle: Text('${item['full_name'] ?? ''} • ${item['student_code'] ?? ''}\nCòn nợ: ${remaining.toStringAsFixed(0)} • Hạn: ${item['due_date'] ?? ''}'),
        trailing: Text(remaining <= 0 ? 'Đủ' : 'Nợ ${remaining.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    final invoice = _selectedDebtInvoice;
    if (invoice == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Hãy chọn một công nợ trước để tiếp tục'),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đã chọn công nợ #${invoice['id']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              items: const [
                DropdownMenuItem(value: 'atm', child: Text('ATM')),
                DropdownMenuItem(value: 'visa', child: Text('Visa')),
                DropdownMenuItem(value: 'master', child: Text('Master')),
              ],
              onChanged: (v) => setState(() => _selectedPaymentMethod = v ?? 'atm'),
              decoration: const InputDecoration(
                labelText: 'Phương thức thanh toán',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _studentStep = 3),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Tiếp tục'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmCard() {
    final invoice = _selectedDebtInvoice;
    if (invoice == null) return const SizedBox.shrink();

    final remaining = num.tryParse(invoice['remaining_amount'].toString()) ?? 0;
    final amount = _paymentAmountController.text.trim().isNotEmpty
        ? double.tryParse(_paymentAmountController.text.trim()) ?? remaining.toDouble()
        : remaining.toDouble();
    final studentCode = invoice['student_code']?.toString().trim() ?? '';
    final studentName = invoice['full_name']?.toString().trim() ?? '';
    final transferContent = [studentCode, studentName].where((e) => e.isNotEmpty).join(' ');
    final qrUrl =
        'https://img.vietqr.io/image/$_bankBin-$_bankAccountNumber-print.png?amount=${amount.toStringAsFixed(0)}&addInfo=${Uri.encodeComponent(transferContent)}&accountName=${Uri.encodeComponent(_bankAccountName)}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xác nhận thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Nội dung CK: $transferContent', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                qrUrl,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  alignment: Alignment.center,
                  color: Colors.orange.shade50,
                  child: const Text('Không tải được mã QR'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paymentAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền thanh toán', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paymentNoteController,
              decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createPayment,
                icon: const Icon(Icons.payments),
                label: const Text('Thanh toán'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _studentStep = 1),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
    final label = isPending ? 'Chờ xác nhận' : 'Đã xác nhận';
    final color = isPending ? Colors.orange : Colors.green;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(Icons.payments, color: color)),
        title: Text('Thanh toán #${item['id']}'),
        subtitle: Text('Số tiền: ${item['amount'] ?? 0} | Ngày: ${item['payment_date'] ?? ''}\nHóa đơn: #${item['invoice_id'] ?? ''} • $label'),
      ),
    );
  }
}
