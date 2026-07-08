import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/notifications/push_sender.dart';
import '../data/call_signaling_repository.dart';
import 'call_controller.dart';
import 'call_state.dart';

final callSignalingRepositoryProvider = Provider<CallSignalingRepository>((ref) {
  return CallSignalingRepository(ref.watch(supabaseClientProvider));
});

final callControllerProvider = StateNotifierProvider.autoDispose.family<CallController, CallState, CallParams>((ref, params) {
  final me = ref.watch(currentProfileProvider).valueOrNull;
  final controller = CallController(
    signaling: ref.watch(callSignalingRepositoryProvider),
    pushSender: ref.watch(pushSenderProvider),
    params: params,
    myId: me?.id ?? 'unknown',
    myName: me?.name ?? (params.isHost ? 'المشرف' : 'أنا'),
    myAvatarUrl: me?.avatarUrl,
  );
  controller.start();
  return controller;
});
