import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardStats {
  final int pendingConsultations;
  final int openTickets;
  final int upcomingAppointments;
  final int totalClients;

  const DashboardStats({
    required this.pendingConsultations,
    required this.openTickets,
    required this.upcomingAppointments,
    required this.totalClients,
  });
}

class DashboardRepository {
  final SupabaseClient _client;
  DashboardRepository(this._client);

  Future<int> _count(String table, {String? column, dynamic value}) async {
    var query = _client.from(table).select('id');
    if (column != null) query = query.eq(column, value);
    final result = await query.count(CountOption.exact);
    return result.count;
  }

  Future<DashboardStats> fetchStats() async {
    final results = await Future.wait([
      _count('consultations', column: 'status', value: 'pending'),
      _count('support_tickets', column: 'status', value: 'open'),
      _count('appointments', column: 'status', value: 'upcoming'),
      _count('profiles', column: 'role', value: 'client'),
    ]);
    return DashboardStats(
      pendingConsultations: results[0],
      openTickets: results[1],
      upcomingAppointments: results[2],
      totalClients: results[3],
    );
  }
}
