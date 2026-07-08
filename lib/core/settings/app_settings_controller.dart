import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontScale { small, medium, large }

extension AppFontScaleX on AppFontScale {
  double get scale {
    switch (this) {
      case AppFontScale.small:
        return 0.9;
      case AppFontScale.medium:
        return 1.0;
      case AppFontScale.large:
        return 1.18;
    }
  }

  String get label {
    switch (this) {
      case AppFontScale.small:
        return 'صغير';
      case AppFontScale.medium:
        return 'متوسط';
      case AppFontScale.large:
        return 'كبير';
    }
  }
}

class AppSettingsState {
  final ThemeMode themeMode;
  final AppFontScale fontScale;
  final Locale locale;

  const AppSettingsState({
    this.themeMode = ThemeMode.light,
    this.fontScale = AppFontScale.medium,
    this.locale = const Locale('ar'),
  });

  AppSettingsState copyWith({ThemeMode? themeMode, AppFontScale? fontScale, Locale? locale}) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      locale: locale ?? this.locale,
    );
  }
}

const _kThemeKey = 'app_theme_mode';
const _kFontKey = 'app_font_scale';
const _kLocaleKey = 'app_locale';

/// يحفظ تفضيلات التطبيق (الثيم/حجم الخط/اللغة) محليًا عبر SharedPreferences
/// بحيث تبقى بعد إغلاق التطبيق وإعادة فتحه.
class AppSettingsController extends StateNotifier<AppSettingsState> {
  final SharedPreferences _prefs;

  AppSettingsController(this._prefs) : super(_load(_prefs));

  static AppSettingsState _load(SharedPreferences prefs) {
    final themeStr = prefs.getString(_kThemeKey);
    final fontStr = prefs.getString(_kFontKey);
    final localeStr = prefs.getString(_kLocaleKey);

    final themeMode = switch (themeStr) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    final fontScale = AppFontScale.values.firstWhere(
      (e) => e.name == fontStr,
      orElse: () => AppFontScale.medium,
    );

    return AppSettingsState(
      themeMode: themeMode,
      fontScale: fontScale,
      locale: Locale(localeStr ?? 'ar'),
    );
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setString(_kThemeKey, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  void setFontScale(AppFontScale scale) {
    _prefs.setString(_kFontKey, scale.name);
    state = state.copyWith(fontScale: scale);
  }

  void setLocale(Locale locale) {
    _prefs.setString(_kLocaleKey, locale.languageCode);
    state = state.copyWith(locale: locale);
  }
}

/// يُملأ فعليًا بقيمة حقيقية في main.dart عبر ProviderScope overrides.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

final appSettingsProvider = StateNotifierProvider<AppSettingsController, AppSettingsState>((ref) {
  return AppSettingsController(ref.watch(sharedPreferencesProvider));
});
