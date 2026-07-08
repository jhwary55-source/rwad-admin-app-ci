import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/appointment.dart';

const _arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
const _arWeekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

/// بطاقة موعد أنيقة موحّدة (تُستخدم بشاشتي مواعيد الموظف والعميل): مربّع
/// تاريخ بارز على الطراز الشهير بتطبيقات التقويم (يوم الأسبوع + الرقم +
/// الشهر + الساعة) بجانب تفاصيل الموعد الكاملة، بدل سطر تاريخ نصّي مضغوط.
class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final int index;
  final bool showClientName;
  final List<Widget> actions;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.index,
    this.showClientName = true,
    this.actions = const [],
  });

  Color _statusColor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.upcoming:
        return AppColors.primary;
      case AppointmentStatus.completed:
        return AppColors.success;
      case AppointmentStatus.cancelled:
        return AppColors.danger;
    }
  }

  IconData _typeIcon(AppointmentType t) {
    switch (t) {
      case AppointmentType.video:
        return Icons.videocam_outlined;
      case AppointmentType.phone:
        return Icons.call_outlined;
      case AppointmentType.inPerson:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final color = _statusColor(a.status);
    final dt = a.scheduledAt;

    return FadeSlideIn(
      index: index,
      child: ModernCard(
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border(right: BorderSide(color: color, width: 4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.04)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _arWeekdays[dt.weekday - 1],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dt.day}',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color, height: 1.1),
                    ),
                    Text(_arMonths[dt.month - 1], style: TextStyle(fontSize: 11, color: color)),
                    const SizedBox(height: 8),
                    Container(height: 1, width: 30, color: color.withValues(alpha: 0.25)),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('HH:mm').format(dt),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            a.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: appointmentStatusToArabic(a.status), color: color),
                      ],
                    ),
                    if (showClientName) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(a.clientName, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_typeIcon(a.type), size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(appointmentTypeToArabic(a.type), style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${a.durationMinutes} دقيقة', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                          ],
                        ),
                      ],
                    ),
                    if (a.description != null && a.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        a.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.4),
                      ),
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
