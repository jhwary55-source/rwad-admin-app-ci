import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/consultation.dart';
import '../../appointments/presentation/appointment_form_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../application/consultations_providers.dart';

class ConsultationDetailScreen extends ConsumerStatefulWidget {
  final String consultationId;
  const ConsultationDetailScreen({super.key, required this.consultationId});

  @override
  ConsumerState<ConsultationDetailScreen> createState() => _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends ConsumerState<ConsultationDetailScreen> {
  bool _ratingPromptShown = false;

  void _maybeShowRatingPrompt(Consultation c, bool isStaff) {
    if (isStaff || c.status != ConsultationStatus.closed || c.rating != null || _ratingPromptShown) return;
    _ratingPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _RatingDialog(
          onRate: (stars) async {
            await ref.read(consultationsRepositoryProvider).rate(c.id, stars);
            ref.invalidate(consultationDetailProvider(c.id));
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(consultationDetailProvider(widget.consultationId));
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isStaff = profile?.isStaff ?? false;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'تفاصيل الاستشارة',
        actions: [
          if (isStaff)
            detailAsync.maybeWhen(
              data: (c) => IconButton(
                icon: const Icon(Icons.event_available_outlined),
                tooltip: 'حجز موعد',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AppointmentFormDialog(
                    initialClientId: c.clientId,
                    initialClientName: c.clientName,
                    initialClientEmail: c.clientEmail,
                    consultationId: c.id,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat/consultation/${widget.consultationId}?title=${Uri.encodeComponent('محادثة الاستشارة')}'),
        icon: const Icon(Icons.chat),
        label: const Text('فتح الدردشة'),
      ),
      body: detailAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'تعذّر تحميل الاستشارة'),
        data: (c) {
          _maybeShowRatingPrompt(c, isStaff);
          return _Body(consultation: c, ref: ref, isStaff: isStaff);
        },
      ),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  final ValueChanged<int> onRate;
  const _RatingDialog({required this.onRate});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _stars = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('كيف كانت تجربتك؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('تم إغلاق استشارتك — يسعدنا تقييمك'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return IconButton(
                iconSize: 34,
                icon: Icon(filled ? Icons.star : Icons.star_border, color: AppColors.gold),
                onPressed: () => setState(() => _stars = i + 1),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('لاحقًا')),
        FilledButton(
          onPressed: _stars == 0 || _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  widget.onRate(_stars);
                  if (mounted) Navigator.of(context).pop();
                },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('إرسال'),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final Consultation consultation;
  final WidgetRef ref;
  final bool isStaff;
  const _Body({required this.consultation, required this.ref, required this.isStaff});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(consultation.clientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              if (consultation.clientPhone != null)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(consultation.clientPhone!),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${consultation.clientPhone}')),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('اتصال هاتفي'),
                    ),
                  ],
                ),
              if (consultation.category != null) ...[
                const SizedBox(height: 6),
                StatusBadge(label: consultation.category!, color: AppColors.gold),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'ملخص القضية'),
        const SizedBox(height: 8),
        ModernCard(
          padding: const EdgeInsets.all(14),
          child: Text(consultation.caseSummary ?? 'لا يوجد ملخص بعد.'),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'حالة الاستشارة'),
        const SizedBox(height: 8),
        if (isStaff)
          Wrap(
            spacing: 8,
            children: ConsultationStatus.values
                .map((s) => ChoiceChip(
                      label: Text(consultationStatusToArabic(s)),
                      selected: consultation.status == s,
                      onSelected: (_) async {
                        await ref.read(consultationsRepositoryProvider).updateStatus(consultation.id, s);
                        ref.invalidate(consultationDetailProvider(consultation.id));
                        ref.invalidate(consultationsListProvider);
                      },
                    ))
                .toList(),
          )
        else
          StatusBadge(label: consultationStatusToArabic(consultation.status), color: AppColors.primary),
        if (isStaff && consultation.rating != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('تقييم العميل: ', style: TextStyle(fontWeight: FontWeight.w700)),
              ...List.generate(
                5,
                (i) => Icon(
                  i < consultation.rating! ? Icons.star : Icons.star_border,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
        if (!isStaff && consultation.status == ConsultationStatus.closed) ...[
          const SizedBox(height: 16),
          const Text('قيّم الاستشارة', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final filled = consultation.rating != null && i < consultation.rating!;
              return IconButton(
                icon: Icon(filled ? Icons.star : Icons.star_border, color: AppColors.gold),
                onPressed: () async {
                  await ref.read(consultationsRepositoryProvider).rate(consultation.id, i + 1);
                  ref.invalidate(consultationDetailProvider(consultation.id));
                },
              );
            }),
          ),
        ],
      ],
    );
  }
}
