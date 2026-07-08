import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/dashboard/application/recent_activity_providers.dart';
import 'adaptive_scaffold.dart';
import 'common_widgets.dart';

const _clientNavItems = [
  NavItem(label: 'الرئيسية', icon: Icons.home_outlined, selectedIcon: Icons.home, path: '/client/home'),
  NavItem(label: 'استشاراتي', icon: Icons.forum_outlined, selectedIcon: Icons.forum, path: '/client/consultations'),
  NavItem(label: 'تذاكري', icon: Icons.support_agent_outlined, selectedIcon: Icons.support_agent, path: '/client/tickets'),
  NavItem(label: 'الإعدادات', icon: Icons.settings_outlined, selectedIcon: Icons.settings, path: '/client/settings'),
];

/// نفس فكرة MainShell لكن بقائمة العميل — يقابل تبويبات client-dashboard.html
/// بدل admin.html.
class ClientShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const ClientShell({super.key, required this.child, required this.location});

  static const _titles = {
    '/client/home': 'الرئيسية',
    '/client/consultations': 'استشاراتي',
    '/client/ai-intake': 'استشارة جديدة',
    '/client/appointments': 'مواعيدي',
    '/client/tickets': 'تذاكري',
    '/client/settings': 'الإعدادات',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _clientNavItems.indexWhere((e) => e.path == location);
    final notifCount = ref.watch(clientNotificationCountProvider).valueOrNull ?? 0;

    return AdaptiveScaffold(
      currentIndex: index < 0 ? 0 : index,
      items: _clientNavItems,
      title: _titles[location] ?? 'رواد الأنظمة',
      onDestinationSelected: (i) => context.go(_clientNavItems[i].path),
      actions: [
        NotificationBellButton(
          count: notifCount,
          onTap: () {
            markClientNotificationsSeen(ref);
            context.push('/client/activity');
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'تسجيل الخروج',
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
            ref.invalidate(currentProfileProvider);
          },
        ),
      ],
      child: child,
    );
  }
}
