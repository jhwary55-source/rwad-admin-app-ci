import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/profile.dart';

class ProfilesRepository {
  final SupabaseClient _client;
  ProfilesRepository(this._client);

  Future<List<Profile>> fetchAll({String? search}) async {
    var query = _client.from('profiles').select();
    if (search != null && search.trim().isNotEmpty) {
      query = query.or('name.ilike.%$search%,email.ilike.%$search%,phone.ilike.%$search%');
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Profile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Profile> fetchOne(String id) async {
    final data = await _client.from('profiles').select().eq('id', id).single();
    return Profile.fromMap(data);
  }

  Future<void> updateRole(String id, String role) async {
    await _client.from('profiles').update({'role': role}).eq('id', id);
  }

  Future<void> updateDetails(String id, {String? name, String? phone}) async {
    final update = <String, dynamic>{};
    if (name != null) update['name'] = name;
    if (phone != null) update['phone'] = phone;
    if (update.isEmpty) return;
    await _client.from('profiles').update(update).eq('id', id);
  }

  /// يرفع صورة الحساب إلى نفس مخزن الموقع (bucket `avatars`، المسار
  /// `${userId}/avatar.${ext}`) ويحدّث عمود `avatar_url` — متاحة لأي مستخدم
  /// (عميل أو موظف) لصورته الخاصة فقط.
  Future<String> uploadAvatar({required String userId, required Uint8List bytes, required String fileExt}) async {
    final path = '$userId/avatar.$fileExt';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // كسر الكاش برقم عشوائي بنهاية الرابط، وإلا قد تستمر الصورة القديمة
    // بالظهور محليًا لأن المسار نفسه لم يتغيّر.
    final bustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('profiles').update({'avatar_url': bustedUrl}).eq('id', userId);
    return bustedUrl;
  }
}
