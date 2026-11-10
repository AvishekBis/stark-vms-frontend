import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/data/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'brand.dart';
import 'connecting_banner.dart';

/// One entry of the main navigation.
class _Destination {
  const _Destination(this.label, this.path, this.icon, this.selectedIcon);

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _destinations = [
  _Destination(
    'Dashboard',
    AppRoutes.dashboard,
    Icons.dashboard_outlined,
    Icons.dashboard,
  ),
  _Destination(
    'Vehicles',
    AppRoutes.vehicles,
    Icons.directions_car_outlined,
    Icons.directions_car,
  ),
];

/// Layout around every signed-in screen: top bar with user, role and
/// logout; NavigationRail on wide screens, Drawer on narrow ones.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Current URL path, used to highlight the active destination.
  final String location;
  final Widget child;

  int get _selectedIndex {
    final index = _destinations.indexWhere((d) => location.startsWith(d.path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isWide =
        MediaQuery.sizeOf(context).width >= ScreenSize.mediumMinWidth;
    final content = DecoratedBox(
      decoration: const BoxDecoration(gradient: AppDecorations.pageGradient),
      child: Column(
        children: [
          const ConnectingBanner(),
          Expanded(child: child),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stark Group VMS'),
        // The navy gradient of the brand, with the gold hairline under it.
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppDecorations.headerGradient,
            border: Border(
              bottom: BorderSide(color: AppPalette.gold, width: 2),
            ),
          ),
        ),
        actions: [
          if (user != null) _UserSummary(user: user, showName: isWide),
          IconButton(
            key: const Key('shell.logout'),
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      drawer: isWide ? null : _NavigationDrawer(selectedIndex: _selectedIndex),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.85,
                  leading: const Padding(
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: _RailMark(),
                  ),
                  onDestinationSelected: (index) =>
                      context.go(_destinations[index].path),
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}

/// A small gold diamond at the top of the rail: the brand mark, no text, so
/// it never repeats the title in the top bar.
class _RailMark extends StatelessWidget {
  const _RailMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: AppSpacing.md,
            height: AppSpacing.md,
            decoration: BoxDecoration(
              border: Border.all(color: AppPalette.gold, width: 2),
              borderRadius: BorderRadius.circular(AppSpacing.xs / 2),
            ),
          ),
        ),
        AppDecorations.goldRule(
          width: AppSpacing.lg,
          margin: const EdgeInsets.only(top: AppSpacing.md),
        ),
      ],
    );
  }
}

/// Initials plate, name and role chip in the top bar. (v1 has no user menu:
/// Log out is its own button next to this summary.)
class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.user, required this.showName});

  final User user;
  final bool showName;

  /// Up to two initials from the full name, for the avatar plate.
  String get _initials {
    final parts = user.fullName.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The initials repeat the name beside them, so screen readers skip
          // them.
          ExcludeSemantics(
            child: Container(
              width: AppSpacing.xl,
              height: AppSpacing.xl,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Brand.navyPlate,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.gold, width: 1.2),
              ),
              child: Text(
                _initials,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppPalette.gold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (showName) ...[
            Text(
              user.fullName,
              key: const Key('shell.userName'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Brand.onNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Chip(
            key: const Key('shell.roleChip'),
            label: Text(user.role.label),
            visualDensity: VisualDensity.compact,
            backgroundColor: theme.colorScheme.secondary,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            side: BorderSide.none,
          ),
        ],
      ),
    );
  }
}

class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(_destinations[index].path);
      },
      children: [
        // The navy header makes the drawer part of the same family as the
        // top bar and the page banners.
        Container(
          decoration: AppDecorations.headerBanner(
            borderRadius: BorderRadius.zero,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stark Group VMS',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Brand.onNavy,
                ),
              ),
              AppDecorations.goldRule(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final destination in _destinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
