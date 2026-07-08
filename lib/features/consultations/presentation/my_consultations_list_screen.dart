import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/consultation.dart';
import '../application/consultations_providers.dart';

/// "استشاراتي" — نفس تبويب client-dashboard.html، تعرض استشارات العميل
/// الحالي فقط (client_id = المستخدم المسجّل دخوله).
class MyConsultationsListScreen extends ConsumerWidget {
  const MyConsultationsListScreen({super.key});

  Color _statusColor(ConsultationStatus s) {
    switch (s) {
      case ConsultationStatus.pending:
        return AppColors.gold;
      case ConsultationStatus.inReview:
        return AppColors.primary;
      case ConsultationStatus.closed:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(myConsultationsProvider);

    return Column(
      children: [
        const GlowBanner(icon: Icons.forum_outlined, title: 'استشاراتي', subtitle: 'تابع حالة طلبات استشارتك'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(myConsultationsProvider),
            child: consultationsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'تعذّر تحميل استشاراتك', onRetry: () => ref.invalidate(myConsultationsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(message: 'لا توجد لديك استشارات بعد', icon: Icons.forum_outlined),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = items[i];
              return FadeSlideIn(
                index: i,
                child: ModernCard(
                  padding: EdgeInsets.zero,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: _statusColor(c.status), width: 4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListTile(
                      title: Text(c.caseSummary ?? 'استشارة بدون ملخص', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(DateFormat('yyyy/MM/dd').format(c.createdAt)),
                      trailing: StatusBadge(label: consultationStatusToArabic(c.status), color: _statusColor(c.status)),
                      onTap: () => context.push('/consultations/${c.id}'),
                    ),
                  ),
                ),
              );
            },
          );
        },
            ),
          ),
        ),
      ],
    );
  }
}
