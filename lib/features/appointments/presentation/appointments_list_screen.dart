import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/appointment.dart';
import '../application/appointments_providers.dart';
import 'appointment_card.dart';
import 'appointment_form_dialog.dart';

class AppointmentsListScreen extends ConsumerWidget {
  const AppointmentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsListProvider);
    final filter = ref.watch(appointmentsFilterProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => const AppointmentFormDialog()),
        icon: const Icon(Icons.add),
        label: const Text('موعد جديد'),
      ),
      body: Column(
        children: [
          const GlowBanner(icon: Icons.event_outlined, title: 'المواعيد', subtitle: 'إدارة مواعيد العملاء وجدولتها'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: filter == null,
                    onSelected: (_) => ref.read(appointmentsFilterProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  for (final s in AppointmentStatus.values) ...[
                    ChoiceChip(
                      label: Text(appointmentStatusToArabic(s)),
                      selected: filter == s,
                      onSelected: (_) => ref.read(appointmentsFilterProvider.notifier).state = s,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: 'تعذّر تحميل المواعيد', onRetry: () => ref.invalidate(appointmentsListProvider)),
              data: (appointments) {
                if (appointments.isEmpty) return const EmptyState(message: 'لا توجد مواعيد', icon: Icons.event_busy);
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = appointments[i];
                    return AppointmentCard(
                      appointment: a,
                      index: i,
                      actions: [
                        if (a.isCallable && a.status == AppointmentStatus.upcoming)
                          OutlinedButton.icon(
                            onPressed: () => context.push(
                              '/call?room=${Uri.encodeComponent(a.meetingLink!)}&name=${Uri.encodeComponent(a.clientName)}'
                              '${a.clientId != null ? '&calleeId=${Uri.encodeComponent(a.clientId!)}' : ''}',
                            ),
                            icon: const Icon(Icons.call, size: 16, color: AppColors.success),
                            label: const Text('بدء الاتصال'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                          ),
                        const SizedBox(width: 6),
                        PopupMenuButton<AppointmentStatus>(
                          onSelected: (s) async {
                            await ref.read(appointmentsRepositoryProvider).updateStatus(a.id, s);
                            ref.invalidate(appointmentsListProvider);
                          },
                          itemBuilder: (context) => AppointmentStatus.values
                              .map((s) => PopupMenuItem(value: s, child: Text(appointmentStatusToArabic(s))))
                              .toList(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
