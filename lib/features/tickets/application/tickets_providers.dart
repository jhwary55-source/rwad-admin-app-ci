import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/support_ticket.dart';
import '../../auth/application/auth_providers.dart';
import '../data/tickets_repository.dart';

final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) {
  return TicketsRepository(ref.watch(supabaseClientProvider));
});

final ticketsFilterProvider = StateProvider.autoDispose<TicketStatus?>((ref) => null);

final ticketsListProvider = FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  final status = ref.watch(ticketsFilterProvider);
  return ref.watch(ticketsRepositoryProvider).fetchAll(status: status);
});

final ticketDetailProvider = FutureProvider.autoDispose.family<SupportTicket, String>((ref, id) {
  return ref.watch(ticketsRepositoryProvider).fetchOne(id);
});

/// تذاكر العميل الحالي فقط (تُستخدم في واجهة العميل).
final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(ticketsRepositoryProvider).fetchMine(profile.id);
});
