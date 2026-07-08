import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

class AiIntakeException implements Exception {
  final String message;
  AiIntakeException(this.message);
  @override
  String toString() => message;
}

/// طبقة "طلب استشارة جديدة" — تنادي netlify/functions/ai-intake.js (الذي
/// يحمل مفتاح Anthropic بأمان على السيرفر) بدل مناداة Anthropic مباشرة من
/// التطبيق. إدراج الاستشارة نفسه في Supabase يبقى من طرف العميل مباشرة،
/// تمامًا كما يفعل chat.html.
class AiIntakeRepository {
  final http.Client _http;
  final SupabaseClient _supabase;

  AiIntakeRepository(this._http, this._supabase);

  Uri get _functionUrl => Uri.parse('${Env.websiteBaseUrl}/.netlify/functions/ai-intake');

  Future<String> sendChat({
    required String clientName,
    required List<Map<String, String>> messages,
  }) async {
    final res = await _http.post(
      _functionUrl,
      headers: {'Content-Type': 'application/json', 'x-api-secret': Env.apiSecret},
      body: jsonEncode({'mode': 'chat', 'clientName': clientName, 'messages': messages}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AiIntakeException((data['error'] as String?) ?? 'تعذّر الاتصال بالمساعد الذكي.');
    }
    return data['text'] as String;
  }

  Future<String> summarize(String conversationText) async {
    final res = await _http.post(
      _functionUrl,
      headers: {'Content-Type': 'application/json', 'x-api-secret': Env.apiSecret},
      body: jsonEncode({'mode': 'summary', 'conversationText': conversationText}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) return '';
    return (data['text'] as String?) ?? '';
  }

  Future<String> createConsultation({
    required String clientId,
    required String clientName,
    String? clientPhone,
    String? clientEmail,
    required String caseSummary,
    required String fullConversation,
    String? category,
  }) async {
    final row = await _supabase.from('consultations').insert({
      'client_id': clientId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_email': clientEmail,
      'case_summary': caseSummary.isEmpty ? '(لا يوجد ملخص)' : caseSummary,
      'full_conversation': fullConversation,
      'status': 'pending',
      'category': category,
    }).select().single();
    return row['id'].toString();
  }
}
