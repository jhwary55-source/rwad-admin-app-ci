import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/chat_message.dart';

/// طبقة الدردشة الحية: نفس الفكرة المستخدمة في الموقع تماماً — إدراج صف في
/// جدول `messages` (للاستشارات) أو `ticket_messages` (للدعم الفني)، مع
/// الاستماع للتغييرات اللحظية عبر Supabase Realtime بدل أي بروتوكول خاص.
class ChatRepository {
  final SupabaseClient _client;
  ChatRepository(this._client);

  Stream<List<ChatMessage>> watchMessages(ChatKind kind, String parentId) {
    // فرز صريح إضافي بجانب .order() بالخادم: يحمي من أي تقلّب بترتيب دفعات
    // Realtime (كل دفعة تُعاد فرزتها بالكامل حسب created_at الفعلي بدل
    // الاعتماد فقط على ترتيب وصول الأحداث نفسها).
    if (kind == ChatKind.consultation) {
      return _client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('consultation_id', parentId)
          .order('created_at')
          .map((rows) => rows.map(ChatMessage.fromConsultationMap).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    }
    return _client
        .from('ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', parentId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromTicketMap).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  /// يعلّم كل رسائل الطرف الآخر (غير المرسلة من `myId`) كمقروءة — تُستخدم
  /// لعرض علامة "✓✓" بفقاعة "أنا" بدل تتبّع قراءة لكل رسالة يدويًا بالواجهة.
  Future<void> markAsRead({required ChatKind kind, required String parentId, required String myId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    if (kind == ChatKind.consultation) {
      await _client
          .from('messages')
          .update({'read_at': now})
          .eq('consultation_id', parentId)
          .neq('sender_id', myId)
          .isFilter('read_at', null);
    } else {
      await _client
          .from('ticket_messages')
          .update({'read_at': now})
          .eq('ticket_id', parentId)
          .neq('sender_id', myId)
          .isFilter('read_at', null);
    }
  }

  /// قناة بث لحظي (بلا تخزين بقاعدة البيانات) للإعلان عن "جارٍ الكتابة".
  RealtimeChannel typingChannel(ChatKind kind, String parentId) {
    return _client.channel('typing-${kind.name}-$parentId');
  }

  void sendTypingSignal(RealtimeChannel channel, String userId) {
    channel.sendBroadcastMessage(event: 'typing', payload: {'userId': userId});
  }

  /// آخر رسائل الاستشارات — بلا فلترة (للموظف) أو محصورة بمعرّفات استشارات
  /// العميل نفسه (`consultationIds`) لتفادي كشف رسائل عملاء آخرين، لأن جدول
  /// `messages` بلا سياسات RLS تحمي هذا على مستوى القاعدة.
  Future<List<ChatMessage>> fetchRecentConsultationMessages({List<String>? consultationIds, int limit = 15}) async {
    if (consultationIds != null && consultationIds.isEmpty) return [];
    var query = _client.from('messages').select();
    if (consultationIds != null) query = query.inFilter('consultation_id', consultationIds);
    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List).map((e) => ChatMessage.fromConsultationMap(e as Map<String, dynamic>)).toList();
  }

  /// آخر رسائل التذاكر — نفس منطق الفلترة أعلاه.
  Future<List<ChatMessage>> fetchRecentTicketMessages({List<String>? ticketIds, int limit = 15}) async {
    if (ticketIds != null && ticketIds.isEmpty) return [];
    var query = _client.from('ticket_messages').select();
    if (ticketIds != null) query = query.inFilter('ticket_id', ticketIds);
    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List).map((e) => ChatMessage.fromTicketMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> sendMessage({
    required ChatKind kind,
    required String parentId,
    required String content,
    required String senderId,
    required String senderName,
    required String senderRole,
    String? imageUrl,
  }) async {
    if (kind == ChatKind.consultation) {
      await _client.from('messages').insert({
        'consultation_id': parentId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'content': content,
        'image_url': imageUrl,
      });
    } else {
      await _client.from('ticket_messages').insert({
        'ticket_id': parentId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'message': content,
        'image_url': imageUrl,
      });
    }
  }

  /// يرفع صورة مرفقة برسالة دردشة إلى bucket `chat-attachments` (عام، يتطلب
  /// تشغيل supabase-schema-v8.sql بمشروع المستخدم أولاً) بمسار فريد لكل رفعة
  /// حتى لا حاجة لكسر كاش الرابط كما بصور الحساب.
  Future<String> uploadChatImage({
    required ChatKind kind,
    required String parentId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final folder = kind == ChatKind.consultation ? 'consultation' : 'ticket';
    final path = '$folder/$parentId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage.from('chat-attachments').uploadBinary(path, bytes);
    return _client.storage.from('chat-attachments').getPublicUrl(path);
  }
}
