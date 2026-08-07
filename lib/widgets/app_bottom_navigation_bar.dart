import 'package:flutter/material.dart';

import '../services/accessibility_scope.dart';
import '../utils/app_haptics.dart';
import 'shared/min_tap_target.dart' show kLargeTouchTargetSize;

/// The app's primary bottom navigation bar.
///
/// A custom Material 3 styled navigation bar: a floating, rounded-top
/// surface with a pill-shaped selection indicator that slides between
/// destinations, plus per-tab icon and label animations. Purely
/// presentational — it owns no app state and only reports taps via
/// [onDestinationSelected].
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  /// Index of the currently selected tab.
  final int selectedIndex;

  /// Called with the tapped tab's index.
  final ValueChanged<int> onDestinationSelected;

  static const List<_NavItemData> _items = [
    _NavItemData(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _NavItemData(
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center,
      label: 'Exercises',
    ),
    _NavItemData(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Routine',
    ),
    _NavItemData(
      icon: Icons.show_chart_outlined,
      selectedIcon: Icons.show_chart,
      label: 'Progress',
    ),
    _NavItemData(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  static const double _barHeight = 68;
  static const double _indicatorHeight = 40;
  static const double _indicatorWidth = 56;
  static const Duration _indicatorDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final indicatorDuration =
        reduceMotion ? Duration.zero : _indicatorDuration;

    return Material(
      color: colorScheme.surface,
      shadowColor: colorScheme.shadow,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: indicatorDuration,
                    curve: Curves.easeOutCubic,
                    top: (_barHeight - _indicatorHeight) / 2,
                    left:
                        itemWidth * selectedIndex +
                        (itemWidth - _indicatorWidth) / 2,
                    width: _indicatorWidth,
                    height: _indicatorHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          _indicatorHeight / 2,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (index) {
                      final selected = index == selectedIndex;
                      return SizedBox(
                        width: itemWidth,
                        child: _NavItem(
                          data: _items[index],
                          selected: selected,
                          activeColor: colorScheme.primary,
                          inactiveColor: colorScheme.onSurfaceVariant,
                          duration: indicatorDuration,
                          onTap: () {
                            if (!selected) {
                              AppHaptics.selection();
                            }
                            onDestinationSelected(index);
                          },
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Static icon/label configuration for a single tab.
class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A single animated tab: icon swap + scale, color tween, and an
/// emphasized label style when selected.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.duration = const Duration(milliseconds: 220),
  });

  final _NavItemData data;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  /// Reduce-motion aware duration for this item's own icon/label
  /// tweens, passed down from [AppBottomNavigationBar] so every
  /// animation in the bar snaps together when the setting is on.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? activeColor : inactiveColor;
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    // Column(mainAxisSize: min) below shrink-wraps to roughly 42-44px
    // (24px icon + 4px gap + a small label) — already just under the
    // accessible minimum even before considering this setting at all,
    // since Row's default crossAxisAlignment doesn't stretch children
    // to the Stack's full 68px bar height. Enforcing at least
    // kLargeTouchTargetSize closes that gap as a baseline correctness
    // fix; when the setting is on, using the bar's own full height
    // gives a clearly larger target rather than a marginal one.
    final minHeight = largeTargets
        ? AppBottomNavigationBar._barHeight
        : kLargeTouchTargetSize;

    return Semantics(
      selected: selected,
      button: true,
      label: data.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: activeColor.withValues(alpha: 0.06),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: duration,
                    builder: (context, animatedColor, _) {
                      return AnimatedScale(
                        scale: selected ? 1.0 : 0.9,
                        duration: duration,
                        curve: Curves.easeOutBack,
                        child: AnimatedSwitcher(
                          duration: duration,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: Icon(
                            selected ? data.selectedIcon : data.icon,
                            key: ValueKey<bool>(selected),
                            color: animatedColor,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOut,
                    style:
                        (textTheme.labelSmall ?? const TextStyle(fontSize: 11))
                            .copyWith(
                              color: color,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
