import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard_page.dart';
import 'jobs_page.dart';
import 'pathway_page.dart';
import 'profile_page.dart';
import 'applications_page.dart';
import '../services/navigation_service.dart';
import 'package:skillmatch/theme/app_colors.dart';

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
  late final List<Widget> _pages;

  static const _items = [
    _NavItem(
      label: 'Dashboard',
      outlinedIcon: Icons.dashboard_outlined,
      filledIcon: Icons.dashboard_rounded,
    ),
    _NavItem(
      label: 'Jobs',
      outlinedIcon: Icons.explore_outlined,
      filledIcon: Icons.explore_rounded,
    ),
    _NavItem(
      label: 'Pathway',
      outlinedIcon: Icons.alt_route_outlined,
      filledIcon: Icons.alt_route_rounded,
    ),
    _NavItem(
      label: 'Applied',
      outlinedIcon: Icons.business_center_outlined,
      filledIcon: Icons.business_center_rounded,
    ),
    _NavItem(
      label: 'Profile',
      outlinedIcon: Icons.person_outline_rounded,
      filledIcon: Icons.person_rounded,
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

  void _onTabSelected(int index) {
    HapticFeedback.selectionClick();
    AppNavigation.switchToIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppNavigation.currentTab,
      builder: (context, currentIndex, _) {
        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.borderSoft, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _NavButton(
                          item: _items[i],
                          selected: i == currentIndex,
                          onTap: () => _onTabSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoftBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? item.filledIcon : item.outlinedIcon,
                color: selected ? AppColors.primary : AppColors.textFaint,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: selected ? -0.2 : 0,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
