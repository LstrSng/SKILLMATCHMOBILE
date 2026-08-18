import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'jobs_page.dart';
import 'pathway_page.dart';
import 'profile_page.dart';
import 'applications_page.dart';
import '../theme/app_colors.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });

  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  static const _items = [
    _NavItem(
      label: 'Dashboard',
      outlinedIcon: Icons.dashboard_outlined,
      filledIcon: Icons.dashboard,
    ),
    _NavItem(
      label: 'Jobs',
      outlinedIcon: Icons.search_outlined,
      filledIcon: Icons.search,
    ),
    _NavItem(
      label: 'Pathway',
      outlinedIcon: Icons.route_outlined,
      filledIcon: Icons.route,
    ),
    _NavItem(
      label: 'Applied',
      outlinedIcon: Icons.business_center_outlined,
      filledIcon: Icons.business_center,
    ),
    _NavItem(
      label: 'Profile',
      outlinedIcon: Icons.person_outline,
      filledIcon: Icons.person,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardPage(),
      const JobsPage(),
      const PathwayPage(),
      const ApplicationsPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps every tab's widget (and its State — selected
      // role, scroll position, loaded data, etc.) alive in the tree even
      // while hidden, instead of disposing and rebuilding it from scratch
      // every time you switch tabs.
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SafeArea(
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: _items[i],
                        selected: i == _currentIndex,
                        onTap: () => setState(() => _currentIndex = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textFaint;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.filledIcon : item.outlinedIcon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
