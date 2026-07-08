import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;

  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });
}

/// هيكل تنقّل متجاوب: قائمة جانبية دائمة على الشاشات الواسعة (سطح المكتب/الأجهزة
/// اللوحية)، وشريط سفلي + قائمة منسدلة على شاشات الجوال الضيقة.
class AdaptiveScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final List<NavItem> items;
  final ValueChanged<int> onDestinationSelected;
  final String title;
  final List<Widget>? actions;

  const AdaptiveScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.items,
    required this.onDestinationSelected,
    required this.title,
    this.actions,
  });

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.gold.withValues(alpha: 0.18),
              destinations: items
                  .map((e) => NavigationRailDestination(
                        icon: Icon(e.icon),
                        selectedIcon: Icon(e.selectedIcon),
                        label: Text(e.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  GradientAppBar(title: title, actions: actions, automaticallyImplyLeading: false),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // شاشات ضيقة: أول 4 عناصر بشريط سفلي، والباقي في قائمة "المزيد".
    const maxBottomItems = 4;
    final bottomItems = items.length > maxBottomItems ? items.sublist(0, maxBottomItems - 1) : items;
    final overflowItems = items.length > maxBottomItems ? items.sublist(maxBottomItems - 1) : <NavItem>[];

    final showingOverflow = overflowItems.isNotEmpty && currentIndex >= bottomItems.length;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: GradientAppBar(title: title, actions: actions, automaticallyImplyLeading: false),
      drawer: overflowItems.isNotEmpty
          ? Drawer(
              child: SafeArea(
                child: ListView(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      ListTile(
                        leading: Icon(i == currentIndex ? items[i].selectedIcon : items[i].icon),
                        title: Text(items[i].label),
                        selected: i == currentIndex,
                        onTap: () {
                          Navigator.of(context).pop();
                          onDestinationSelected(i);
                        },
                      ),
                  ],
                ),
              ),
            )
          : null,
      body: child,
      bottomNavigationBar: NavigationBar(
        indicatorColor: AppColors.gold.withValues(alpha: 0.18),
        selectedIndex: showingOverflow ? bottomItems.length : currentIndex.clamp(0, bottomItems.length),
        onDestinationSelected: (i) {
          if (i == bottomItems.length && overflowItems.isNotEmpty) {
            scaffoldKey.currentState?.openDrawer();
            return;
          }
          onDestinationSelected(i);
        },
        destinations: [
          for (final item in bottomItems)
            NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label),
          if (overflowItems.isNotEmpty)
            const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'المزيد'),
        ],
      ),
    );
  }
}
