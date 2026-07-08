import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/profile.dart';
import '../../accounts/application/accounts_providers.dart';

/// يفتح بحثًا عن عميل واحد (بالاسم/الجوال/البريد) ويعيده — يُستخدم لاختيار
/// "العميل الأساسي" بحوار الموعد.
Future<Profile?> showSingleClientPicker(BuildContext context) {
  return showDialog<Profile>(
    context: context,
    builder: (_) => const _ClientPickerDialog(multiple: false),
  );
}

/// يفتح بحثًا متعدد الاختيار (حضور إضافيون) ويستبعد `excludeIds` (مثل العميل
/// الأساسي المختار مسبقًا) من نتائج البحث.
Future<List<Profile>?> showMultiClientPicker(BuildContext context, {List<String> excludeIds = const []}) {
  return showDialog<List<Profile>>(
    context: context,
    builder: (_) => _ClientPickerDialog(multiple: true, excludeIds: excludeIds),
  );
}

class _ClientPickerDialog extends ConsumerStatefulWidget {
  final bool multiple;
  final List<String> excludeIds;
  const _ClientPickerDialog({required this.multiple, this.excludeIds = const []});

  @override
  ConsumerState<_ClientPickerDialog> createState() => _ClientPickerDialogState();
}

class _ClientPickerDialogState extends ConsumerState<_ClientPickerDialog> {
  final _searchCtrl = TextEditingController();
  final _selected = <String, Profile>{};
  List<Profile> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    setState(() => _loading = true);
    try {
      final all = await ref.read(profilesRepositoryProvider).fetchAll(search: term);
      if (!mounted) return;
      setState(() {
        _results = all.where((p) => !widget.excludeIds.contains(p.id)).toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Profile p) {
    setState(() {
      if (widget.multiple) {
        if (_selected.containsKey(p.id)) {
          _selected.remove(p.id);
        } else {
          _selected[p.id] = p;
        }
      } else {
        Navigator.of(context).pop(p);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.multiple ? 'إضافة حضور' : 'اختر العميل'),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو الجوال أو البريد...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            if (widget.multiple && _selected.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selected.values
                      .map((p) => Chip(
                            avatar: PersonAvatar(avatarUrl: p.avatarUrl, name: p.name, radius: 10),
                            label: Text(p.name),
                            onDeleted: () => setState(() => _selected.remove(p.id)),
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : _results.isEmpty
                      ? const EmptyState(message: 'لا توجد نتائج', icon: Icons.person_search_outlined)
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final p = _results[i];
                            final isSelected = _selected.containsKey(p.id);
                            return ListTile(
                              leading: PersonAvatar(avatarUrl: p.avatarUrl, name: p.name),
                              title: Text(p.name),
                              subtitle: Text(p.email ?? p.phone ?? ''),
                              trailing: widget.multiple
                                  ? Checkbox(value: isSelected, onChanged: (_) => _toggle(p))
                                  : null,
                              selected: isSelected,
                              onTap: () => _toggle(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        if (widget.multiple)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected.values.toList()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('إضافة'),
          ),
      ],
    );
  }
}
