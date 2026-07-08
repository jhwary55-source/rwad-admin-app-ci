enum ConsultationStatus { pending, inReview, closed }

ConsultationStatus consultationStatusFromString(String? value) {
  switch (value) {
    case 'in_review':
      return ConsultationStatus.inReview;
    case 'closed':
      return ConsultationStatus.closed;
    default:
      return ConsultationStatus.pending;
  }
}

String consultationStatusToDb(ConsultationStatus status) {
  switch (status) {
    case ConsultationStatus.pending:
      return 'pending';
    case ConsultationStatus.inReview:
      return 'in_review';
    case ConsultationStatus.closed:
      return 'closed';
  }
}

String consultationStatusToArabic(ConsultationStatus status) {
  switch (status) {
    case ConsultationStatus.pending:
      return 'قيد الانتظار';
    case ConsultationStatus.inReview:
      return 'قيد المراجعة';
    case ConsultationStatus.closed:
      return 'مغلقة';
  }
}

class Consultation {
  final String id;
  final String? clientId;
  final String clientName;
  final String? clientPhone;
  final String? clientEmail;
  final String? caseSummary;
  final String? fullConversation;
  final ConsultationStatus status;
  final int? rating;
  final String? category;
  final String? assignedTo;
  final DateTime createdAt;

  const Consultation({
    required this.id,
    this.clientId,
    required this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.caseSummary,
    this.fullConversation,
    required this.status,
    this.rating,
    this.category,
    this.assignedTo,
    required this.createdAt,
  });

  factory Consultation.fromMap(Map<String, dynamic> map) {
    return Consultation(
      id: map['id'].toString(),
      clientId: map['client_id'] as String?,
      clientName: (map['client_name'] as String?) ?? 'بدون اسم',
      clientPhone: map['client_phone'] as String?,
      clientEmail: map['client_email'] as String?,
      caseSummary: map['case_summary'] as String?,
      fullConversation: map['full_conversation'] as String?,
      status: consultationStatusFromString(map['status'] as String?),
      rating: (map['rating'] as num?)?.toInt(),
      category: map['category'] as String?,
      assignedTo: map['assigned_to'] as String?,
      createdAt: (DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now()).toLocal(),
    );
  }
}
