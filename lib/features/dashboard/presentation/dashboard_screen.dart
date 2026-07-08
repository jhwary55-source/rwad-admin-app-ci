import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../application/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Column(
      children: [
        GlowBanner(
          icon: Icons.dashboard_outlined,
          title: 'مرحباً ${profileAsync.valueOrNull?.name ?? ''} 👋',
          subtitle: 'نظرة عامة على نشاط اليوم',
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardStatsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          statsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: LoadingView()),
            error: (e, _) => ErrorView(message: 'تعذّر تحميل الإحصائيات', onRetry: () => ref.invalidate(dashboardStatsProvider)),
            data: (stats) => GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                FadeSlideIn(
                  index: 0,
                  child: KpiCard(
                    label: 'استشارات قيد الانتظار',
                    value: '${stats.pendingConsultations}',
                    icon: Icons.forum_outlined,
                    color: AppColors.gold,
                  ),
                ),
                FadeSlideIn(
                  index: 1,
                  child: KpiCard(
                    label: 'تذاكر دعم مفتوحة',
                    value: '${stats.openTickets}',
                    icon: Icons.support_agent_outlined,
                    color: AppColors.danger,
                  ),
                ),
                FadeSlideIn(
                  index: 2,
                  child: KpiCard(
                    label: 'مواعيد قادمة',
                    value: '${stats.upcomingAppointments}',
                    icon: Icons.event_outlined,
                    color: AppColors.primary,
                  ),
                ),
                FadeSlideIn(
                  index: 3,
                  child: KpiCard(
                    label: 'إجمالي العملاء',
                    value: '${stats.totalClients}',
                    icon: Icons.people_outline,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'اختصارات سريعة'),
          const SizedBox(height: 10),
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (stats) => GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                FadeSlideIn(
                  index: 0,
                  child: QuickActionTile(
                    icon: Icons.forum_outlined,
                    label: 'الاستشارات',
                    color: AppColors.gold,
                    badgeCount: stats.pendingConsultations,
                    onTap: () => context.go('/consultations'),
                  ),
                ),
                FadeSlideIn(
                  index: 1,
                  child: QuickActionTile(
                    icon: Icons.event_outlined,
                    label: 'المواعيد',
                    color: AppColors.primary,
                    onTap: () => context.go('/appointments'),
                  ),
                ),
                FadeSlideIn(
                  index: 2,
                  child: QuickActionTile(
                    icon: Icons.support_agent_outlined,
                    label: 'الدعم الفني',
                    color: AppColors.danger,
                    badgeCount: stats.openTickets,
                    onTap: () => context.go('/tickets'),
                  ),
                ),
                FadeSlideIn(
                  index: 3,
                  child: QuickActionTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'التحليلات',
                    color: AppColors.success,
                    onTap: () => context.go('/analytics'),
                  ),
                ),
                FadeSlideIn(
                  index: 4,
                  child: QuickActionTile(
                    icon: Icons.timeline_outlined,
                    label: 'النشاط الأخير',
                    color: AppColors.primaryDark,
                    onTap: () => context.push('/activity'),
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
