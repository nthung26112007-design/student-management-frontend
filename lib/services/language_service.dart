import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const _key = 'app_language';
  Locale _locale = const Locale('vi');

  Locale get locale => _locale;
  bool get isVietnamese => _locale.languageCode == 'vi';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _locale = Locale(preferences.getString(_key) == 'en' ? 'en' : 'vi');
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    final normalized = languageCode == 'en' ? 'en' : 'vi';
    if (_locale.languageCode == normalized) return;
    _locale = Locale(normalized);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, normalized);
    notifyListeners();
  }

  String text(String vietnamese, String english) => isVietnamese ? vietnamese : english;
}
