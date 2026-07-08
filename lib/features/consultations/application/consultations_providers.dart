import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/consultation.dart';
import '../../auth/application/auth_providers.dart';
import '../data/consultations_repository.dart';

final consultationsRepositoryProvider = Provider<ConsultationsRepository>((ref) {
  return ConsultationsRepository(ref.watch(supabaseClientProvider));
});

final consultationsFilterProvider = StateProvider.autoDispose<ConsultationStatus?>((ref) => null);

final consultationsListProvider = FutureProvider.autoDispose<List<Consultation>>((ref) {
  final status = ref.watch(consultationsFilterProvider);
  return ref.watch(consultationsRepositoryProvider).fetchAll(status: status);
});

final consultationDetailProvider = FutureProvider.autoDispose.family<Consultation, String>((ref, id) {
  return ref.watch(consultationsRepositoryProvider).fetchOne(id);
});

/// استشارات العميل الحالي فقط (تُستخدم في واجهة العميل).
final myConsultationsProvider = FutureProvider.autoDispose<List<Consultation>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(consultationsRepositoryProvider).fetchMine(profile.id);
});
