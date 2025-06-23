import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 主题服务Provider
final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

// 主题模式Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.read(themeServiceProvider));
});

// 字体大小Provider
final fontSizeProvider = StateNotifierProvider<FontSizeNotifier, double>((ref) {
  return FontSizeNotifier(ref.read(themeServiceProvider));
});

class ThemeService {
  static const String _themeModeKey = 'theme_mode';
  static const String _fontSizeKey = 'font_size';

  // 获取保存的主题模式
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_themeModeKey) ?? 0; // 默认为系统主题
    return ThemeMode.values[modeIndex];
  }

  // 保存主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  // 获取保存的字体大小
  Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? 1.0; // 默认为标准大小
  }

  // 保存字体大小
  Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final ThemeService _themeService;

  ThemeModeNotifier(this._themeService) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    state = await _themeService.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _themeService.setThemeMode(mode);
  }

  void toggleTheme() {
    switch (state) {
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.system:
        setThemeMode(ThemeMode.dark);
        break;
    }
  }

  String get themeModeDisplayName {
    switch (state) {
      case ThemeMode.light:
        return '明亮模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  IconData get themeModeIcon {
    switch (state) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.settings_brightness;
    }
  }
}

class FontSizeNotifier extends StateNotifier<double> {
  final ThemeService _themeService;

  FontSizeNotifier(this._themeService) : super(1.0) {
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    state = await _themeService.getFontSize();
  }

  Future<void> setFontSize(double size) async {
    // 限制字体大小范围
    final clampedSize = size.clamp(0.8, 1.5);
    state = clampedSize;
    await _themeService.setFontSize(clampedSize);
  }

  void increaseFontSize() {
    setFontSize(state + 0.1);
  }

  void decreaseFontSize() {
    setFontSize(state - 0.1);
  }

  void resetFontSize() {
    setFontSize(1.0);
  }

  String get fontSizeDisplayName {
    if (state <= 0.9) {
      return '小号字体';
    } else if (state >= 1.3) {
      return '大号字体';
    } else {
      return '标准字体';
    }
  }

  String get fontSizePercentage {
    return '${(state * 100).round()}%';
  }
}

// 主题扩展，用于根据字体大小调整TextTheme
extension ThemeDataExtension on ThemeData {
  ThemeData copyWithFontSize(double fontSize) {
    return copyWith(
      textTheme: textTheme.apply(fontSizeFactor: fontSize),
      primaryTextTheme: primaryTextTheme.apply(fontSizeFactor: fontSize),
    );
  }
} 