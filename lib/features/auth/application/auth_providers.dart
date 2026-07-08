import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/profile.dart';
import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// يبث حالة تسجيل الدخول الحالية (المستخدم أو null) من Supabase مباشرة.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// ملف الموظف الحالي؛ يُعاد جلبه كلما تغيّرت حالة الجلسة.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  final repo = ref.watch(authRepositoryProvider);
  final userId = authState?.session?.user.id ?? repo.currentSession?.user.id;
  if (userId == null) return null;
  return repo.fetchProfile(userId);
});
