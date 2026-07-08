import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/consultation.dart';
import '../../chat/application/chat_providers.dart';
import '../application/consultations_providers.dart';

class ConsultationsListScreen extends ConsumerWidget {
  const ConsultationsListScreen({super.key});

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
    final consultationsAsync = ref.watch(consultationsListProvider);
    final filter = ref.watch(consultationsFilterProvider);

    return Column(
      children: [
        const GlowBanner(icon: Icons.forum_outlined, title: 'الاستشارات', subtitle: 'متابعة طلبات استشارة العملاء'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: filter == null,
                  onSelected: (_) => ref.read(consultationsFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                for (final s in ConsultationStatus.values) ...[
                  ChoiceChip(
                    label: Text(consultationStatusToArabic(s)),
                    selected: filter == s,
                    onSelected: (_) => ref.read(consultationsFilterProvider.notifier).state = s,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: consultationsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: 'تعذّر تحميل الاستشارات', onRetry: () => ref.invalidate(consultationsListProvider)),
            data: (items) {
              if (items.isEmpty) return const EmptyState(message: 'لا توجد استشارات', icon: Icons.forum_outlined);
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
                          title: Text(c.clientName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.caseSummary ?? 'بدون ملخص',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (c.assignedTo != null) _ClaimerLabel(staffId: c.assignedTo!),
                            ],
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(label: consultationStatusToArabic(c.status), color: _statusColor(c.status)),
                              const SizedBox(height: 4),
                              Text(DateFormat('MM/dd').format(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
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
      ],
    );
  }
}

/// اسم الموظف المستلم — يظهر بالقائمة ليعرف بقية الموظفين من يستلم كل استشارة.
class _ClaimerLabel extends ConsumerWidget {
  final String staffId;
  const _ClaimerLabel({required this.staffId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(profileByIdProvider(staffId)).valueOrNull;
    return Text(
      'المستلم: ${staff?.name ?? '...'}',
      style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600),
    );
  }
}
