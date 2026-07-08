import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/appointment.dart';
import '../../appointments/application/appointments_providers.dart';

/// قائمة الجلسات القابلة للاتصال بها (مواعيد مرئية/هاتفية قادمة تملك رابط
/// جلسة). الاتصال الفعلي يتم عبر WebView لصفحة call.html على الموقع.
class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsListProvider);

    return Column(
      children: [
        const GlowBanner(icon: Icons.call_outlined, title: 'الاتصال', subtitle: 'جلسات الاتصال المرئي/الصوتي القادمة'),
        Expanded(
          child: appointmentsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'تعذّر تحميل الجلسات', onRetry: () => ref.invalidate(appointmentsListProvider)),
      data: (appointments) {
        final callable = appointments.where((a) => a.isCallable && a.status == AppointmentStatus.upcoming).toList();
        if (callable.isEmpty) {
          return const EmptyState(message: 'لا توجد جلسات اتصال مجدولة حالياً', icon: Icons.call_end_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: callable.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = callable[i];
            return FadeSlideIn(
              index: i,
              child: ModernCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1F166534),
                    child: Icon(Icons.videocam, color: AppColors.success),
                  ),
                  title: Text(a.clientName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${a.title} • ${DateFormat('yyyy/MM/dd - HH:mm').format(a.scheduledAt)}'),
                  trailing: GradientButton(
                    label: 'اتصال',
                    icon: Icons.call,
                    onPressed: () => context.push(
                      '/call?room=${Uri.encodeComponent(a.meetingLink!)}&name=${Uri.encodeComponent(a.clientName)}'
                      '${a.clientId != null ? '&calleeId=${Uri.encodeComponent(a.clientId!)}' : ''}',
                    ),
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
