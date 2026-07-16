import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/language_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passwordField(
                  controller: currentController,
                  label: 'Mật khẩu hiện tại',
                  obscure: obscureCurrent,
                  onToggle: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: newController,
                  label: 'Mật khẩu mới',
                  obscure: obscureNew,
                  onToggle: () => setDialogState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: confirmController,
                  label: 'Xác nhận mật khẩu mới',
                  obscure: obscureConfirm,
                  onToggle: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final currentPassword = currentController.text.trim();
                final newPassword = newController.text.trim();
                if (currentPassword.isEmpty || newPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập đầy đủ mật khẩu')),
                  );
                  return;
                }
                if (newPassword != confirmController.text.trim()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
                  );
                  return;
                }
                try {
                  await ApiService.changePassword(currentPassword, newPassword);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đổi mật khẩu thành công'), backgroundColor: Color(0xFF10B981)),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không đổi được mật khẩu: $error'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              },
              child: const Text('Lưu mật khẩu'),
            ),
          ],
        ),
      ),
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  static Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageService>();
    String t(String vi, String en) => language.text(vi, en);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF059669)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('Ngôn ngữ', 'Language'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(t('Thay đổi ngôn ngữ hiển thị của hệ thống.', 'Change the display language of the system.'),
                        style: const TextStyle(color: Color(0xFF6B7280))),
                  ]),
                ),
                const SizedBox(width: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'vi', icon: Text('🇻🇳'), label: Text('Tiếng Việt')),
                    ButtonSegment(value: 'en', icon: Text('🇬🇧'), label: Text('English')),
                  ],
                  selected: {language.locale.languageCode},
                  onSelectionChanged: (value) => language.setLanguage(value.first),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('Mật khẩu', 'Password'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(t('Thay đổi mật khẩu đăng nhập của tài khoản.', 'Change your account login password.'),
                        style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _changePassword(context),
                icon: const Icon(Icons.lock_reset_rounded),
                label: Text(t('Đổi mật khẩu', 'Change password')),
              ),
            ],
          ),
            ),
          ),
        ],
      ),
    );
  }
}
