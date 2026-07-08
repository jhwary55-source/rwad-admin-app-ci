import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/app_router.dart';

/// معالج الرسائل بالخلفية (التطبيق مُصغَّر أو مُغلَق تمامًا) — لازم تكون
/// دالة top-level (وليست method داخل class) حتى يستدعيها Android بمعزل
/// (Isolate) منفصل عند وصول رسالة FCM والتطبيق غير مفتوح. مُعلَّمة
/// `vm:entry-point` حتى لا يُزيلها compiler الإصدار (tree shaking).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  if (message.data['type'] == 'call') {
    await PushNotificationsService._showIncomingCallUi(message.data);
  }
}

/// إشعارات الدفع (Push) عبر Firebase Cloud Messaging — تعمل على أندرويد
/// وiOS فقط (المكتبة لا تدعم ويندوز/لينكس إطلاقًا)، فتُتجاهل هذه الخدمة
/// بصمت (بدون أي خطأ) على أي منصة أخرى بدل تعطيل التطبيق.
///
/// ⚠️ **تتطلب مشروع Firebase حقيقي** ينشئه صاحب المشروع يدويًا من
/// Firebase Console (لا يمكن إنشاؤه برمجيًا)، مع وضع `google-services.json`
/// (أندرويد) و`GoogleService-Info.plist` (iOS) في مكانيهما — بدونهما تفشل
/// `Firebase.initializeApp()` بصمت وتبقى الإشعارات داخل التطبيق فقط (كما
/// كانت) دون أي تعطّل.
class PushNotificationsService {
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _tokenListenerAttached = false;

  static bool get isSupportedPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// يُستدعى مرّة واحدة عند إقلاع التطبيق (بدون الحاجة لمستخدم مسجّل دخول
  /// بعد) — يُهيّئ Firebase والإشعارات المحلية ومستمعي الرسائل الواردة.
  static Future<void> init() async {
    if (!isSupportedPlatform || _initialized) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      return; // لا مشروع Firebase مُهيّأ بعد — تجاهل بصمت
    }
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload != null) _navigate(jsonDecode(resp.payload!) as Map<String, dynamic>);
      },
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _navigate(m.data));

    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event is CallEventActionCallAccept) {
        final extra = event.callKitParams.extra ?? <String, dynamic>{};
        _navigate({...extra, 'type': 'call'});
      }
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _navigate(initialMessage.data);
  }

  /// يعرض شاشة "اتصال وارد" حقيقية (رنين + قبول/رفض) بدل إشعار عادي — تُستدعى
  /// من مستمع الرسائل بالمقدمة ومن معالج الخلفية معًا (نفس المنطق للحالتين).
  static Future<void> _showIncomingCallUi(Map<String, dynamic> data) async {
    final room = data['room'] as String?;
    if (room == null) return;
    final name = (data['name'] as String?) ?? 'اتصال وارد';
    final params = CallKitParams(
      id: room,
      nameCaller: name,
      appName: 'رواد الأنظمة',
      handle: name,
      type: 1,
      duration: 30000,
      missedCallNotification: const NotificationParams(showNotification: false),
      extra: {'room': room, 'name': name},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isFullScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#2D5869',
        actionColor: '#C5A059',
        textAccept: 'قبول',
        textDecline: 'رفض',
      ),
      ios: const IOSParams(handleType: 'generic'),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// يُستدعى عند كل تسجيل دخول ناجح — يطلب صلاحية الإشعارات ويحفظ توكن هذا
  /// الجهاز مرتبطًا بالمستخدم الحالي بجدول `device_tokens`.
  static Future<void> syncTokenForCurrentUser(SupabaseClient supabase) async {
    if (!isSupportedPlatform || !_initialized) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) await _saveToken(supabase, token);

    if (!_tokenListenerAttached) {
      _tokenListenerAttached = true;
      messaging.onTokenRefresh.listen((t) => _saveToken(supabase, t));
    }
  }

  static Future<void> _saveToken(SupabaseClient supabase, String token) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } catch (_) {}
  }

  /// يُستدعى عند تسجيل الخروج — يحذف توكن هذا الجهاز حتى لا يستمر باستقبال
  /// إشعارات مخصّصة لحساب لم يعد مسجّلاً به.
  static Future<void> clearToken(SupabaseClient supabase) async {
    if (!isSupportedPlatform || !_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await supabase.from('device_tokens').delete().eq('token', token);
    } catch (_) {}
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (message.data['type'] == 'call') {
      await _showIncomingCallUi(message.data);
      return;
    }
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails('default_channel', 'إشعارات عامة', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _navigate(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    switch (data['type'] as String?) {
      case 'message':
        final kind = (data['kind'] as String?) ?? 'consultation';
        final id = data['id'] as String?;
        if (id != null) {
          final title = kind == 'ticket' ? 'محادثة الدعم الفني' : 'محادثة الاستشارة';
          context.push('/chat/$kind/$id?title=${Uri.encodeComponent(title)}');
        }
        break;
      case 'appointment':
        context.push(data['isStaff'] == 'true' ? '/appointments' : '/client/appointments');
        break;
      case 'ticket':
        final id = data['id'] as String?;
        if (id != null) context.push('/tickets/$id');
        break;
      case 'consultation':
        final id = data['id'] as String?;
        if (id != null) context.push('/consultations/$id');
        break;
      case 'call':
        final room = data['room'] as String?;
        if (room != null) {
          // من يستقبل هذا الإشعار هو المُتصَل به دائمًا، فيجب أن يدخل كضيف
          // (guest) لا كمضيف — بدون mode=guest يدخل الافتراضي host خطأً.
          context.push('/call?room=${Uri.encodeComponent(room)}&name=${Uri.encodeComponent((data['name'] as String?) ?? '')}&mode=guest');
        }
        break;
    }
  }
}
