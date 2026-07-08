import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/push_sender.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/profile.dart';
import '../../auth/application/auth_providers.dart';
import '../application/ai_intake_providers.dart';
import '../data/ai_intake_repository.dart';

const _kConsultationCategories = [
  'أخرى (لأي موضوع لا يندرج تحت ما سبق)',
  'التمثيل القضائي وحل المنازعات',
  'الخدمات الاستشارية',
  'العقود والاتفاقيات',
  'حقوق الملكية الفكرية',
  'قطاع الأعمال والشركات',
  'الخدمات المتعلقة بالعقارات',
  'قضايا الأحوال الشخصية',
  'القضايا الجنائية',
  'القضايا العمالية',
  'نزاعات القانون الدولي والتحكيم',
  'قضايا القانون البحري والجوي',
  'الاستثمار الأجنبي',
];

class _Turn {
  final String role; // user | assistant
  final String content;
  const _Turn(this.role, this.content);
}

/// "طلب استشارة جديدة" — نفس تدفق chat.html (الالتقاط الذكي) لكن بدون
/// نموذج جمع الاسم/الجوال/البريد لأن العميل مسجّل دخول بالفعل، وباستخدام
/// دالة ai-intake الخلفية بدل مناداة Anthropic مباشرة من التطبيق.
///
/// أول خطوة الآن: اختيار نوع الاستشارة يدويًا (نفس تصنيفات consultation.html)
/// قبل بدء الدردشة مع المساعد الذكي.
class AiIntakeScreen extends ConsumerStatefulWidget {
  const AiIntakeScreen({super.key});

  @override
  ConsumerState<AiIntakeScreen> createState() => _AiIntakeScreenState();
}

class _AiIntakeScreenState extends ConsumerState<AiIntakeScreen> {
  final _turns = <_Turn>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _done = false;
  String? _error;
  String? _category;

  void _selectCategory(String category) {
    setState(() => _category = category);
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  void _greet() {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final name = profile?.name ?? '';
    setState(() {
      _turns.add(_Turn(
        'assistant',
        'مرحباً $name 👋\nأنا المحامي الذكي من شركة رواد الأنظمة. تفضّل باشرح لي قضيتك أو استفسارك القانوني باختصار، وسأجمع التفاصيل ليتواصل معك المختص.',
      ));
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _conversationText => _turns
      .where((t) => t.content.isNotEmpty)
      .map((t) => '${t.role == 'user' ? 'العميل' : 'المحامي الذكي'}: ${t.content}')
      .join('\n');

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending || _done) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() {
      _turns.add(_Turn('user', text));
      _inputCtrl.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final reply = await ref.read(aiIntakeRepositoryProvider).sendChat(
            clientName: profile.name,
            messages: _turns.map((t) => {'role': t.role, 'content': t.content}).toList(),
          );

      if (reply.contains('[INTAKE_COMPLETE]')) {
        final clean = reply.replaceAll('[INTAKE_COMPLETE]', '').trim();
        setState(() {
          if (clean.isNotEmpty) _turns.add(_Turn('assistant', clean));
        });
        await _finalize(profile);
      } else {
        setState(() => _turns.add(_Turn('assistant', reply)));
      }
    } on AiIntakeException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _finalize(Profile profile) async {
    setState(() => _sending = true);
    try {
      final repo = ref.read(aiIntakeRepositoryProvider);
      final summary = await repo.summarize(_conversationText);
      final id = await repo.createConsultation(
        clientId: profile.id,
        clientName: profile.name,
        clientPhone: profile.phone,
        clientEmail: profile.email,
        caseSummary: summary,
        fullConversation: _conversationText,
        category: _category,
      );
      setState(() => _done = true);
      ref.read(pushSenderProvider).send(
            toStaff: true,
            title: 'استشارة جديدة ⚖️',
            message: '${profile.name}${_category != null ? ' — $_category' : ''}',
            imageUrl: profile.avatarUrl,
            data: {'type': 'consultation', 'id': id},
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ تم إرسال طلب استشارتك بنجاح'), backgroundColor: AppColors.success));
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) context.pushReplacement('/consultations/$id');
        });
      }
    } catch (_) {
      setState(() => _error = 'تم جمع طلبك لكن تعذّر حفظه، حاول لاحقًا أو تواصل معنا مباشرة.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_category == null) {
      return Scaffold(
        appBar: const GradientAppBar(title: 'طلب استشارة جديدة'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('اختر نوع الاستشارة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('لتوجيه طلبك للمختص المناسب مباشرة', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            for (int i = 0; i < _kConsultationCategories.length; i++)
              FadeSlideIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ModernCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _selectCategory(_kConsultationCategories[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(child: Text(_kConsultationCategories[i], style: const TextStyle(fontWeight: FontWeight.w600))),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: const GradientAppBar(title: 'المحامي الذكي'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _turns.length,
              itemBuilder: (context, i) => _Bubble(turn: _turns[i]),
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppColors.danger.withValues(alpha: 0.08),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          if (_done)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 40),
                  SizedBox(height: 8),
                  Text('تم استلام طلبك بنجاح، سيتواصل معك أحد محامينا قريبًا.', textAlign: TextAlign.center),
                ],
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        enabled: !_sending,
                        decoration: const InputDecoration(hintText: 'اكتب رسالتك...'),
                        onSubmitted: (_) => _send(),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sending
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Turn turn;
  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: const Color(0xFFDDE8EC)),
        ),
        child: Text(turn.content, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }
}
