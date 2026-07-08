import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rwad_admin_app/features/auth/presentation/register_screen.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );
  }

  testWidgets('يعرض أخطاء التحقق عند إرسال نموذج فارغ', (tester) async {
    await tester.pumpWidget(wrap(const RegisterScreen()));

    await tester.tap(find.text('إنشاء الحساب'));
    await tester.pump();

    expect(find.text('أدخل اسمك الكامل'), findsOneWidget);
    expect(find.text('أدخل رقم جوال سعودي صحيح'), findsOneWidget);
    expect(find.text('أدخل بريداً صحيحاً'), findsOneWidget);
    expect(find.text('كلمة المرور 6 أحرف على الأقل'), findsOneWidget);
  });

  testWidgets('يرفض عدم تطابق كلمتي المرور', (tester) async {
    await tester.pumpWidget(wrap(const RegisterScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'الاسم الكامل'), 'محمد أحمد');
    await tester.enterText(find.widgetWithText(TextFormField, 'رقم الجوال'), '0512345678');
    await tester.enterText(find.widgetWithText(TextFormField, 'البريد الإلكتروني'), 'test@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'كلمة المرور'), 'password1');
    await tester.enterText(find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'), 'password2');
    await tester.tap(find.text('إنشاء الحساب'));
    await tester.pump();

    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
  });
}
