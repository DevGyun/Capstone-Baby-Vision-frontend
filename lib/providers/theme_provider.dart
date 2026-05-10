import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자가 명시적으로 설정 가능한 테마 모드.
/// system이 기본값 — 기기 설정 따라감.
enum AppThemePreference { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  AppThemePreference _preference = AppThemePreference.system;

  AppThemePreference get preference => _preference;

  ThemeMode get themeMode {
    switch (_preference) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  /// 현재 적용된 테마가 다크인지 — 시스템 따라가기일 때도 정확하게 판단.
  /// MediaQuery 정보가 필요하므로 BuildContext와 함께 호출.
  bool isDarkMode(BuildContext context) {
    switch (_preference) {
      case AppThemePreference.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      case AppThemePreference.light:
        return false;
      case AppThemePreference.dark:
        return true;
    }
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme');

    switch (themeStr) {
      case 'dark':
        _preference = AppThemePreference.dark;
        break;
      case 'light':
        _preference = AppThemePreference.light;
        break;
      case 'system':
      default:
        _preference = AppThemePreference.system;
    }
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference pref) async {
    _preference = pref;
    final prefs = await SharedPreferences.getInstance();
    final value = switch (pref) {
      AppThemePreference.system => 'system',
      AppThemePreference.light => 'light',
      AppThemePreference.dark => 'dark',
    };
    await prefs.setString('theme', value);
    notifyListeners();
  }

  /// 기존 코드 호환용 — 다크 토글 (시스템 모드 무시).
  /// 새로 만드는 화면에선 setPreference를 직접 쓰는 게 좋아요.
  Future<void> toggleTheme(bool isDark) async {
    await setPreference(
        isDark ? AppThemePreference.dark : AppThemePreference.light);
  }
}