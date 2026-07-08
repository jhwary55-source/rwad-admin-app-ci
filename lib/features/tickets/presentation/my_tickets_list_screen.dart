import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/support_ticket.dart';
import '../application/tickets_providers.dart';
import 'new_ticket_dialog.dart';

/// "الدعم الفني" لواجهة العميل — تذاكري فقط + إنشاء تذكرة جديدة.
class MyTicketsListScreen extends ConsumerWidget {
  const MyTicketsListScreen({super.key});

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
    final ticketsAsync = ref.watch(myTicketsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final id = await showDialog<String>(context: context, builder: (_) => const NewTicketDialog());
          if (id != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ تم إرسال طلب تذكرتك بنجاح'), backgroundColor: AppColors.success));
            context.push('/tickets/$id');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('تذكرة جديدة'),
      ),
      body: Column(
        children: [
          const GlowBanner(icon: Icons.support_agent_outlined, title: 'تذاكري', subtitle: 'تذاكرك وطلبات الدعم الخاصة بك'),
          Expanded(
            child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTicketsProvider),
        child: ticketsAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: 'تعذّر تحميل تذاكرك', onRetry: () => ref.invalidate(myTicketsProvider)),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(message: 'لا توجد لديك تذاكر دعم', icon: Icons.support_agent_outlined),
                ],
              );
            }
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
                        subtitle: Text(t.category ?? ''),
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
          ),
        ],
      ),
    );
  }
}
