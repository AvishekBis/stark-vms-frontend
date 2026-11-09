import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/documents/presentation/expiring_documents_screen.dart';
import '../../features/drivers/presentation/driver_detail_screen.dart';
import '../../features/drivers/presentation/driver_form_screen.dart';
import '../../features/drivers/presentation/drivers_list_screen.dart';
import '../../features/users/presentation/user_form_screen.dart';
import '../../features/users/presentation/users_list_screen.dart';
import '../../features/vehicles/data/vehicle_enums.dart';
import '../../features/vehicles/presentation/vehicle_detail_screen.dart';
import '../../features/vehicles/presentation/vehicle_detail_tab.dart';
import '../../features/vehicles/presentation/vehicle_form_screen.dart';
import '../../features/vehicles/presentation/vehicle_list_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/splash_screen.dart';
import '../../shared/widgets/state_views.dart';
import 'app_routes.dart';

/// Decides where a navigation may go, based on the auth state.
///
/// * restoring a session → `/splash` (remembering the target),
/// * signed out → `/login` (remembering the target),
/// * signed in on `/login` or `/splash` → the remembered target or the
///   dashboard,
/// * v2.1: a non-ADMIN on `/users…` → the dashboard (the backend 403 is the
///   real control; this only keeps STAFF off pages that would fail).
String? authRedirect(AsyncValue<AuthState> auth, Uri uri) {
  final path = uri.path;
  final isPublic = path == AppRoutes.login || path == AppRoutes.splash;
  final target = isPublic
      ? _safeTarget(uri.queryParameters[AppRoutes.fromParameter])
      : uri.toString();

  if (auth.isLoading && !auth.hasValue) {
    return path == AppRoutes.splash
        ? null
        : _withTarget(AppRoutes.splash, target);
  }

  final isSignedIn = auth.valueOrNull?.isAuthenticated ?? false;
  if (!isSignedIn) {
    return path == AppRoutes.login
        ? null
        : _withTarget(AppRoutes.login, target);
  }
  final isAdmin = auth.valueOrNull?.user?.isAdmin ?? false;
  if (isPublic) {
    final next = target ?? AppRoutes.dashboard;
    return !isAdmin && AppRoutes.isAdminOnly(Uri.parse(next).path)
        ? AppRoutes.dashboard
        : next;
  }
  if (!isAdmin && AppRoutes.isAdminOnly(path)) {
    return AppRoutes.dashboard;
  }
  return null;
}

String _withTarget(String path, String? target) {
  if (target == null || target == AppRoutes.dashboard || target == '/') {
    return path;
  }
  return Uri(
    path: path,
    queryParameters: {AppRoutes.fromParameter: target},
  ).toString();
}

/// Only in-app paths are accepted as redirect targets.
String? _safeTarget(String? target) {
  if (target == null || !target.startsWith('/') || target.startsWith('//')) {
    return null;
  }
  if (target.startsWith(AppRoutes.login) ||
      target.startsWith(AppRoutes.splash)) {
    return null;
  }
  return target;
}

int? _pathId(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

Widget _vehicleScreen(GoRouterState state, Widget Function(int id) builder) {
  final id = _pathId(state);
  if (id == null) {
    return const Scaffold(
      body: ErrorView(
        title: 'Vehicle not found',
        message: 'This vehicle address is not valid.',
      ),
    );
  }
  return builder(id);
}

Widget _userScreen(GoRouterState state) {
  final id = _pathId(state);
  if (id == null) {
    return const Scaffold(
      body: ErrorView(
        title: 'User not found',
        message: 'This user address is not valid.',
      ),
    );
  }
  return UserFormScreen(userId: id);
}

Widget _driverScreen(GoRouterState state, Widget Function(int id) builder) {
  final id = _pathId(state);
  if (id == null) {
    return const Scaffold(
      body: ErrorView(
        title: 'Driver not found',
        message: 'This driver address is not valid.',
      ),
    );
  }
  return builder(id);
}

/// `/vehicles?status=MAINTENANCE&type=BUS` → a filtered list.
Widget _vehicleList(GoRouterState state) {
  final parameters = state.uri.queryParameters;
  final hasFilters =
      parameters.containsKey(AppRoutes.statusParameter) ||
      parameters.containsKey(AppRoutes.typeParameter);
  return VehicleListScreen(
    hasRouteFilters: hasFilters,
    routeStatus: VehicleStatus.tryParse(parameters[AppRoutes.statusParameter]),
    routeType: VehicleType.tryParse(parameters[AppRoutes.typeParameter]),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier<AsyncValue<AuthState>>(
    ref.read(authControllerProvider),
  );
  ref.listen<AsyncValue<AuthState>>(
    authControllerProvider,
    (_, next) => authState.value = next,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: authState,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => authRedirect(authState.value, state.uri),
    onException: (context, state, router) => router.go(AppRoutes.dashboard),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.dashboard),
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.vehicles,
            builder: (_, state) => _vehicleList(state),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const VehicleFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => _vehicleScreen(
                  state,
                  (id) => VehicleDetailScreen(
                    vehicleId: id,
                    initialTab: VehicleDetailTab.fromQuery(
                      state.uri.queryParameters[AppRoutes.tabParameter],
                    ),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => _vehicleScreen(
                      state,
                      (id) => VehicleFormScreen(vehicleId: id),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.drivers,
            builder: (_, _) => const DriversListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const DriverFormScreen()),
              GoRoute(
                path: ':id',
                builder: (_, state) => _driverScreen(
                  state,
                  (id) => DriverDetailScreen(driverId: id),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => _driverScreen(
                      state,
                      (id) => DriverFormScreen(driverId: id),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.users,
            builder: (_, _) => const UsersListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const UserFormScreen()),
              GoRoute(
                path: ':id/edit',
                builder: (_, state) => _userScreen(state),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.expiringDocuments,
            builder: (_, state) => ExpiringDocumentsScreen(
              initialWithinDays: int.tryParse(
                state.uri.queryParameters[AppRoutes.withinDaysParameter] ?? '',
              ),
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    authState.dispose();
  });
  return router;
});
