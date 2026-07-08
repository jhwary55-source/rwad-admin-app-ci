import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

/// نداء دالة `send-push` الخلفية (Netlify Function) — نفس نمط
/// `AiIntakeRepository`: الخادم يحمل بيانات Firebase الحسّاسة، والتطبيق
/// يرسل فقط طلب "أرسل إشعارًا" مع مفتاح API العام. الفشل هنا **غير حرج**؛
/// لا يجب أن يوقف أي عملية أساسية (إرسال رسالة، حجز موعد...)، فيُبتلع
/// الخطأ بصمت دائمًا.
class PushSender {
  final http.Client _http;
  PushSender(this._http);

  Uri get _url => Uri.parse('${Env.websiteBaseUrl}/.netlify/functions/send-push');

  Future<void> send({
    List<String>? userIds,
    bool toStaff = false,
    String? excludeUserId,
    required String title,
    required String message,
    String? imageUrl,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _http
          .post(
            _url,
            headers: {'Content-Type': 'application/json', 'x-api-secret': Env.apiSecret},
            body: jsonEncode({
              if (userIds != null) 'userIds': userIds,
              'toStaff': toStaff,
              if (excludeUserId != null) 'excludeUserId': excludeUserId,
              'title': title,
              'message': message,
              if (imageUrl != null) 'imageUrl': imageUrl,
              if (data != null) 'data': data,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // إشعار الدفع ثانوي دائمًا — لا يجب أن يفشل بسببه أي إجراء أساسي.
    }
  }
}

final pushSenderProvider = Provider<PushSender>((ref) => PushSender(http.Client()));
