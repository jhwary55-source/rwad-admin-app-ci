import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/appointment.dart';
import '../../../models/chat_message.dart';
import '../../../models/consultation.dart';
import '../../../models/support_ticket.dart';
import '../../auth/application/auth_providers.dart';
import '../../chat/application/chat_providers.dart';
import '../../consultations/application/consultations_providers.dart';
import '../../tickets/application/tickets_providers.dart';
import '../../appointments/application/appointments_providers.dart';

enum ActivityKind { consultation, ticket, appointment, message }

/// عنصر نشاط موحّد لعرض آخر الاستشارات/التذاكر/المواعيد/الرسائل بقائمة زمنية
/// واحدة — مبني بالكامل على بيانات موجودة أصلاً (fetchAll/fetchMine لكل
/// مستودع)، بدون أي جدول أو عمود جديد بقاعدة البيانات.
class ActivityItem {
  final ActivityKind kind;
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String? explicitRoute;

  const ActivityItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.explicitRoute,
  });

  String? get route {
    if (explicitRoute != null) return explicitRoute;
    switch (kind) {
      case ActivityKind.consultation:
        return '/consultations/$id';
      case ActivityKind.ticket:
        return '/tickets/$id';
      case ActivityKind.appointment:
        return null; // لا توجد شاشة تفاصيل مستقلة للموعد بعد — يُفتح من قائمة المواعيد
      case ActivityKind.message:
        return null; // يُحدَّد عبر explicitRoute دائمًا
    }
  }
}

List<ActivityItem> _mapConsultationMessages(List<ChatMessage> messages) => messages
    .map((m) => ActivityItem(
          kind: ActivityKind.message,
          id: m.parentId,
          title: 'رسالة من ${m.senderName}',
          subtitle: m.content,
          timestamp: m.createdAt,
          icon: Icons.chat_bubble_outline,
          color: AppColors.gold,
          explicitRoute: '/chat/consultation/${m.parentId}?title=${Uri.encodeComponent('محادثة الاستشارة')}',
        ))
    .toList();

List<ActivityItem> _mapTicketMessages(List<ChatMessage> messages) => messages
    .map((m) => ActivityItem(
          kind: ActivityKind.message,
          id: m.parentId,
          title: 'رسالة من ${m.senderName}',
          subtitle: m.content,
          timestamp: m.createdAt,
          icon: Icons.chat_bubble_outline,
          color: AppColors.danger,
          explicitRoute: '/chat/ticket/${m.parentId}?title=${Uri.encodeComponent('محادثة الدعم الفني')}',
        ))
    .toList();

/// نشاط عام (للموظف): كل الاستشارات/التذاكر/المواعيد/الرسائل بلا فلترة.
final recentActivityProvider = FutureProvider.autoDispose<List<ActivityItem>>((ref) async {
  final consultations = await ref.watch(consultationsRepositoryProvider).fetchAll();
  final tickets = await ref.watch(ticketsRepositoryProvider).fetchAll();
  final appointments = await ref.watch(appointmentsRepositoryProvider).fetchAll();
  final consultMessages = await ref.watch(chatRepositoryProvider).fetchRecentConsultationMessages();
  final ticketMessages = await ref.watch(chatRepositoryProvider).fetchRecentTicketMessages();

  final items = <ActivityItem>[
    ...consultations.map((c) => ActivityItem(
          kind: ActivityKind.consultation,
          id: c.id,
          title: 'استشارة جديدة من ${c.clientName}',
          subtitle: c.caseSummary ?? 'بدون ملخص',
          timestamp: c.createdAt,
          icon: Icons.forum_outlined,
          color: AppColors.gold,
        )),
    ...tickets.map((t) => ActivityItem(
          kind: ActivityKind.ticket,
          id: t.id,
          title: 'تذكرة دعم: ${t.subject}',
          subtitle: t.clientName,
          timestamp: t.createdAt,
          icon: Icons.support_agent_outlined,
          color: AppColors.danger,
        )),
    ...appointments.map((a) => ActivityItem(
          kind: ActivityKind.appointment,
          id: a.id,
          title: 'موعد: ${a.title}',
          subtitle: '${a.clientName} — ${a.scheduledAt.year}/${a.scheduledAt.month}/${a.scheduledAt.day}',
          timestamp: a.scheduledAt,
          icon: Icons.event_outlined,
          color: AppColors.primary,
        )),
    ..._mapConsultationMessages(consultMessages),
    ..._mapTicketMessages(ticketMessages),
  ];

  items.sort((x, y) => y.timestamp.compareTo(x.timestamp));
  return items.take(40).toList();
});

/// معرّفات العناصر التي "شوهدت" فعلًا (بعد فتح الجرس مرة) — تُستبعد من عدّ
/// الشارة حتى تتغيّر (مثال: استشارة معلّقة جديدة تصل لاحقًا). ذاكرة الجلسة
/// فقط (لا تُحفظ)، متعمّد للبساطة.
final dismissedNotificationIdsProvider = StateProvider<Set<String>>((ref) => {});

