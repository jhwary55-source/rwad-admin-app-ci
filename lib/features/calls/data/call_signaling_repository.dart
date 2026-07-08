import 'package:supabase_flutter/supabase_flutter.dart';

/// طبقة إشارة الاتصال (WebRTC signaling) عبر قناة بث Supabase Realtime واحدة
/// لكل غرفة — بديل عن خادم PeerJS السحابي الذي كانت تعتمد عليه صفحة call.html
/// بالموقع. نفس فكرة `ChatRepository.typingChannel`/`sendTypingSignal` تمامًا
/// (`lib/features/chat/data/chat_repository.dart`)، فقط بأحداث بث أكثر
/// (عرض/رد/مرشّح ICE/إنهاء) بالإضافة لدردشة الجلسة ومؤشر القراءة التي لا
/// تُخزَّن بقاعدة البيانات إطلاقًا (تمامًا كسلوك دردشة call.html السابق).
class CallSignalingRepository {
  final SupabaseClient _client;
  CallSignalingRepository(this._client);

  RealtimeChannel channelFor(String roomId) => _client.channel('call-$roomId');

  Future<void> trackPresence(RealtimeChannel channel, Map<String, dynamic> payload) {
    return channel.track(payload);
  }

  void sendOffer(RealtimeChannel channel, {required String sdp, required String senderId}) {
    channel.sendBroadcastMessage(event: 'offer', payload: {'sdp': sdp, 'senderId': senderId});
  }

  void sendAnswer(RealtimeChannel channel, {required String sdp, required String senderId}) {
    channel.sendBroadcastMessage(event: 'answer', payload: {'sdp': sdp, 'senderId': senderId});
  }

  void sendIceCandidate(
    RealtimeChannel channel, {
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
    required String senderId,
  }) {
    channel.sendBroadcastMessage(event: 'ice-candidate', payload: {
      'candidate': candidate,
      'sdpMid': sdpMid,
      'sdpMLineIndex': sdpMLineIndex,
      'senderId': senderId,
    });
  }

  void sendHangup(RealtimeChannel channel, {required String senderId, String reason = 'ended'}) {
    channel.sendBroadcastMessage(event: 'hangup', payload: {'senderId': senderId, 'reason': reason});
  }

  void sendChatMessage(
    RealtimeChannel channel, {
    required String msgId,
    required String senderId,
    required String senderName,
    String? senderAvatarUrl,
    required String text,
  }) {
    channel.sendBroadcastMessage(event: 'chat-message', payload: {
      'msgId': msgId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'text': text,
    });
  }

  void sendChatRead(RealtimeChannel channel, {required String readerId}) {
    channel.sendBroadcastMessage(event: 'chat-read', payload: {'readerId': readerId});
  }

  Future<void> removeChannel(RealtimeChannel channel) {
    return _client.removeChannel(channel);
  }
}
