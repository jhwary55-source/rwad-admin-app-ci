import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/appointment.dart';
import '../application/appointments_providers.dart';
import 'appointment_card.dart';

/// "مواعيدي" — نفس تبويب client-dashboard.html: قراءة فقط، مع زر انضمام
/// يُفعَّل قبل 15 دقيقة من الموعد للمواعيد المرئية/الهاتفية.
class MyAppointmentsListScreen extends ConsumerWidget {
  const MyAppointmentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(myAppointmentsProvider);

    return Column(
      children: [
        const GlowBanner(icon: Icons.event_outlined, title: 'مواعيدي', subtitle: 'مواعيدك القادمة مع فريقنا القانوني'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(myAppointmentsProvider),
            child: appointmentsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'تعذّر تحميل مواعيدك', onRetry: () => ref.invalidate(myAppointmentsProvider)),
        data: (appointments) {
          if (appointments.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(message: 'لا توجد لديك مواعيد', icon: Icons.event_busy),
              ],
            );
          }
          final now = DateTime.now();
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: appointments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = appointments[i];
              final canJoin = a.isCallable &&
                  a.status == AppointmentStatus.upcoming &&
                  now.isAfter(a.scheduledAt.subtract(const Duration(minutes: 15)));
              return AppointmentCard(
                appointment: a,
                index: i,
                showClientName: false,
                actions: [
                  if (a.isCallable && a.status == AppointmentStatus.upcoming)
                    OutlinedButton.icon(
                      onPressed: !canJoin
                          ? null
                          : () => context.push(
                                '/call?room=${Uri.encodeComponent(a.meetingLink!)}&name=${Uri.encodeComponent(a.lawyerName ?? 'المحامي')}&mode=guest',
                              ),
                      icon: Icon(Icons.call, size: 16, color: canJoin ? AppColors.success : Colors.grey),
                      label: Text(canJoin ? 'انضمام للمكالمة' : 'يتفعّل قبل 15 دقيقة'),
                      style: OutlinedButton.styleFrom(foregroundColor: canJoin ? AppColors.success : Colors.grey),
                    ),
                ],
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
