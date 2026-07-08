import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/chat_message.dart';
import '../../../models/profile.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, (ChatKind, String)>((ref, args) {
  return ref.watch(chatRepositoryProvider).watchMessages(args.$1, args.$2);
});

/// يجلب ملف المرسل (الصورة والاسم) لعرضه بفقاعة الدردشة — Riverpod يخزّن
/// النتيجة تلقائيًا بمفتاح المعرّف فيُعاد استخدامها لكل الفقاعات دون تكرار الطلب.
final profileByIdProvider = FutureProvider.autoDispose.family<Profile?, String>((ref, id) async {
  try {
    return await ref.watch(profilesRepositoryProvider).fetchOne(id);
  } catch (_) {
    return null;
  }
});
