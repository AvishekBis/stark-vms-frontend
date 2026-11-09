import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/page_response.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/data_table_frame.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/sort_menu.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/user_account.dart';
import '../data/user_query.dart';
import 'reset_password_dialog.dart';
import 'user_providers.dart';
import 'widgets/user_widgets.dart';

/// Users list (v2.1, ADMIN only, contract 7.7): debounced server search,
/// role and enabled filters, sort, pagination, cards / compact table /
/// full table by width.
class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
  late final TextEditingController _searchController;
  final Debouncer _searchDebouncer = Debouncer(delay: AppConfig.searchDebounce);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(userQueryProvider).search,
    );
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebouncer.run(
      () => ref.read(userQueryProvider.notifier).setSearch(value),
    );
  }

  void _onSearchSubmitted(String value) {
    _searchDebouncer.cancel();
    ref.read(userQueryProvider.notifier).setSearch(value);
  }

  void _clearSearchAndFilters() {
    _searchDebouncer.cancel();
    _searchController.clear();
    ref.read(userQueryProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final listValue = ref.watch(userListProvider);
    final query = ref.watch(userQueryProvider);
    final queryController = ref.read(userQueryProvider.notifier);
    final screenSize = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);
    final isCompact = screenSize == ScreenSize.compact;

    return Scaffold(
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              key: const Key('users.addFab'),
              onPressed: () => context.go(AppRoutes.newUser),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add user'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('Users', style: Theme.of(context).textTheme.headlineSmall),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.searchMinWidth,
                        maxWidth: AppSpacing.searchMaxWidth,
                      ),
                      child: TextField(
                        key: const Key('users.search'),
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchSubmitted,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search e-mail or name',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, _) => value.text.isEmpty
                                ? const SizedBox.shrink()
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _searchDebouncer.cancel();
                                      _searchController.clear();
                                      queryController.setSearch('');
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    FilterMenu<UserRole>(
                      key: const Key('users.roleFilter'),
                      label: 'Role',
                      options: UserRole.values,
                      optionLabel: (role) => role.label,
                      selected: query.role,
                      onChanged: queryController.setRole,
                    ),
                    FilterMenu<bool>(
                      key: const Key('users.enabledFilter'),
                      label: 'Status',
                      options: const [true, false],
                      optionLabel: UserEnabledBadge.labelFor,
                      selected: query.enabled,
                      onChanged: queryController.setEnabled,
                    ),
                    SortMenu<UserSortField>(
                      key: const Key('users.sortMenu'),
                      values: UserSortField.values,
                      label: (field) => field.label,
                      field: query.sortField,
                      direction: query.sortDirection,
                      onSelected: queryController.setSort,
                    ),
                    if (!isCompact)
                      FilledButton.icon(
                        key: const Key('users.add'),
                        onPressed: () => context.go(AppRoutes.newUser),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add user'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.xs,
              child: listValue.isLoading && listValue.hasValue
                  ? const LinearProgressIndicator()
                  : null,
            ),
            Expanded(
              child: AsyncValueView<PageResponse<UserAccount>>(
                value: listValue,
                loadingMessage: 'Loading users…',
                onRetry: () => ref.invalidate(userListProvider),
                isEmpty: (page) => page.totalElements == 0 && page.isEmpty,
                empty: query.hasFilters
                    ? EmptyView(
                        icon: Icons.search_off,
                        title: 'No users match the search or filters',
                        action: OutlinedButton(
                          key: const Key('users.clearFilters'),
                          onPressed: _clearSearchAndFilters,
                          child: const Text('Clear search and filters'),
                        ),
                      )
                    : EmptyView(
                        icon: Icons.group_outlined,
                        title: 'No users yet',
                        action: FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.newUser),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Add user'),
                        ),
                      ),
                data: (page) => _UserResults(
                  page: page,
                  query: query,
                  screenSize: screenSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserResults extends ConsumerWidget {
  const _UserResults({
    required this.page,
    required this.query,
    required this.screenSize,
  });

  final PageResponse<UserAccount> page;
  final UserQuery query;
  final ScreenSize screenSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(userQueryProvider.notifier);
    final currentUserId = ref.watch(currentUserProvider)?.id;

    final Widget results;
    if (page.isEmpty) {
      results = const EmptyView(
        icon: Icons.find_in_page_outlined,
        title: 'No users on this page',
        message: 'Go back to the previous page.',
      );
    } else if (screenSize == ScreenSize.compact) {
      results = ListView.separated(
        itemCount: page.content.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final user = page.content[index];
          return _UserCard(user: user, isSelf: user.id == currentUserId);
        },
      );
    } else {
      results = _UserTable(
        users: page.content,
        query: query,
        isFull: screenSize == ScreenSize.expanded,
        currentUserId: currentUserId,
        onSort: controller.sortBy,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: results),
        PaginationBar(
          page: page.page,
          totalPages: page.totalPages,
          totalElements: page.totalElements,
          pageSize: query.size,
          pageSizeOptions: UserQuery.pageSizeOptions,
          itemLabel: page.totalElements == 1 ? 'user' : 'users',
          onPageChanged: controller.goToPage,
          onPageSizeChanged: controller.setPageSize,
        ),
        if (screenSize == ScreenSize.compact)
          const SizedBox(height: AppSpacing.xl * 2),
      ],
    );
  }
}

