import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/application/auth_providers.dart';
import '../data/ai_intake_repository.dart';

final aiIntakeRepositoryProvider = Provider<AiIntakeRepository>((ref) {
  return AiIntakeRepository(http.Client(), ref.watch(supabaseClientProvider));
});
