import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../auth/application/auth_providers.dart';

/// "حسابي" — عرض الملف الشخصي وتعديله وتسجيل الخروج، منفصلة الآن عن شاشة
/// "الإعدادات" التي أصبحت خاصة بتفضيلات التطبيق (الثيم/اللغة/حجم الخط) فقط.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar(String userId) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.contains('.') ? picked.path.split('.').last.toLowerCase() : 'jpg';
      await ref.read(profilesRepositoryProvider).uploadAvatar(userId: userId, bytes: bytes, fileExt: ext);
      ref.invalidate(currentProfileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تحديث الصورة، حاول مرة أخرى')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: 'حسابي'),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'تعذّر تحميل الملف الشخصي'),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PersonAvatar(avatarUrl: profile.avatarUrl, name: profile.name, radius: 42),
                    if (_uploadingAvatar)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.black45,
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                        ),
                      ),
                    Positioned(
                      bottom: -2,
                      left: -2,
                      child: Material(
                        color: AppColors.gold,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploadingAvatar ? null : () => _pickAndUploadAvatar(profile.id),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(profile.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Center(child: Text(profile.email ?? '', style: const TextStyle(color: Colors.grey))),
              const SizedBox(height: 24),
              ModernCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('تعديل الاسم / الجوال'),
                      onTap: () => _showEditDialog(context, ref, profile.id, profile.name, profile.phone),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('عن التطبيق'),
                      subtitle: const Text('لوحة تحكم رواد الأنظمة — الإصدار 1.0.0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.invalidate(currentProfileProvider);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String id, String name, String? phone) {
    final nameCtrl = TextEditingController(text: name);
    final phoneCtrl = TextEditingController(text: phone ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل البيانات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الجوال')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              await ref.read(profilesRepositoryProvider).updateDetails(id, name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
              ref.invalidate(currentProfileProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
