import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/dashboard/application/recent_activity_providers.dart';
import 'adaptive_scaffold.dart';
import 'common_widgets.dart';

const _navItems = [
  NavItem(label: 'الرئيسية', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, path: '/dashboard'),
  NavItem(label: 'المواعيد', icon: Icons.event_outlined, selectedIcon: Icons.event, path: '/appointments'),
  NavItem(label: 'الاستشارات', icon: Icons.forum_outlined, selectedIcon: Icons.forum, path: '/consultations'),
  NavItem(label: 'الدعم الفني', icon: Icons.support_agent_outlined, selectedIcon: Icons.support_agent, path: '/tickets'),
  NavItem(label: 'التحليلات', icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, path: '/analytics'),
  NavItem(label: 'الاتصال', icon: Icons.call_outlined, selectedIcon: Icons.call, path: '/calls'),
  NavItem(label: 'الحسابات', icon: Icons.people_outline, selectedIcon: Icons.people, path: '/accounts'),
  NavItem(label: 'الإعدادات', icon: Icons.settings_outlined, selectedIcon: Icons.settings, path: '/settings'),
];

class MainShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const MainShell({super.key, required this.child, required this.location});

  static const _titles = {
    '/dashboard': 'الرئيسية',
    '/appointments': 'المواعيد',
    '/consultations': 'الاستشارات',
    '/tickets': 'الدعم الفني',
    '/analytics': 'التحليلات',
    '/calls': 'الاتصال',
    '/accounts': 'الحسابات',
    '/settings': 'الإعدادات',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _navItems.indexWhere((e) => e.path == location);
    final notifCount = ref.watch(staffNotificationCountProvider).valueOrNull ?? 0;

    return AdaptiveScaffold(
      currentIndex: index < 0 ? 0 : index,
      items: _navItems,
      title: _titles[location] ?? 'رواد الأنظمة',
      onDestinationSelected: (i) => context.go(_navItems[i].path),
      actions: [
        NotificationBellButton(
          count: notifCount,
          onTap: () {
            markStaffNotificationsSeen(ref);
            context.push('/activity');
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
