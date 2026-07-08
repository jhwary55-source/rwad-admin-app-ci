import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings_controller.dart';
import '../../../core/widgets/common_widgets.dart';

/// "الإعدادات" — تفضيلات التطبيق فقط (المظهر/حجم الخط/اللغة)، وليست بيانات
/// حساب العميل — تلك انتقلت لشاشة "حسابي" المنفصلة (`AccountScreen`)، يوصل
/// لها من الزر بأسفل هذه الشاشة.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Column(
      children: [
        const GlowBanner(icon: Icons.settings_outlined, title: 'الإعدادات', subtitle: 'تفضيلات التطبيق'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'المظهر'),
              const SizedBox(height: 10),
              ModernCard(
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('فاتح')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('داكن')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('النظام')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (v) => notifier.setThemeMode(v.first),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'حجم الخط'),
              const SizedBox(height: 10),
              ModernCard(
                child: SegmentedButton<AppFontScale>(
                  segments: AppFontScale.values
                      .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                      .toList(),
                  selected: {settings.fontScale},
                  onSelectionChanged: (v) => notifier.setFontScale(v.first),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'اللغة'),
              const SizedBox(height: 10),
              ModernCard(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {settings.locale.languageCode},
                  onSelectionChanged: (v) => notifier.setLocale(Locale(v.first)),
                ),
              ),
              const SizedBox(height: 28),
              ModernCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('حسابي'),
                  subtitle: const Text('عرض الملف الشخصي وتسجيل الخروج'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/my-account'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
