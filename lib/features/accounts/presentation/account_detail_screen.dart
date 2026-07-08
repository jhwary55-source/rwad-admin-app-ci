import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/profile.dart';
import '../../auth/application/auth_providers.dart';
import '../application/accounts_providers.dart';

class AccountDetailScreen extends ConsumerWidget {
  final String profileId;
  const AccountDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(accountDetailProvider(profileId));

    return Scaffold(
      appBar: const GradientAppBar(title: 'تفاصيل الحساب'),
      body: detailAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'تعذّر تحميل بيانات الحساب'),
        data: (profile) => _AccountDetailBody(profile: profile),
      ),
    );
  }
}

class _AccountDetailBody extends ConsumerWidget {
  final Profile profile;
  const _AccountDetailBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: PersonAvatar(avatarUrl: profile.avatarUrl, name: profile.name, radius: 40)),
        const SizedBox(height: 12),
        Center(child: Text(profile.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StatusBadge(label: roleToArabic(profile.role), color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(icon: Icons.email_outlined, label: 'البريد الإلكتروني', value: profile.email ?? '—'),
              _InfoRow(icon: Icons.phone_outlined, label: 'الجوال', value: profile.phone ?? '—'),
              _InfoRow(icon: Icons.login, label: 'عدد مرات الدخول', value: '${profile.loginCount}'),
              _InfoRow(
                icon: Icons.access_time,
                label: 'آخر دخول',
                value: profile.lastLogin != null ? DateFormat('yyyy/MM/dd - HH:mm').format(profile.lastLogin!) : '—',
              ),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'تاريخ الإنشاء',
                value: DateFormat('yyyy/MM/dd').format(profile.createdAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ModernCard(child: _RoleEditor(profile: profile)),
      ],
    );
  }
}

/// يطابق منطق changeRole في admin.html بالضبط: لا يقدر أحد يعدّل دوره
/// الخاص، ولا يقدر "مشرف" عادي يعدّل دور "سوبر أدمن" — فقط سوبر أدمن يقدر.
/// خيار "سوبر أدمن" بالقائمة يظهر فقط إذا كان المستخدم الحالي سوبر أدمن.
class _RoleEditor extends ConsumerWidget {
  final Profile profile;
  const _RoleEditor({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfile = ref.watch(currentProfileProvider).valueOrNull;
    final isSelf = currentProfile?.id == profile.id;
    final iAmSuper = currentProfile?.role == StaffRole.superAdmin;
    final canEdit = !isSelf && !(profile.role == StaffRole.superAdmin && !iAmSuper);

    if (!canEdit) {
      return Row(
        children: [
          const Text('صلاحية الحساب', style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            isSelf ? 'لا يمكنك تعديل صلاحيتك الخاصة' : 'صلاحية سوبر أدمن — لا يعدّلها إلا سوبر أدمن آخر',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('صلاحية الحساب', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<StaffRole>(
          initialValue: profile.role,
          items: [
            const DropdownMenuItem(value: StaffRole.client, child: Text('عميل')),
            const DropdownMenuItem(value: StaffRole.admin, child: Text('مشرف')),
            if (iAmSuper) const DropdownMenuItem(value: StaffRole.superAdmin, child: Text('⭐ سوبر أدمن')),
          ],
          onChanged: (role) async {
            if (role == null) return;
            if (role == StaffRole.superAdmin && !iAmSuper) return;
            await ref.read(profilesRepositoryProvider).updateRole(profile.id, roleToDb(role));
            ref.invalidate(accountDetailProvider(profile.id));
            ref.invalidate(accountsListProvider);
          },
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
