import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class NotificationService {
  static Future<void> init() async {
    // Firebase Messaging chỉ hỗ trợ Android/iOS
    // Windows và Web không hỗ trợ
  }

  static Future<String?> getToken() async {
    return null;
  }
}
