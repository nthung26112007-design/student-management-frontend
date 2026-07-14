import 'package:flutter/material.dart';
import 'grades_screen.dart';

/// Màn "Quản lý điểm" dạng bảng admin (giống [GradesScreen]).
///
/// Trước đây màn này hiển thị danh sách sinh viên; đã được redesign thành
/// bảng quản lý điểm đồng nhất với [GradesScreen] để không phải maintain
/// 2 implementation trùng nhau.
class StudentsGradesScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const GradesScreen();
  }
}