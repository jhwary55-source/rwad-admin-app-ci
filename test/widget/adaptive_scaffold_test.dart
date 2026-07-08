import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rwad_admin_app/core/widgets/adaptive_scaffold.dart';

const _items = [
  NavItem(label: 'الرئيسية', icon: Icons.home_outlined, selectedIcon: Icons.home, path: '/a'),
  NavItem(label: 'الثانية', icon: Icons.star_outline, selectedIcon: Icons.star, path: '/b'),
];

Widget _buildApp() {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: AdaptiveScaffold(
        currentIndex: 0,
        items: _items,
        title: 'اختبار',
        onDestinationSelected: (_) {},
        child: const SizedBox(),
      ),
    ),
  );
}

void main() {
  testWidgets('يستخدم NavigationRail على الشاشات الواسعة', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildApp());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('يستخدم NavigationBar السفلي على الشاشات الضيقة', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
