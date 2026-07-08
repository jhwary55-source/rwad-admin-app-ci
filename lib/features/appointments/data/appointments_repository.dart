import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/appointment.dart';

class AppointmentsRepository {
  final SupabaseClient _client;
  AppointmentsRepository(this._client);

  Future<List<Appointment>> fetchAll({AppointmentStatus? status}) async {
    var query = _client.from('appointments').select();
    if (status != null) query = query.eq('status', appointmentStatusToDb(status));
    final data = await query.order('scheduled_at', ascending: true);
    return (data as List).map((e) => Appointment.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> create({
    required String clientId,
    required String clientName,
    String? clientEmail,
    required String title,
    String? description,
    required DateTime scheduledAt,
    required int durationMinutes,
    required AppointmentType type,
    String? consultationId,
    String? ticketId,
    List<String> extraAttendeeIds = const [],
  }) async {
    String? meetingLink;
    if (type != AppointmentType.inPerson) {
      meetingLink = 'rwad-peer-${DateTime.now().millisecondsSinceEpoch}';
    }
    final inserted = await _client
        .from('appointments')
        .insert({
          'client_id': clientId,
          'client_name': clientName,
          'client_email': clientEmail,
          'title': title,
          'description': description,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'duration': durationMinutes,
          'type': appointmentTypeToDb(type),
          'status': 'upcoming',
          'meeting_link': meetingLink,
          'consultation_id': consultationId,
          'ticket_id': ticketId,
        })
        .select()
        .single();

    final appointmentId = inserted['id'].toString();
    final attendeeIds = extraAttendeeIds.where((id) => id != clientId).toSet().toList();
    if (attendeeIds.isNotEmpty) {
      await _client.from('appointment_attendees').insert(
            attendeeIds.map((id) => {'appointment_id': appointmentId, 'client_id': id}).toList(),
          );
    }
  }

  Future<void> updateStatus(String id, AppointmentStatus status) async {
    await _client.from('appointments').update({'status': appointmentStatusToDb(status)}).eq('id', id);
  }

  /// مواعيد العميل الحالي — كعميل أساسي (client_id) أو كحاضر إضافي
  /// (appointment_attendees) — يقابل استعلام "مواعيدي" في client-dashboard.html
  /// مع دعم الحضور المتعدد الجديد.
  Future<List<Appointment>> fetchMine(String clientId) async {
    final own = await _client.from('appointments').select().eq('client_id', clientId).order('scheduled_at', ascending: true);
    final ownList = (own as List).map((e) => Appointment.fromMap(e as Map<String, dynamic>)).toList();

    final attendeeRows = await _client.from('appointment_attendees').select('appointment_id').eq('client_id', clientId);
    final attendeeIds = (attendeeRows as List).map((e) => e['appointment_id'].toString()).toList();
    if (attendeeIds.isEmpty) {
      return ownList;
    }

    final extra = await _client.from('appointments').select().inFilter('id', attendeeIds).order('scheduled_at', ascending: true);
    final extraList = (extra as List).map((e) => Appointment.fromMap(e as Map<String, dynamic>)).toList();

    final byId = <String, Appointment>{};
    for (final a in [...ownList, ...extraList]) {
      byId[a.id] = a;
    }
    final merged = byId.values.toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return merged;
  }
}
