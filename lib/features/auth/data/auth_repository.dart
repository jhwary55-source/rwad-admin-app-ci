import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/notifications/push_notifications_service.dart';
import '../../../models/profile.dart';

class AppAuthException implements Exception {
  final String message;
  AppAuthException(this.message);
  @override
  String toString() => message;
}

/// طبقة المصادقة: تخدم كل الأدوار (عميل وموظف)، تمامًا مثل login.html
/// الذي يوجّه كل حساب حسب دوره بدل رفض أحدهم. لا يوجد DB trigger لإنشاء
/// صف profiles عند التسجيل (تأكدنا من ذلك بقراءة كل ملفات supabase-schema)
/// — الإنشاء "كسول" ويحدث فقط أول مرة يسجّل فيها المستخدم دخوله، بنفس
/// منطق إعادة المحاولة الموجود في client-dashboard.html.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<Profile> signIn({required String email, required String password}) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) {
      throw AppAuthException('تعذّر تسجيل الدخول.');
    }
    final profile = await _fetchOrCreateProfile(user);
    await _client.from('profiles').update({
      'last_login': DateTime.now().toUtc().toIso8601String(),
      'login_count': profile.loginCount + 1,
    }).eq('id', user.id);
    return profile;
  }

  /// تسجيل حساب عميل جديد — نفس register.html بالضبط: signUp فقط
  /// (بدون إدراج profiles وبدون تسجيل دخول تلقائي)، لأن المشروع يشترط
  /// تأكيد البريد الإلكتروني قبل أول دخول.
  Future<void> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'phone': phone},
    );
  }

  Future<Profile?> fetchProfile(String userId) async {
    final data = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<Profile> _fetchOrCreateProfile(User user) async {
    Profile? profile = await fetchProfile(user.id);
    for (var i = 0; i < 3 && profile == null; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      profile = await fetchProfile(user.id);
    }
    if (profile != null) return profile;

    final meta = user.userMetadata ?? {};
    final inserted = await _client.from('profiles').insert({
      'id': user.id,
      'name': (meta['name'] as String?) ?? user.email?.split('@').first ?? 'مستخدم',
      'phone': meta['phone'] as String?,
      'role': 'client',
    }).select().single();
    return Profile.fromMap(inserted);
  }

  Future<void> signOut() async {
    await PushNotificationsService.clearToken(_client);
    await _client.auth.signOut();
  }
}
