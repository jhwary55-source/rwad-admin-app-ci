/// نموذج موحّد لرسائل الدردشة، يُستخدم لجدولي `messages` (الاستشارات)
/// و`ticket_messages` (الدعم الفني) لأن بنيتهما متطابقة تقريباً.
class ChatMessage {
  final String id;
  final String parentId; // consultation_id أو ticket_id
  final String? senderId;
  final String senderName;
  final String senderRole; // client | admin | system
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.parentId,
    this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromConsultationMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      parentId: map['consultation_id'].toString(),
      senderId: map['sender_id'] as String?,
      senderName: (map['sender_name'] as String?) ?? '',
      senderRole: (map['sender_role'] as String?) ?? 'client',
      content: (map['content'] as String?) ?? '',
      imageUrl: map['image_url'] as String?,
      createdAt: (DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now()).toLocal(),
      readAt: map['read_at'] != null ? DateTime.tryParse(map['read_at'].toString())?.toLocal() : null,
    );
  }

  factory ChatMessage.fromTicketMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      parentId: map['ticket_id'].toString(),
      senderId: map['sender_id'] as String?,
      senderName: (map['sender_name'] as String?) ?? '',
      senderRole: (map['sender_role'] as String?) ?? 'client',
      content: (map['message'] as String?) ?? '',
      imageUrl: map['image_url'] as String?,
      createdAt: (DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now()).toLocal(),
      readAt: map['read_at'] != null ? DateTime.tryParse(map['read_at'].toString())?.toLocal() : null,
    );
  }
}

enum ChatKind { consultation, ticket }
