import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/push_notifications_service.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_providers.dart';

class RwadAdminApp extends ConsumerWidget {
  const RwadAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(appSettingsProvider);

    ref.listen(currentProfileProvider, (prev, next) {
      if (next.valueOrNull != null) {
        PushNotificationsService.syncTokenForCurrentUser(ref.read(supabaseClientProvider));
      }
    });

    return MaterialApp.router(
      title: 'رواد الأنظمة | لوحة التحكم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: router,
      locale: settings.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: settings.locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.fontScale.scale)),
          child: child!,
        ),
      ),
    );
  }
}
