import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/data/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
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
    final content = Column(
      children: [
        const ConnectingBanner(),
        Expanded(child: child),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stark Group VMS'),
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

class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.user, required this.showName});

  final User user;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showName) ...[
            Text(
              user.fullName,
              key: const Key('shell.userName'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
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
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(_destinations[index].path);
      },
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Stark Group VMS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
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
