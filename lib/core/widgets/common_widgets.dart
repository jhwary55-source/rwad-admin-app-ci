import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// شريط عنوان بتدرج تيل→داكن (مطابق لهوية الموقع) + تمويه زجاجي خفيف على
/// الخلفية (مثل `backdrop-filter: blur()` بشريط تنقّل الموقع) — بديل موحّد
/// عن AppBar العادي، يُستخدم بكل شاشة بالتطبيق (رئيسية وفرعية).
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(decoration: const BoxDecoration(gradient: AppGradients.tealToDark)),
        ),
      ),
    );
  }
}

/// لافتة علوية زخرفية تُستخدم أعلى الشاشات الرئيسية (الرئيسية، الحسابات،
/// المواعيد، التحليلات...) — تدرج تيل→داكن مع "توهّج" دائري ناعم بلونين
/// (ذهبي وتيل) بنفس أسلوب `radial-gradient` خلف قسم Hero وقسم "من نحن" بالموقع،
/// بدل خلفية متدرجة مسطحة بلا عمق.
class GlowBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const GlowBanner({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
        decoration: const BoxDecoration(gradient: AppGradients.tealToDark),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -40,
              left: -30,
              child: _glowCircle(AppColors.gold.withValues(alpha: 0.35), 130),
            ),
            Positioned(
              bottom: -50,
              right: -20,
              child: _glowCircle(AppColors.primary.withValues(alpha: 0.5), 150),
            ),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.goldToTeal,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// دائرة صورة الحساب: تعرض avatar_url إن وُجد، وإلا حرف أول الاسم بتدرج
/// ذهبي — مطابق لسلوك `.up-avatar` بالموقع (fallback عند غياب الصورة).
class PersonAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;

  const PersonAvatar({super.key, required this.avatarUrl, required this.name, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(avatarUrl!));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.gold, AppColors.goldLight]),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0] : '؟',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.8),
        ),
      ),
    );
  }
}

/// بطاقة حديثة بحواف وظل ناعم مطابق لبطاقات الموقع (`.team-card`/`.partner-card`)
/// — تُستخدم بدل `Card` القياسية بالشاشات المواجهة للعميل.
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ModernCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

/// عنوان قسم بخط عريض وشريط تدرج صغير أسفله — مطابق لـ `.section-title::after` بالموقع.
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
        const SizedBox(height: 6),
        Container(
          width: 46,
          height: 4,
          decoration: BoxDecoration(gradient: AppGradients.goldToTeal, borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
  }
}

/// زر بيضاوي بتدرج وظل — مطابق لـ `.btn-free-consultation` بالموقع، للأزرار الرئيسية.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const GradientButton({super.key, required this.label, this.icon, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppGradients.goldToTeal,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Center(
              child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else ...[
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حركة دخول بسيطة (تلاشي + انزلاق للأعلى) تحاكي AOS `fade-up` بالموقع —
/// تُستخدم بعناصر القوائم الثابتة فقط (وليس الشات، لتفادي إعادة التحريك أثناء التمرير).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 60).clamp(0, 400);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 16), child: child),
        );
      },
      child: child,
    );
  }
}

/// بلاطة إجراء مربّعة (أيقونة + تسمية) مع شارة حمراء اختيارية بعدد العناصر
/// الجديدة — تُستخدم باختصارات الرئيسية لكل من الموظف والعميل.
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ModernCard(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              if (badgeCount > 0) Positioned(top: -6, right: -6, child: NotificationCountBadge(count: badgeCount)),
            ],
          ),
        ),
      ),
    );
  }
}

/// شارة حمراء دائرية بعدد (99+ عند التجاوز) — نفس الشارة تُستخدم بجرس
/// الإشعارات وبلاطات الاختصارات.
class NotificationCountBadge extends StatelessWidget {
  final int count;
  const NotificationCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

/// جرس الإشعارات بشريط العنوان — يعرض شارة العدد فوقه عند وجود أي جديد.
class NotificationBellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const NotificationBellButton({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'الإشعارات',
          onPressed: onTap,
        ),
        if (count > 0) Positioned(top: 6, right: 6, child: NotificationCountBadge(count: count)),
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const KpiCard({super.key, required this.label, required this.value, required this.icon, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
