import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/support_ticket.dart';

class TicketsRepository {
  final SupabaseClient _client;
  TicketsRepository(this._client);

  Future<List<SupportTicket>> fetchAll({TicketStatus? status}) async {
    var query = _client.from('support_tickets').select();
    if (status != null) query = query.eq('status', ticketStatusToDb(status));
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => SupportTicket.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<SupportTicket> fetchOne(String id) async {
    final data = await _client.from('support_tickets').select().eq('id', id).single();
    return SupportTicket.fromMap(data);
  }

  Future<void> claim(String id, String staffId) async {
    await _client.from('support_tickets').update({'status': 'claimed', 'claimed_by': staffId}).eq('id', id);
  }

  Future<void> close(String id) async {
    await _client.from('support_tickets').update({'status': 'closed'}).eq('id', id);
  }

  /// تذاكر العميل الحالي فقط — يقابل استعلام "الدعم الفني" في client-dashboard.html.
  Future<List<SupportTicket>> fetchMine(String clientId) async {
    final data = await _client.from('support_tickets').select().eq('client_id', clientId).order('created_at', ascending: false);
    return (data as List).map((e) => SupportTicket.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> rate(String id, int rating) async {
    await _client.from('support_tickets').update({'rating': rating}).eq('id', id);
  }

  /// إنشاء تذكرة جديدة من طرف العميل — يطابق submitTicket() في
  /// client-dashboard.html: إدراج التذكرة ثم أول رسالة فيها.
  Future<String> createTicket({
    required String clientId,
    required String clientName,
    String? clientEmail,
    required String subject,
    required String message,
    String? category,
    String? priority,
  }) async {
    final ticket = await _client.from('support_tickets').insert({
      'client_id': clientId,
      'client_name': clientName,
      'client_email': clientEmail,
      'subject': subject,
      'category': category,
      'priority': priority,
      'status': 'open',
    }).select().single();

    await _client.from('ticket_messages').insert({
      'ticket_id': ticket['id'],
      'sender_id': clientId,
      'sender_name': clientName,
      'sender_role': 'client',
      'message': message,
    });

    return ticket['id'].toString();
  }
}
