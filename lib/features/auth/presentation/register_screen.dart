import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../application/auth_providers.dart';

/// تسجيل عميل جديد — بنفس حقول register.html بالضبط. لا يوجد تسجيل دخول
/// تلقائي بعد الإرسال لأن المشروع يشترط تأكيد البريد الإلكتروني أولاً.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      setState(() => _error = 'تعذّر إنشاء الحساب. قد يكون البريد مستخدمًا مسبقًا.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'إنشاء حساب جديد'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ModernCard(
              padding: const EdgeInsets.all(28),
              child: _done ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 48),
        const SizedBox(height: 16),
        const Text(
          'تم إنشاء حسابك!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'تحقق من بريدك الإلكتروني وانقر رابط التأكيد، ثم عد وسجّل الدخول من هنا.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: 'العودة لتسجيل الدخول',
          icon: Icons.login,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().length < 2) ? 'أدخل اسمك الكامل' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رقم الجوال', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\s'), '');
              return RegExp(r'^0?5\d{8}$|^\+?9665\d{8}$').hasMatch(digits) ? null : 'أدخل رقم جوال سعودي صحيح';
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) => (v == null || !v.contains('@')) ? 'أدخل بريداً صحيحاً' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور 6 أحرف على الأقل' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password2Ctrl,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => (v != _passwordCtrl.text) ? 'كلمتا المرور غير متطابقتين' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 20),
          GradientButton(
            label: 'إنشاء الحساب',
            icon: Icons.person_add_alt_1,
            loading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
