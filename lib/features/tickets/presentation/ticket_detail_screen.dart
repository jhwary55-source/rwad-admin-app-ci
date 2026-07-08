import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/support_ticket.dart';
import '../../appointments/presentation/appointment_form_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../application/tickets_providers.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  bool _ratingPromptShown = false;

  void _maybeShowRatingPrompt(SupportTicket t, bool isStaff) {
    if (isStaff || t.status != TicketStatus.closed || t.rating != null || _ratingPromptShown) return;
    _ratingPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _TicketRatingDialog(
          onRate: (stars) async {
            await ref.read(ticketsRepositoryProvider).rate(t.id, stars);
            ref.invalidate(ticketDetailProvider(t.id));
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(ticketDetailProvider(widget.ticketId));
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isStaff = profile?.isStaff ?? false;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'تفاصيل التذكرة',
        actions: [
          if (isStaff)
            detailAsync.maybeWhen(
              data: (t) => IconButton(
                icon: const Icon(Icons.event_available_outlined),
                tooltip: 'حجز موعد',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AppointmentFormDialog(
                    initialClientId: t.clientId,
                    initialClientName: t.clientName,
                    ticketId: t.id,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat/ticket/${widget.ticketId}?title=${Uri.encodeComponent('محادثة الدعم الفني')}'),
        icon: const Icon(Icons.chat),
        label: const Text('فتح الدردشة'),
      ),
      body: detailAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'تعذّر تحميل التذكرة'),
        data: (t) {
          _maybeShowRatingPrompt(t, isStaff);
          return ListView(
            padding: const EdgeInsets.all(16),
          children: [
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(t.clientName, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      StatusBadge(label: ticketStatusToArabic(t.status), color: AppColors.primary),
                      if (t.priority != null) StatusBadge(label: t.priority!, color: AppColors.gold),
                      if (t.category != null) StatusBadge(label: t.category!, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            if (profile != null && profile.isStaff) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (t.status == TicketStatus.open)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.assignment_ind_outlined),
                        label: const Text('استلام التذكرة'),
                        onPressed: () async {
                          await ref.read(ticketsRepositoryProvider).claim(t.id, profile.id);
                          ref.invalidate(ticketDetailProvider(t.id));
                          ref.invalidate(ticketsListProvider);
                        },
                      ),
                    ),
                  if (t.status != TicketStatus.closed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('إغلاق التذكرة'),
                        onPressed: () async {
                          await ref.read(ticketsRepositoryProvider).close(t.id);
                          ref.invalidate(ticketDetailProvider(t.id));
                          ref.invalidate(ticketsListProvider);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (profile != null && !profile.isStaff && t.status == TicketStatus.closed) ...[
              const SizedBox(height: 16),
              const Text('قيّم مستوى الدعم', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final filled = t.rating != null && i < t.rating!;
                  return IconButton(
                    icon: Icon(filled ? Icons.star : Icons.star_border, color: AppColors.gold),
                    onPressed: () async {
                      await ref.read(ticketsRepositoryProvider).rate(t.id, i + 1);
                      ref.invalidate(ticketDetailProvider(t.id));
                    },
                  );
                }),
              ),
            ],
          ],
          );
        },
      ),
    );
  }
}

class _TicketRatingDialog extends StatefulWidget {
  final ValueChanged<int> onRate;
  const _TicketRatingDialog({required this.onRate});

  @override
  State<_TicketRatingDialog> createState() => _TicketRatingDialogState();
}

class _TicketRatingDialogState extends State<_TicketRatingDialog> {
  int _stars = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('كيف كانت تجربتك؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('تم إغلاق تذكرتك — يسعدنا تقييمك'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return IconButton(
                iconSize: 34,
                icon: Icon(filled ? Icons.star : Icons.star_border, color: AppColors.gold),
                onPressed: () => setState(() => _stars = i + 1),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('لاحقًا')),
        FilledButton(
          onPressed: _stars == 0 || _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  widget.onRate(_stars);
                  if (mounted) Navigator.of(context).pop();
                },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('إرسال'),
        ),
      ],
    );
  }
}
