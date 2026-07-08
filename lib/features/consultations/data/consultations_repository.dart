import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/consultation.dart';

class ConsultationsRepository {
  final SupabaseClient _client;
  ConsultationsRepository(this._client);

  Future<List<Consultation>> fetchAll({ConsultationStatus? status}) async {
    var query = _client.from('consultations').select();
    if (status != null) query = query.eq('status', consultationStatusToDb(status));
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Consultation.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Consultation> fetchOne(String id) async {
    final data = await _client.from('consultations').select().eq('id', id).single();
    return Consultation.fromMap(data);
  }

  Future<void> updateStatus(String id, ConsultationStatus status) async {
    await _client.from('consultations').update({'status': consultationStatusToDb(status)}).eq('id', id);
  }

  Future<void> assign(String id, String staffId) async {
    await _client.from('consultations').update({'assigned_to': staffId}).eq('id', id);
  }

  /// استشارات العميل الحالي فقط — يقابل استعلام "استشاراتي" في client-dashboard.html.
  Future<List<Consultation>> fetchMine(String clientId) async {
    final data = await _client.from('consultations').select().eq('client_id', clientId).order('created_at', ascending: false);
    return (data as List).map((e) => Consultation.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> rate(String id, int rating) async {
    await _client.from('consultations').update({'rating': rating}).eq('id', id);
  }
}
