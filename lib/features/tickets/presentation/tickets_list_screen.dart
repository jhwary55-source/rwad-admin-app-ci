import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/support_ticket.dart';
import '../../chat/application/chat_providers.dart';
import '../application/tickets_providers.dart';

class TicketsListScreen extends ConsumerWidget {
  const TicketsListScreen({super.key});

  Color _statusColor(TicketStatus s) {
    switch (s) {
      case TicketStatus.open:
        return AppColors.danger;
      case TicketStatus.claimed:
        return AppColors.gold;
      case TicketStatus.closed:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(ticketsListProvider);
    final filter = ref.watch(ticketsFilterProvider);

    return Column(
      children: [
        const GlowBanner(icon: Icons.support_agent_outlined, title: 'الدعم الفني', subtitle: 'متابعة تذاكر الدعم وإغلاقها'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: filter == null,
                  onSelected: (_) => ref.read(ticketsFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                for (final s in TicketStatus.values) ...[
                  ChoiceChip(
                    label: Text(ticketStatusToArabic(s)),
                    selected: filter == s,
                    onSelected: (_) => ref.read(ticketsFilterProvider.notifier).state = s,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: 'تعذّر تحميل التذاكر', onRetry: () => ref.invalidate(ticketsListProvider)),
            data: (items) {
              if (items.isEmpty) return const EmptyState(message: 'لا توجد تذاكر دعم', icon: Icons.support_agent_outlined);
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = items[i];
                  return FadeSlideIn(
                    index: i,
                    child: ModernCard(
                      padding: EdgeInsets.zero,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: _statusColor(t.status), width: 4)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListTile(
                          title: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t.clientName),
                              if (t.claimedBy != null) _ClaimerLabel(staffId: t.claimedBy!),
                            ],
                          ),
                          isThreeLine: t.claimedBy != null,
                          trailing: StatusBadge(label: ticketStatusToArabic(t.status), color: _statusColor(t.status)),
                          onTap: () => context.push('/tickets/${t.id}'),
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

/// اسم الموظف المستلم — يظهر بالقائمة ليعرف بقية الموظفين من يستلم كل تذكرة.
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
