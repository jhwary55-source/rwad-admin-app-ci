import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_providers.dart';
import '../data/analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(supabaseClientProvider));
});

final analyticsSnapshotProvider = FutureProvider.autoDispose<AnalyticsSnapshot>((ref) {
  return ref.watch(analyticsRepositoryProvider).fetchSnapshot();
});
