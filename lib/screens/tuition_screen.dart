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
  final _paymentAmountController = TextEditingController();
  final _paymentNoteController = TextEditingController();

  bool _isLoading = false;
  List _summary = [];
  List _invoices = [];
  List _payments = [];
  Map<String, dynamic>? _selectedDebtInvoice;
  String _selectedPaymentMethod = 'atm';
  int _step = 1;

  static const String _bankName = 'Vietcombank';
  static const String _bankAccountName = 'NGUYEN VAN A';
  static const String _bankAccountNumber = '0123456789';
  static const String _bankBin = '970436';

  @override
  void initState() {
    super.initState();
    _studentIdController.text = widget.studentId?.toString() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _paymentAmountController.dispose();
    _paymentNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final studentId = widget.studentId ?? int.tryParse(_studentIdController.text.trim());
      final summary = await ApiService.getTuitionSummary(studentId: studentId);
      final invoices = await ApiService.getTuitionInvoices(studentId: studentId);
      final payments = await ApiService.getTuitionPayments(studentId: studentId);

      setState(() {
        _summary = summary;
        _invoices = invoices;
        _payments = payments;
        if (_selectedDebtInvoice != null && !_invoices.any((i) => i['id'] == _selectedDebtInvoice!['id'])) {
          _selectedDebtInvoice = null;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _pendingInvoices {
    return _invoices
        .where((i) => (num.tryParse(i['remaining_amount'].toString()) ?? 0) > 0)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _createPayment() async {
    final invoice = _selectedDebtInvoice;
    final invoiceId = invoice?['id'] as int?;
    final studentId = invoice?['student_id'] as int?;
    final amount = double.tryParse(_paymentAmountController.text.trim()) ?? 0;

    if (invoiceId == null || studentId == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn công nợ và nhập số tiền hợp lệ')),
        );
      }
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
      _step = 1;
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu thanh toán')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thanh toán: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingInvoices = _pendingInvoices;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Thanh toán học phí'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildStepper(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 12),
                        if (_step == 1) ...[
                          _buildStepTitle('Màn 1 · Chọn công nợ'),
                          const SizedBox(height: 8),
                          ...pendingInvoices.map((item) => _buildDebtCard(item)),
                        ],
                        if (_step == 2) ...[
                          _buildStepTitle('Màn 2 · Chọn phương thức thanh toán'),
                          const SizedBox(height: 8),
                          _buildPaymentMethodCard(),
                        ],
                        if (_step == 3) ...[
                          _buildStepTitle('Màn 3 · Xác nhận thanh toán'),
                          const SizedBox(height: 8),
                          _buildConfirmCard(),
                        ],
                        const SizedBox(height: 12),
                        _buildStepTitle('Lịch sử thanh toán'),
                        const SizedBox(height: 8),
                        ..._payments.map((item) => _buildPaymentCard(Map<String, dynamic>.from(item))),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sinh viên thanh toán học phí', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _studentIdController,
              keyboardType: TextInputType.number,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'ID sinh viên',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.receipt_long),
                label: const Text('Tải dữ liệu học phí'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    Color active = Colors.deepOrange.shade700;
    Color inactive = Colors.grey.shade300;

    Widget dot(int index, String label) {
      final selected = _step >= index;
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? active : inactive,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            Expanded(child: Container(height: 2, color: _step >= 2 ? active : inactive)),
            dot(2, 'Chọn phương thức'),
            Expanded(child: Container(height: 2, color: _step >= 3 ? active : inactive)),
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

    final item = Map<String, dynamic>.from(_summary.first);
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
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
            _step = 2;
          });
        },
        leading: CircleAvatar(
          backgroundColor: selected ? Colors.deepOrange.withOpacity(0.12) : Colors.red.withOpacity(0.12),
          child: Icon(selected ? Icons.check_circle : Icons.warning_amber_rounded, color: selected ? Colors.deepOrange : Colors.red),
        ),
        title: Text('Công nợ #${item['id']}'),
        subtitle: Text(
          '${item['full_name'] ?? ''} • ${item['student_code'] ?? ''}\nCòn nợ: ${remaining.toStringAsFixed(0)} • Hạn: ${item['due_date'] ?? ''}',
        ),
        trailing: Text(
          remaining <= 0 ? 'Đủ' : 'Nợ ${remaining.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    final invoice = _selectedDebtInvoice;
    if (invoice == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
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
                onPressed: () => setState(() => _step = 3),
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
    if (invoice == null) {
      return const SizedBox.shrink();
    }
    final remaining = num.tryParse(invoice['remaining_amount'].toString()) ?? 0;
    final amount = _paymentAmountController.text.trim().isNotEmpty
        ? double.tryParse(_paymentAmountController.text.trim()) ?? remaining.toDouble()
        : remaining.toDouble();
    final transferContent = 'HP-${_studentIdController.text.trim()}-${invoice['id']}';
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ngân hàng: $_bankName'),
                  Text('Số tài khoản: $_bankAccountNumber'),
                  Text('Chủ tài khoản: $_bankAccountName'),
                  Text('Nội dung CK: $transferContent'),
                  Text('Phương thức: $_selectedPaymentMethod'),
                  Text('Số tiền: ${amount.toStringAsFixed(0)}'),
                ],
              ),
            ),
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
              decoration: const InputDecoration(
                labelText: 'Số tiền thanh toán',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paymentNoteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
              ),
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
              onPressed: () => setState(() => _step = 1),
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
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(Icons.payments, color: color),
        ),
        title: Text('Thanh toán #${item['id']}'),
        subtitle: Text(
          'Số tiền: ${item['amount'] ?? 0} | Ngày: ${item['payment_date'] ?? ''}\nHóa đơn: #${item['invoice_id'] ?? ''} • $label',
        ),
      ),
    );
  }

  Widget _buildStepTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }
}
