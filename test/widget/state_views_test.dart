import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/core/theme/app_theme.dart';
import 'package:stark_vms_frontend/shared/widgets/state_views.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('ErrorView shows the message and Retry calls back', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _wrap(
        ErrorView(
          message: 'Cannot reach the server.',
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.text('Cannot reach the server.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('error.retry')));
    expect(retries, 1);
  });

  testWidgets('AsyncValueView renders loading, empty, data and error states', (
    tester,
  ) async {
    Widget view(AsyncValue<List<String>> value) => _wrap(
      AsyncValueView<List<String>>(
        value: value,
        isEmpty: (items) => items.isEmpty,
        empty: const EmptyView(title: 'Nothing here'),
        onRetry: () {},
        data: (items) => Text(items.join(',')),
      ),
    );

    await tester.pumpWidget(view(const AsyncLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(view(const AsyncData([])));
    expect(find.text('Nothing here'), findsOneWidget);

    await tester.pumpWidget(view(const AsyncData(['DHK-1', 'DHK-2'])));
    expect(find.text('DHK-1,DHK-2'), findsOneWidget);

    await tester.pumpWidget(
      view(
        const AsyncError(
          ApiException(kind: ApiErrorKind.network, message: 'Offline'),
          StackTrace.empty,
        ),
      ),
    );
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byKey(const Key('error.retry')), findsOneWidget);
  });
}
