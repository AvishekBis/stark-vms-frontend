import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/data/auth_models.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/change_password_dialog.dart';
import 'connecting_banner.dart';

/// One entry of the main navigation.
class _Destination {
  const _Destination(this.label, this.path, this.icon, this.selectedIcon);

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _commonDestinations = [
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
  _Destination('Drivers', AppRoutes.drivers, Icons.badge_outlined, Icons.badge),
  _Destination(
    'Expiring docs',
    AppRoutes.expiringDocuments,
    Icons.event_note_outlined,
    Icons.event_note,
  ),
];

/// v2.1: user management, ADMIN only (contract 7.7).
const _Destination _usersDestination = _Destination(
  'Users',
  AppRoutes.users,
  Icons.manage_accounts_outlined,
  Icons.manage_accounts,
);

/// The navigation entries [user] may see.
List<_Destination> _destinationsFor(User? user) => [
  ..._commonDestinations,
  if (user?.isAdmin ?? false) _usersDestination,
];

/// Layout around every signed-in screen: top bar with the user menu (name,
/// role, Change password, Log out); NavigationRail on wide screens, Drawer
/// on narrow ones. "Users" is only shown to ADMIN.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Current URL path, used to highlight the active destination.
  final String location;
  final Widget child;

  int _selectedIndex(List<_Destination> destinations) {
    final index = destinations.indexWhere((d) => location.startsWith(d.path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final destinations = _destinationsFor(user);
    final selectedIndex = _selectedIndex(destinations);
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
          if (user != null)
            _UserMenu(
              user: user,
              showName: isWide,
              onChangePassword: () => showChangePasswordDialog(context),
              onLogout: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      drawer: isWide
          ? null
          : _NavigationDrawer(
              destinations: destinations,
              selectedIndex: selectedIndex,
            ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) =>
                      context.go(destinations[index].path),
                  destinations: [
                    for (final destination in destinations)
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

enum _UserMenuAction { changePassword, logout }

/// Name and role chip; opens the user menu (every role): Change password
/// (v2.1, contract 7.3.4) and Log out.
class _UserMenu extends StatelessWidget {
  const _UserMenu({
    required this.user,
    required this.showName,
    required this.onChangePassword,
    required this.onLogout,
  });

  final User user;
  final bool showName;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_UserMenuAction>(
      key: const Key('shell.userMenu'),
      tooltip: 'Account',
      onSelected: (action) => switch (action) {
        _UserMenuAction.changePassword => onChangePassword(),
        _UserMenuAction.logout => onLogout(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(user.email, style: theme.textTheme.bodySmall),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          key: Key('shell.changePassword'),
          value: _UserMenuAction.changePassword,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.password),
            title: Text('Change password'),
          ),
        ),
        const PopupMenuItem(
          key: Key('shell.logout'),
          value: _UserMenuAction.logout,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Log out'),
          ),
        ),
      ],
      child: Padding(
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
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}

class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer({
    required this.destinations,
    required this.selectedIndex,
  });

  final List<_Destination> destinations;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(destinations[index].path);
      },
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Stark Group VMS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final destination in destinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
