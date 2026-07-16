import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const AccountScreen({super.key, required this.profile});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Uint8List? _avatarBytes;
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};

  String get _avatarKey {
    final username = _profile['username']?.toString().trim();
    final studentCode = _profile['student_code']?.toString().trim();
    final role = _profile['role']?.toString().trim();
    return 'avatar_bytes_${username?.isNotEmpty == true ? username : (studentCode?.isNotEmpty == true ? studentCode : role ?? 'user')}';
  }

  String? get _serverAvatarUrl {
    final raw = _profile['avatar_url']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  ImageProvider? _avatarImageProvider() {
    if (_avatarBytes != null) return MemoryImage(_avatarBytes!);
    final raw = _serverAvatarUrl;
    if (raw == null) return null;
    if (raw.startsWith('data:image')) {
      final commaIndex = raw.indexOf(',');
      if (commaIndex != -1 && commaIndex < raw.length - 1) {
        try {
          return MemoryImage(base64Decode(raw.substring(commaIndex + 1)));
        } catch (_) {
          return null;
        }
      }
    }
    return NetworkImage(raw);
  }

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final latest = await ApiService.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = {
          ...widget.profile,
          ...latest,
        };
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    final prefs = await SharedPreferences.getInstance();
    final savedBytes = prefs.getString(_avatarKey);
    if (savedBytes == null || savedBytes.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _avatarBytes = base64Decode(savedBytes);
    });
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Image';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, base64Image);

    try {
      await ApiService.updateMyAvatar(dataUrl);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Đổi mật khẩu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setD(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setD(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setD(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  if (newController.text.trim() != confirmController.text.trim()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
                    );
                    return;
                  }
                  try {
                    await ApiService.changePassword(currentController.text.trim(), newController.text.trim());
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đổi mật khẩu thành công')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Không đổi được mật khẩu: $e')),
                    );
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _profile['full_name']?.toString().trim().isNotEmpty == true
        ? _profile['full_name'].toString()
        : (_profile['username']?.toString() ?? 'Tài khoản');

    final studentCode = _profile['student_code']?.toString() ?? '—';
    final gender = _profile['gender']?.toString() ?? '—';
    final birthDate = _formatDate(_profile['birth_date']);
    final className = _profile['class_name']?.toString() ?? '—';
    final email = _profile['email']?.toString() ?? '—';
    final phone = _profile['phone']?.toString() ?? '—';
    final status = _profile['status']?.toString() ?? 'Đang học';
    final role = _profile['role']?.toString() ?? 'student';
    final avatarProvider = _avatarImageProvider();
    final avatar = avatarProvider != null
        ? CircleAvatar(radius: 48, backgroundImage: avatarProvider)
        : CircleAvatar(
            radius: 48,
            backgroundColor: Colors.blue.shade100,
            child: const Icon(Icons.person, size: 54, color: Colors.blue),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 260,
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  title: const Text('Thông tin sinh viên'),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade700, Colors.blue.shade500],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: _changeAvatar,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: avatar,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fullName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Chạm vào ảnh đại diện để thay đổi',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip('Vai trò: ${role == 'student' ? 'Sinh viên' : role}', Colors.blue),
                            _chip('Trạng thái: $status', Colors.green),
                            _chip('Lớp: $className', Colors.purple),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          child: Column(
                            children: [
                              _infoTile('MSSV', studentCode),
                              _divider(),
                              _infoTile('Họ tên', fullName),
                              _divider(),
                              _infoTile('Giới tính', gender),
                              _divider(),
                              _infoTile('Ngày sinh', birthDate),
                              _divider(),
                              _infoTile('Lớp', className),
                              _divider(),
                              _infoTile('Số điện thoại', phone),
                              _divider(),
                              _infoTile('Email', email),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 1, color: Colors.grey.shade200);

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final str = value.toString();
    if (str.length >= 10) {
      final y = str.substring(0, 4);
      final m = str.substring(5, 7);
      final d = str.substring(8, 10);
      return '$d/$m/$y';
    }
    return str;
  }
}
