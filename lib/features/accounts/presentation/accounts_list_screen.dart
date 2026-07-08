import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/profile.dart';
import '../application/accounts_providers.dart';

class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({super.key});

  Color _roleColor(StaffRole role) {
    switch (role) {
      case StaffRole.superAdmin:
        return AppColors.gold;
      case StaffRole.admin:
        return AppColors.primary;
      case StaffRole.client:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Column(
      children: [
        const GlowBanner(
          icon: Icons.people_outline,
          title: 'الحسابات',
          subtitle: 'إدارة حسابات العملاء والموظفين وصلاحياتهم',
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث بالاسم أو البريد أو الجوال...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => ref.read(accountsSearchProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: accountsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: 'تعذّر تحميل الحسابات', onRetry: () => ref.invalidate(accountsListProvider)),
            data: (accounts) {
              if (accounts.isEmpty) return const EmptyState(message: 'لا توجد حسابات مطابقة');
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = accounts[i];
                  return FadeSlideIn(
                    index: i,
                    child: ModernCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: PersonAvatar(avatarUrl: p.avatarUrl, name: p.name),
                        title: Text(p.name),
                        subtitle: Text(p.email ?? p.phone ?? ''),
                        trailing: StatusBadge(label: roleToArabic(p.role), color: _roleColor(p.role)),
                        onTap: () => context.push('/accounts/${p.id}'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
