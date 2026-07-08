enum TicketStatus { open, claimed, closed }

TicketStatus ticketStatusFromString(String? value) {
  switch (value) {
    case 'claimed':
      return TicketStatus.claimed;
    case 'closed':
      return TicketStatus.closed;
    default:
      return TicketStatus.open;
  }
}

String ticketStatusToDb(TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return 'open';
    case TicketStatus.claimed:
      return 'claimed';
    case TicketStatus.closed:
      return 'closed';
  }
}

String ticketStatusToArabic(TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return 'مفتوحة';
    case TicketStatus.claimed:
      return 'قيد المعالجة';
    case TicketStatus.closed:
      return 'مغلقة';
  }
}

class SupportTicket {
  final String id;
  final String? clientId;
  final String clientName;
  final String? clientEmail;
  final String subject;
  final String? category;
  final String? priority;
  final TicketStatus status;
  final String? claimedBy;
  final int? rating;
  final DateTime createdAt;

  const SupportTicket({
    required this.id,
    this.clientId,
    required this.clientName,
    this.clientEmail,
    required this.subject,
    this.category,
    this.priority,
    required this.status,
    this.claimedBy,
    this.rating,
    required this.createdAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      id: map['id'].toString(),
      clientId: map['client_id'] as String?,
      clientName: (map['client_name'] as String?) ?? 'بدون اسم',
      clientEmail: map['client_email'] as String?,
      subject: (map['subject'] as String?) ?? 'بدون عنوان',
      category: map['category'] as String?,
      priority: map['priority'] as String?,
      status: ticketStatusFromString(map['status'] as String?),
      claimedBy: map['claimed_by'] as String?,
      rating: (map['rating'] as num?)?.toInt(),
      createdAt: (DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now()).toLocal(),
    );
  }
}
