import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../appointments/application/appointments_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../tickets/presentation/new_ticket_dialog.dart';

/// الرئيسية لواجهة العميل — أربعة إجراءات فقط بلا أي إضافات: طلب استشارة،
/// حسابي، رفع تذكرة دعم، مواعيدي.
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final appointmentsAsync = ref.watch(myAppointmentsProvider);
    final upcomingCount = appointmentsAsync.valueOrNull?.length ?? 0;

    return Column(
      children: [
        GlowBanner(
          icon: Icons.home_outlined,
          title: 'مرحباً ${profileAsync.valueOrNull?.name ?? ''} 👋',
          subtitle: 'كيف نقدر نساعدك اليوم؟',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: [
                FadeSlideIn(
                  index: 0,
                  child: QuickActionTile(
                    icon: Icons.smart_toy_outlined,
                    label: 'طلب استشارة',
                    color: AppColors.gold,
                    onTap: () => context.go('/client/ai-intake'),
                  ),
                ),
                FadeSlideIn(
                  index: 1,
                  child: QuickActionTile(
                    icon: Icons.person_outline,
                    label: 'حسابي',
                    color: AppColors.primary,
                    onTap: () => context.push('/my-account'),
                  ),
                ),
                FadeSlideIn(
                  index: 2,
                  child: QuickActionTile(
                    icon: Icons.support_agent_outlined,
                    label: 'رفع تذكرة للدعم',
                    color: AppColors.danger,
                    onTap: () async {
                      final id = await showDialog<String>(context: context, builder: (_) => const NewTicketDialog());
                      if (id != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ تم إرسال طلب تذكرتك بنجاح'), backgroundColor: AppColors.success));
                        context.push('/tickets/$id');
                      }
                    },
                  ),
                ),
                FadeSlideIn(
                  index: 3,
                  child: QuickActionTile(
                    icon: Icons.event_outlined,
                    label: 'مواعيدي',
                    color: AppColors.success,
                    badgeCount: upcomingCount,
                    onTap: () => context.go('/client/appointments'),
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
