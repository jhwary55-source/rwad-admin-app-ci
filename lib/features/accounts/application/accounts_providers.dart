import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/profile.dart';
import '../../auth/application/auth_providers.dart';
import '../data/profiles_repository.dart';

final profilesRepositoryProvider = Provider<ProfilesRepository>((ref) {
  return ProfilesRepository(ref.watch(supabaseClientProvider));
});

final accountsSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final accountsListProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  final search = ref.watch(accountsSearchProvider);
  return ref.watch(profilesRepositoryProvider).fetchAll(search: search);
});

final accountDetailProvider = FutureProvider.autoDispose.family<Profile, String>((ref, id) {
  return ref.watch(profilesRepositoryProvider).fetchOne(id);
});
