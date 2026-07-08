import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/appointment.dart';
import '../../auth/application/auth_providers.dart';
import '../data/appointments_repository.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(supabaseClientProvider));
});

final appointmentsFilterProvider = StateProvider.autoDispose<AppointmentStatus?>((ref) => AppointmentStatus.upcoming);

final appointmentsListProvider = FutureProvider.autoDispose<List<Appointment>>((ref) {
  final status = ref.watch(appointmentsFilterProvider);
  return ref.watch(appointmentsRepositoryProvider).fetchAll(status: status);
});

/// مواعيد العميل الحالي فقط (تُستخدم في واجهة العميل).
final myAppointmentsProvider = FutureProvider.autoDispose<List<Appointment>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(appointmentsRepositoryProvider).fetchMine(profile.id);
});
