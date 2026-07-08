import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rwad_admin_app/features/auth/presentation/login_screen.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );
  }

  testWidgets('يعرض أخطاء التحقق عند إرسال نموذج فارغ', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();

    expect(find.text('أدخل بريداً صحيحاً'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور'), findsOneWidget);
  });

  testWidgets('يرفض بريداً بدون علامة @', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();

    expect(find.text('أدخل بريداً صحيحاً'), findsOneWidget);
  });
}
