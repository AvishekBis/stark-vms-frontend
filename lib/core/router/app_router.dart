import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/vehicles/presentation/vehicle_detail_screen.dart';
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
///   dashboard.
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
  if (isPublic) {
    return target ?? AppRoutes.dashboard;
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

int? _vehicleId(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

Widget _vehicleScreen(GoRouterState state, Widget Function(int id) builder) {
  final id = _vehicleId(state);
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
            builder: (_, _) => const VehicleListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const VehicleFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => _vehicleScreen(
                  state,
                  (id) => VehicleDetailScreen(vehicleId: id),
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
