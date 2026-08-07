import 'package:flutter/material.dart';

import '../services/navigation_tab_controller.dart';
import '../services/navigation_tab_scope.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import 'exercises_screen.dart';
import 'home_screen.dart';
import 'progress/progress_screen.dart';
import 'routine_screen.dart';
import 'settings_screen.dart';

/// Root navigation shell for the app.
///
/// Hosts the five top-level tabs behind a Material 3 [NavigationBar]
/// (via [AppBottomNavigationBar]). An [IndexedStack] is used so each
/// tab keeps its own state — scroll position, form input, etc. —
/// when switching between tabs.
///
/// Which tab is selected lives in [NavigationTabController] (read via
/// [NavigationTabScope]), not local state here. That's what lets a
/// screen nested inside one tab — e.g. Home's "View Daily Exercises"
/// card, which switches to the Routine tab — request a tab change
/// directly, the same way tapping the bottom nav bar does, without
/// this screen needing to grow a bespoke callback for every such
/// case. This widget itself just listens and keeps [IndexedStack] in
/// sync; it doesn't need to be a [StatefulWidget] since it no longer
/// owns any state of its own.
class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  static const List<Widget> _tabs = [
    HomeScreen(),
    ExercisesScreen(),
    RoutineScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navigation = NavigationTabScope.of(context);
    final selectedIndex = navigation.current.index;

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: _tabs),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            navigation.switchTo(AppTab.values[index]),
      ),
    );
  }
}
