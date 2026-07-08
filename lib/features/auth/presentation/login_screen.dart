import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      ref.invalidate(currentProfileProvider);
    } on AppAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'بيانات الدخول غير صحيحة أو حدث خطأ في الاتصال.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ModernCard(
              padding: const EdgeInsets.all(28),
              child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppGradients.tealToDark,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: const Icon(Icons.balance, color: AppColors.goldLight, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'رواد الأنظمة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                      const Text(
                        'بوابة العملاء والموظفين',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'أدخل بريداً صحيحاً' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
                        onFieldSubmitted: (_) => _submit(),
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
                      Center(
                        child: GradientButton(
                          label: 'تسجيل الدخول',
                          icon: Icons.login,
                          loading: _loading,
                          onPressed: _loading ? null : _submit,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('ليس لديك حساب؟ سجّل كعميل جديد'),
                      ),
                    ],
                  ),
                ),
            ),
          ),
        ),
      ),
    );
  }
}
