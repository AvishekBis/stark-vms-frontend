import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stark_vms_frontend/core/theme/app_theme.dart';

/// Pumps [screen] inside the real theme, a ProviderScope with [overrides]
/// and a minimal router (so `context.go` works), at a given window size.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    errorBuilder: (_, state) =>
        Scaffold(body: Text('Navigated to ${state.uri}')),
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
