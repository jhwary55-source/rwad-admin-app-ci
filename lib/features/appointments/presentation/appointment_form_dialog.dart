import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/push_sender.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/appointment.dart';
import '../../../models/chat_message.dart';
import '../../../models/profile.dart';
import '../../auth/application/auth_providers.dart';
import '../../chat/application/chat_providers.dart';
import '../application/appointments_providers.dart';
import 'client_picker_dialog.dart';

/// حوار "موعد جديد" الموحّد: يُفتح إما بشكل مستقل من شاشة المواعيد (بدون
/// [consultationId]/[ticketId])، أو من داخل تفاصيل استشارة/تذكرة مع تمرير
/// معرّفها، وعندها يُرسل تلقائيًا إشعار نظام بنفس محادثة تلك الاستشارة/التذكرة
/// فور إنشاء الموعد.
class AppointmentFormDialog extends ConsumerStatefulWidget {
  final String? initialClientId;
  final String? initialClientName;
  final String? initialClientEmail;
  final String? initialClientAvatarUrl;
  final String? consultationId;
  final String? ticketId;

  const AppointmentFormDialog({
    super.key,
    this.initialClientId,
    this.initialClientName,
    this.initialClientEmail,
    this.initialClientAvatarUrl,
    this.consultationId,
    this.ticketId,
  });

  @override
  ConsumerState<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends ConsumerState<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  int _duration = 30;
  AppointmentType _type = AppointmentType.video;
  bool _saving = false;

  Profile? _primaryClient;
  final _extraAttendees = <String, Profile>{};

  bool get _clientLocked => widget.initialClientId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialClientId != null) {
      _primaryClient = Profile(
        id: widget.initialClientId!,
        name: widget.initialClientName ?? 'بدون اسم',
        email: widget.initialClientEmail,
        avatarUrl: widget.initialClientAvatarUrl,
        role: StaffRole.client,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPrimaryClient() async {
    final picked = await showSingleClientPicker(context);
    if (picked != null) setState(() => _primaryClient = picked);
  }

  Future<void> _addAttendees() async {
    final excludeIds = [if (_primaryClient != null) _primaryClient!.id, ..._extraAttendees.keys];
    final picked = await showMultiClientPicker(context, excludeIds: excludeIds);
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        for (final p in picked) {
          _extraAttendees[p.id] = p;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_primaryClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر العميل أولًا')));
      return;
    }
    setState(() => _saving = true);
    final scheduledAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    try {
      await ref.read(appointmentsRepositoryProvider).create(
            clientId: _primaryClient!.id,
            clientName: _primaryClient!.name,
            clientEmail: _primaryClient!.email,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            scheduledAt: scheduledAt,
            durationMinutes: _duration,
            type: _type,
            consultationId: widget.consultationId,
            ticketId: widget.ticketId,
            extraAttendeeIds: _extraAttendees.keys.toList(),
          );
      ref.invalidate(appointmentsListProvider);

      if (widget.consultationId != null || widget.ticketId != null) {
        await _notifyClientInChat(scheduledAt);
      }
      _notifyClientPush(scheduledAt);

      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notifyClientPush(DateTime scheduledAt) {
    final staff = ref.read(currentProfileProvider).valueOrNull;
    if (staff == null || _primaryClient == null) return;
    final when = DateFormat('yyyy/MM/dd - HH:mm').format(scheduledAt);
    final targets = {_primaryClient!.id, ..._extraAttendees.keys};
    ref.read(pushSenderProvider).send(
          userIds: targets.toList(),
          title: 'موعد جديد 📅',
          message: '${_titleCtrl.text.trim()} — $when',
          imageUrl: staff.avatarUrl,
          data: {'type': 'appointment', 'isStaff': 'false'},
        );
  }

  Future<void> _notifyClientInChat(DateTime scheduledAt) async {
    final staff = ref.read(currentProfileProvider).valueOrNull;
    if (staff == null) return;
    final kind = widget.consultationId != null ? ChatKind.consultation : ChatKind.ticket;
    final parentId = widget.consultationId ?? widget.ticketId!;
    final when = DateFormat('yyyy/MM/dd - HH:mm').format(scheduledAt);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            kind: kind,
            parentId: parentId,
            content: '📅 تم تحديد موعد: ${_titleCtrl.text.trim()} بتاريخ $when',
            senderId: staff.id,
            senderName: staff.name,
            senderRole: 'system',
          );
    } catch (_) {
      // إشعار الشات ثانوي — عدم فشله يجب ألا يفشل حفظ الموعد نفسه.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('موعد جديد'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('العميل الأساسي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              if (_primaryClient != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PersonAvatar(avatarUrl: _primaryClient!.avatarUrl, name: _primaryClient!.name),
                  title: Text(_primaryClient!.name),
                  subtitle: Text(_primaryClient!.email ?? ''),
                  trailing: _clientLocked ? null : TextButton(onPressed: _pickPrimaryClient, child: const Text('تغيير')),
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickPrimaryClient,
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('اختر العميل'),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('حضور إضافيون', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addAttendees,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: const Text('إضافة'),
                  ),
                ],
              ),
              if (_extraAttendees.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _extraAttendees.values
                      .map((p) => Chip(
                            avatar: PersonAvatar(avatarUrl: p.avatarUrl, name: p.name, radius: 10),
                            label: Text(p.name),
                            onDeleted: () => setState(() => _extraAttendees.remove(p.id)),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'عنوان الموعد'),
                validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('${_date.year}/${_date.month}/${_date.day}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AppointmentType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'نوع الموعد'),
                items: AppointmentType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(appointmentTypeToArabic(t))))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _duration,
                decoration: const InputDecoration(labelText: 'المدة (دقيقة)'),
                items: const [15, 30, 45, 60, 90]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d دقيقة')))
                    .toList(),
                onChanged: (v) => setState(() => _duration = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
