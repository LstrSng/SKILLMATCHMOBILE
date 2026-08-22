import 'package:flutter/material.dart';

/// Enum representing the primary tabs in the SkillMatch navigation bar.
enum AppTab {
  dashboard('Dashboard'),
  jobs('Jobs'),
  pathway('Pathway'),
  applied('Applied'),
  profile('Profile');

  final String label;
  const AppTab(this.label);
}

/// Global navigation controller for switching main tabs from anywhere in the app.
class AppNavigation {
  AppNavigation._();

  static final ValueNotifier<int> currentTab = ValueNotifier<int>(0);

  /// Switches to a specific tab by enum.
  static void switchTab(AppTab tab) {
    currentTab.value = tab.index;
  }

  /// Switches to a specific tab by index.
  static void switchToIndex(int index) {
    if (index >= 0 && index < AppTab.values.length) {
      currentTab.value = index;
    }
  }

  /// Returns the current active tab enum.
  static AppTab get activeTab => AppTab.values[currentTab.value];
}
