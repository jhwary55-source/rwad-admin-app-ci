enum AppointmentStatus { upcoming, completed, cancelled }

AppointmentStatus appointmentStatusFromString(String? value) {
  switch (value) {
    case 'completed':
      return AppointmentStatus.completed;
    case 'cancelled':
      return AppointmentStatus.cancelled;
    default:
      return AppointmentStatus.upcoming;
  }
}

String appointmentStatusToDb(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.upcoming:
      return 'upcoming';
    case AppointmentStatus.completed:
      return 'completed';
    case AppointmentStatus.cancelled:
      return 'cancelled';
  }
}

String appointmentStatusToArabic(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.upcoming:
      return 'قادم';
    case AppointmentStatus.completed:
      return 'مكتمل';
    case AppointmentStatus.cancelled:
      return 'ملغى';
  }
}

enum AppointmentType { inPerson, phone, video }

AppointmentType appointmentTypeFromString(String? value) {
  switch (value) {
    case 'phone':
      return AppointmentType.phone;
    case 'video':
      return AppointmentType.video;
    default:
      return AppointmentType.inPerson;
  }
}

String appointmentTypeToDb(AppointmentType type) {
  switch (type) {
    case AppointmentType.inPerson:
      return 'in_person';
    case AppointmentType.phone:
      return 'phone';
    case AppointmentType.video:
      return 'video';
  }
}

String appointmentTypeToArabic(AppointmentType type) {
  switch (type) {
    case AppointmentType.inPerson:
      return 'حضوري';
    case AppointmentType.phone:
      return 'هاتفي';
    case AppointmentType.video:
      return 'مرئي / صوتي';
  }
}

class Appointment {
  final String id;
  final String? clientId;
  final String clientName;
  final String? clientEmail;
  final String? lawyerId;
  final String? lawyerName;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final AppointmentType type;
  final AppointmentStatus status;
  final String? meetingLink;
  final String? consultationId;
  final String? ticketId;

  const Appointment({
    required this.id,
    this.clientId,
    required this.clientName,
    this.clientEmail,
    this.lawyerId,
    this.lawyerName,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.durationMinutes = 30,
    required this.type,
    required this.status,
    this.meetingLink,
    this.consultationId,
    this.ticketId,
  });

  bool get isCallable => type != AppointmentType.inPerson && meetingLink != null && meetingLink!.isNotEmpty;

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'].toString(),
      clientId: map['client_id'] as String?,
      clientName: (map['client_name'] as String?) ?? 'بدون اسم',
      clientEmail: map['client_email'] as String?,
      lawyerId: map['lawyer_id'] as String?,
      lawyerName: map['lawyer_name'] as String?,
      title: (map['title'] as String?) ?? 'موعد',
      description: map['description'] as String?,
      scheduledAt: (DateTime.tryParse(map['scheduled_at']?.toString() ?? '') ?? DateTime.now()).toLocal(),
      durationMinutes: (map['duration'] as num?)?.toInt() ?? 30,
      type: appointmentTypeFromString(map['type'] as String?),
      status: appointmentStatusFromString(map['status'] as String?),
      meetingLink: map['meeting_link'] as String?,
      consultationId: map['consultation_id'] as String?,
      ticketId: map['ticket_id'] as String?,
    );
  }
}
