import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsSnapshot {
  final Map<String, int> consultationsByStatus;
  final Map<String, int> appointmentsByStatus;
  final Map<String, int> ticketsByStatus;
  final double averageRating;
  final Map<DateTime, int> visitsByDay;
  final Map<int, int> visitsByHour;

  const AnalyticsSnapshot({
    required this.consultationsByStatus,
    required this.appointmentsByStatus,
    required this.ticketsByStatus,
    required this.averageRating,
    required this.visitsByDay,
    required this.visitsByHour,
  });
}

/// يعيد بناء نفس الرسوم الموجودة في تبويب "تحليل البوت" و"الإحصائيات" داخل
/// admin.html، لكن بمعالجة محلية بعد جلب الأعمدة المطلوبة فقط (لا توجد
/// دوال RPC مخصصة على قاعدة البيانات لهذه التجميعات).
class AnalyticsRepository {
  final SupabaseClient _client;
  AnalyticsRepository(this._client);

  Map<String, int> _countBy(List<dynamic> rows, String key) {
    final map = <String, int>{};
    for (final row in rows) {
      final value = (row as Map<String, dynamic>)[key]?.toString() ?? 'غير محدد';
      map[value] = (map[value] ?? 0) + 1;
    }
    return map;
  }

  Future<AnalyticsSnapshot> fetchSnapshot() async {
    final since = DateTime.now().subtract(const Duration(days: 14)).toUtc().toIso8601String();

    final results = await Future.wait([
      _client.from('consultations').select('status'),
      _client.from('appointments').select('status'),
      _client.from('support_tickets').select('status'),
      _client.from('consultations').select('rating').not('rating', 'is', null),
      _client.from('site_analytics').select('visited_at').gte('visited_at', since),
    ]);

    final ratings = (results[3] as List)
        .map((e) => (e as Map<String, dynamic>)['rating'] as num?)
        .whereType<num>()
        .toList();
    final avgRating = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;

    final visitsByDay = <DateTime, int>{};
    final visitsByHour = <int, int>{};
    for (final row in results[4] as List) {
      final raw = (row as Map<String, dynamic>)['visited_at']?.toString();
      final dt = DateTime.tryParse(raw ?? '')?.toLocal();
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      visitsByDay[day] = (visitsByDay[day] ?? 0) + 1;
      visitsByHour[dt.hour] = (visitsByHour[dt.hour] ?? 0) + 1;
    }

    return AnalyticsSnapshot(
      consultationsByStatus: _countBy(results[0] as List, 'status'),
      appointmentsByStatus: _countBy(results[1] as List, 'status'),
      ticketsByStatus: _countBy(results[2] as List, 'status'),
      averageRating: avgRating,
      visitsByDay: visitsByDay,
      visitsByHour: visitsByHour,
    );
  }
}
