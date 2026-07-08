import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_providers.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) {
  return ref.watch(dashboardRepositoryProvider).fetchStats();
});
