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
import '../../features/auth/presentation/change_password_dialog.dart';
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
                  groupAlignment: -0.85,
                  leading: const Padding(
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: _RailMark(),
                  ),
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

enum _UserMenuAction { changePassword, logout }

/// Initials plate, name and role chip; opens the user menu (every role):
/// Change password (v2.1, contract 7.3.4) and Log out.
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
            Container(
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
            Icon(Icons.arrow_drop_down, color: Brand.onNavyMuted),
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
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(destinations[index].path);
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
