import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/common_widgets.dart';
import '../application/recent_activity_providers.dart';

/// "النشاط الأخير" / "إشعاراتي" — صفحة تجمع آخر الاستشارات والتذاكر والمواعيد
/// والرسائل بقائمة زمنية واحدة. تُستخدم لكل من الموظف (`mine: false`، كل
/// المكتب) والعميل (`mine: true`، نشاطه هو فقط) بنفس الشاشة.
class RecentActivityScreen extends ConsumerWidget {
  final bool mine;
  const RecentActivityScreen({super.key, this.mine = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mine ? myRecentActivityProvider : recentActivityProvider;
    final activityAsync = ref.watch(provider);
    final title = mine ? 'إشعاراتي' : 'النشاط الأخير';

    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: Column(
        children: [
          GlowBanner(
            icon: Icons.notifications_outlined,
            title: title,
            subtitle: mine ? 'كل جديد باستشاراتك ومواعيدك ومحادثاتك' : 'كل جديد بالاستشارات والمواعيد والدعم الفني والمحادثات',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(provider),
              child: activityAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: 'تعذّر تحميل النشاط', onRetry: () => ref.invalidate(provider)),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(message: 'لا يوجد نشاط بعد', icon: Icons.timeline_outlined);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return FadeSlideIn(
                        index: i,
                        child: ModernCard(
                          padding: EdgeInsets.zero,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: item.color, width: 4)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: item.color.withValues(alpha: 0.12),
                                child: Icon(item.icon, color: item.color),
                              ),
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Text(
                                DateFormat('MM/dd HH:mm').format(item.timestamp),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              onTap: item.route == null ? null : () => context.push(item.route!),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
