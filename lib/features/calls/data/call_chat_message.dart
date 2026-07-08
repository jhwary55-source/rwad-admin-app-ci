/// رسالة دردشة جلسة الاتصال — عابرة (ephemeral)، تُرسل عبر بث Supabase
/// Realtime فقط ولا تُخزَّن بأي جدول قاعدة بيانات، تمامًا كما كانت دردشة
/// call.html تُرسل عبر قناة بيانات PeerJS المباشرة بدون تخزين.
class CallChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final DateTime sentAt;
  final bool isMe;
  bool read;

  CallChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    required this.sentAt,
    required this.isMe,
    this.read = false,
  });
}