class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.users,
    required this.query,
    required this.isFull,
    required this.currentUserId,
    required this.onSort,
  });

  final List<UserAccount> users;
  final UserQuery query;
  final bool isFull;
  final int? currentUserId;
  final ValueChanged<UserSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final columns = <(String, UserSortField?)>[
      ('Name', UserSortField.fullName),
      ('E-mail', UserSortField.email),
      ('Role', null),
      ('Status', null),
      if (isFull) ('Added', UserSortField.createdAt),
      if (isFull) ('Added by', null),
      ('Actions', null),
    ];
    final sortIndex = columns.indexWhere((c) => c.$2 == query.sortField);

    return DataTableFrame(
      table: DataTable(
        key: const Key('users.table'),
        showCheckboxColumn: false,
        sortColumnIndex: sortIndex < 0 ? null : sortIndex,
        sortAscending: query.sortDirection == SortDirection.ascending,
        columns: [
          for (final (label, field) in columns)
            DataColumn(
              label: Text(label),
              onSort: field == null ? null : (_, _) => onSort(field),
            ),
        ],
        rows: [
          for (final user in users)
            DataRow(
              key: ValueKey('user.row.${user.id}'),
              onSelectChanged: (_) => context.go(AppRoutes.editUser(user.id)),
              cells: [
                DataCell(
                  Text(
                    user.id == currentUserId
                        ? '${user.displayName} (you)'
                        : user.displayName,
                  ),
                ),
                DataCell(Text(user.email)),
                DataCell(Text(user.role.label)),
                DataCell(UserEnabledBadge(enabled: user.enabled)),
                if (isFull) DataCell(Text(Formatters.date(user.createdAt))),
                if (isFull) DataCell(Text(user.createdBy ?? 'system')),
                DataCell(
                  _UserActions(user: user, isSelf: user.id == currentUserId),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isSelf});

  final UserAccount user;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: ValueKey('user.card.${user.id}'),
      child: InkWell(
        onTap: () => context.go(AppRoutes.editUser(user.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            0,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelf ? '${user.displayName} (you)' : user.displayName,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${user.email} · ${user.role.label}',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    UserEnabledBadge(enabled: user.enabled),
                  ],
                ),
              ),
              _UserActions(user: user, isSelf: isSelf),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit, and "Reset password" for everyone except the signed-in admin
/// (who uses "Change password" in the user menu instead).
class _UserActions extends StatelessWidget {
  const _UserActions({required this.user, required this.isSelf});

  final UserAccount user;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('user.edit.${user.id}'),
          tooltip: 'Edit',
          onPressed: () => context.go(AppRoutes.editUser(user.id)),
          icon: const Icon(Icons.edit_outlined),
        ),
        if (!isSelf)
          IconButton(
            key: ValueKey('user.resetPassword.${user.id}'),
            tooltip: 'Reset password',
            onPressed: () => showResetPasswordDialog(context, user: user),
            icon: const Icon(Icons.lock_reset),
          ),
      ],
    );
  }
}