final _staffNotifyQualifyingIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final consultations = await ref.watch(consultationsRepositoryProvider).fetchAll(status: ConsultationStatus.pending);
  final tickets = await ref.watch(ticketsRepositoryProvider).fetchAll(status: TicketStatus.open);
  return {...consultations.map((c) => 'c_${c.id}'), ...tickets.map((t) => 't_${t.id}')};
});

/// عدد شارة الجرس للموظف: استشارات قيد الانتظار + تذاكر مفتوحة، مطروحًا منها
/// ما شوهد بالفعل عبر فتح الجرس سابقًا.
final staffNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final ids = await ref.watch(_staffNotifyQualifyingIdsProvider.future);
  final dismissed = ref.watch(dismissedNotificationIdsProvider);
  return ids.difference(dismissed).length;
});

/// يُستدعى عند فتح جرس الموظف — يعلّم كل العناصر الحالية كمشاهَدة.
Future<void> markStaffNotificationsSeen(WidgetRef ref) async {
  final ids = await ref.read(_staffNotifyQualifyingIdsProvider.future);
  ref.read(dismissedNotificationIdsProvider.notifier).update((s) => {...s, ...ids});
}

final _clientNotifyQualifyingIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return {};

  final consultations = await ref.watch(consultationsRepositoryProvider).fetchMine(profile.id);
  final tickets = await ref.watch(ticketsRepositoryProvider).fetchMine(profile.id);
  final appointments = await ref.watch(appointmentsRepositoryProvider).fetchMine(profile.id);

  return {
    ...consultations.where((c) => c.status == ConsultationStatus.closed && c.rating == null).map((c) => 'c_${c.id}'),
    ...tickets.where((t) => t.status == TicketStatus.closed && t.rating == null).map((t) => 't_${t.id}'),
    ...appointments.where((a) => a.status == AppointmentStatus.upcoming).map((a) => 'a_${a.id}'),
  };
});

/// عدد شارة الجرس للعميل: استشارات/تذاكر مغلقة تنتظر تقييمه + مواعيده
/// القادمة، مطروحًا منها ما شوهد بالفعل عبر فتح الجرس سابقًا.
final clientNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final ids = await ref.watch(_clientNotifyQualifyingIdsProvider.future);
  final dismissed = ref.watch(dismissedNotificationIdsProvider);
  return ids.difference(dismissed).length;
});

/// يُستدعى عند فتح جرس العميل — يعلّم كل العناصر الحالية كمشاهَدة.
Future<void> markClientNotificationsSeen(WidgetRef ref) async {
  final ids = await ref.read(_clientNotifyQualifyingIdsProvider.future);
  ref.read(dismissedNotificationIdsProvider.notifier).update((s) => {...s, ...ids});
}

/// نشاط العميل الحالي فقط: استشاراته/تذاكره/مواعيده/رسائله — نفس الفكرة لكن
/// محصورة به لأن جدول الرسائل بلا سياسات RLS تحميه على مستوى القاعدة.
final myRecentActivityProvider = FutureProvider.autoDispose<List<ActivityItem>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];

  final consultations = await ref.watch(consultationsRepositoryProvider).fetchMine(profile.id);
  final tickets = await ref.watch(ticketsRepositoryProvider).fetchMine(profile.id);
  final appointments = await ref.watch(appointmentsRepositoryProvider).fetchMine(profile.id);
  final consultMessages = await ref
      .watch(chatRepositoryProvider)
      .fetchRecentConsultationMessages(consultationIds: consultations.map((c) => c.id).toList());
  final ticketMessages =
      await ref.watch(chatRepositoryProvider).fetchRecentTicketMessages(ticketIds: tickets.map((t) => t.id).toList());

  final items = <ActivityItem>[
    ...consultations.map((c) => ActivityItem(
          kind: ActivityKind.consultation,
          id: c.id,
          title: 'استشارتي: ${c.caseSummary ?? 'بدون ملخص'}',
          subtitle: consultationStatusToArabic(c.status),
          timestamp: c.createdAt,
          icon: Icons.forum_outlined,
          color: AppColors.gold,
        )),
    ...tickets.map((t) => ActivityItem(
          kind: ActivityKind.ticket,
          id: t.id,
          title: 'تذكرتي: ${t.subject}',
          subtitle: ticketStatusToArabic(t.status),
          timestamp: t.createdAt,
          icon: Icons.support_agent_outlined,
          color: AppColors.danger,
        )),
    ...appointments.map((a) => ActivityItem(
          kind: ActivityKind.appointment,
          id: a.id,
          title: 'موعدي: ${a.title}',
          subtitle: '${a.scheduledAt.year}/${a.scheduledAt.month}/${a.scheduledAt.day}',
          timestamp: a.scheduledAt,
          icon: Icons.event_outlined,
          color: AppColors.primary,
        )),
    ..._mapConsultationMessages(consultMessages),
    ..._mapTicketMessages(ticketMessages),
  ];

  items.sort((x, y) => y.timestamp.compareTo(x.timestamp));
  return items.take(40).toList();
});
