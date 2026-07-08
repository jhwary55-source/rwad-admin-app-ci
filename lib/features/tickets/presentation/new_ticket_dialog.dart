import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/push_sender.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../application/tickets_providers.dart';

const _categories = ['استفسار عام', 'مشكلة تقنية', 'استفسار مالي', 'أخرى'];
const _priorities = ['منخفضة', 'متوسطة', 'عالية'];

Color _priorityColor(String p) {
  switch (p) {
    case 'عالية':
      return AppColors.danger;
    case 'متوسطة':
      return AppColors.gold;
    default:
      return AppColors.success;
  }
}

class NewTicketDialog extends ConsumerStatefulWidget {
  const NewTicketDialog({super.key});

  @override
  ConsumerState<NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends ConsumerState<NewTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = _categories.first;
  String _priority = _priorities.first;
  bool _saving = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(ticketsRepositoryProvider).createTicket(
            clientId: profile.id,
            clientName: profile.name,
            clientEmail: profile.email,
            subject: _subjectCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
            category: _category,
            priority: _priority,
          );
      ref.invalidate(myTicketsProvider);
      ref.read(pushSenderProvider).send(
            toStaff: true,
            title: 'تذكرة دعم جديدة 🎧',
            message: '${profile.name}: ${_subjectCtrl.text.trim()}',
            imageUrl: profile.avatarUrl,
            data: {'type': 'ticket', 'id': id},
          );
      if (mounted) Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: const BoxDecoration(gradient: AppGradients.tealToDark),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.support_agent_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تذكرة دعم جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                          SizedBox(height: 2),
                          Text('سنرد عليك في أقرب وقت ممكن', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _subjectCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الموضوع',
                            prefixIcon: Icon(Icons.subject_outlined),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _messageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تفاصيل المشكلة',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.notes_outlined)),
                          ),
                          maxLines: 3,
                          validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('التصنيف', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories
                              .map((c) => ChoiceChip(
                                    label: Text(c),
                                    selected: _category == c,
                                    selectedColor: AppColors.primary.withValues(alpha: 0.16),
                                    labelStyle: TextStyle(
                                      color: _category == c ? AppColors.primary : null,
                                      fontWeight: _category == c ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                    onSelected: (_) => setState(() => _category = c),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text('الأولوية', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _priorities.map((p) {
                            final color = _priorityColor(p);
                            final selected = _priority == p;
                            return ChoiceChip(
                              label: Text(p),
                              selected: selected,
                              selectedColor: color.withValues(alpha: 0.16),
                              side: BorderSide(color: selected ? color : Colors.grey.withValues(alpha: 0.4)),
                              avatar: CircleAvatar(backgroundColor: color, radius: 6),
                              labelStyle: TextStyle(color: selected ? color : null, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                              onSelected: (_) => setState(() => _priority = p),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        label: 'إرسال',
                        icon: Icons.send_outlined,
                        loading: _saving,
                        onPressed: _saving ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
