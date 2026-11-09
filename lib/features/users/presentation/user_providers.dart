import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/form_errors.dart';
import '../../../core/network/page_response.dart';
import '../../../core/utils/change_tracker.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/user_account.dart';
import '../data/user_query.dart';
import '../data/user_repository.dart';

/// Bumped after every user create / update / password reset.
final userChangesProvider = NotifierProvider<ChangeTracker, int>(
  ChangeTracker.new,
);

/// Page / size / sort / search / filters of the users list; survives
/// navigation, resets when another user logs in.
class UserQueryController extends Notifier<UserQuery> {
  @override
  UserQuery build() {
    ref.watch(currentUserProvider.select((user) => user?.id));
    return const UserQuery();
  }

  void setSearch(String search) {
    final trimmed = search.trim();
    if (trimmed != state.search) {
      state = state.copyWith(search: trimmed, page: 0);
    }
  }

  void setRole(UserRole? role) {
    if (role != state.role) {
      state = state.copyWith(role: role, page: 0);
    }
  }

  void setEnabled(bool? enabled) {
    if (enabled != state.enabled) {
      state = state.copyWith(enabled: enabled, page: 0);
    }
  }

  /// Search and both filters cleared; sort and page size kept.
  void clearFilters() {
    final next = state.copyWith(search: '', role: null, enabled: null, page: 0);
    if (next != state) {
      state = next;
    }
  }

  void sortBy(UserSortField field) {
    state = state.sortField == field
        ? state.copyWith(sortDirection: state.sortDirection.reversed, page: 0)
        : state.copyWith(
            sortField: field,
            sortDirection: SortDirection.ascending,
            page: 0,
          );
  }

  void setSort(UserSortField field, SortDirection direction) {
    state = state.copyWith(sortField: field, sortDirection: direction, page: 0);
  }

  void goToPage(int page) {
    if (page >= 0 && page != state.page) {
      state = state.copyWith(page: page);
    }
  }

  void setPageSize(int size) {
    state = state.copyWith(size: size.clamp(1, UserQuery.maxPageSize), page: 0);
  }
}

final userQueryProvider = NotifierProvider<UserQueryController, UserQuery>(
  UserQueryController.new,
);

/// The current page of `GET /users`.
final userListProvider = FutureProvider.autoDispose<PageResponse<UserAccount>>((
  ref,
) {
  ref.watch(userChangesProvider);
  return ref.watch(userRepositoryProvider).list(ref.watch(userQueryProvider));
});

/// One user from `GET /users/{id}`. Refreshed explicitly after a save or a
/// "Reload" (it does not watch [userChangesProvider], so an open edit form
/// is not replaced behind the user's back).
final userDetailProvider = FutureProvider.autoDispose.family<UserAccount, int>((
  ref,
  id,
) {
  return ref.watch(userRepositoryProvider).get(id);
});

/// Creates and updates users, mapping server errors onto the form:
/// 409 `duplicate-email` → `email`; `self-modification` / `last-admin` →
/// the general message; 409 `stale-version` → [FormSubmitState.isStale].
class UserFormController extends AutoDisposeNotifier<FormSubmitState> {
  static const Map<String, String> duplicateTypes = {
    'duplicate-email': 'email',
  };

  @override
  FormSubmitState build() => const FormSubmitState();

  Future<UserAccount?> create(CreateUserInput input) {
    return _save(
      () => ref.read(userRepositoryProvider).create(input),
      fields: CreateUserInput.fieldNames,
    );
  }

  /// Sends the `version` [existing] was loaded with.
  Future<UserAccount?> update(UserAccount existing, UpdateUserInput input) {
    return _save(
      () => ref
          .read(userRepositoryProvider)
          .update(existing.id, input, version: existing.version),
      fields: UpdateUserInput.fieldNames,
    );
  }

  Future<UserAccount?> _save(
    Future<UserAccount> Function() request, {
    required Set<String> fields,
  }) async {
    if (state.isSubmitting) {
      return null;
    }
    state = const FormSubmitState(isSubmitting: true);
    try {
      final saved = await request();
      ref.read(userChangesProvider.notifier).markChanged();
      ref.invalidate(userDetailProvider(saved.id));
      state = const FormSubmitState();
      return saved;
    } on ApiException catch (error) {
      state = FormSubmitState.failed(
        error,
        fields: fields,
        typeToField: duplicateTypes,
      );
      return null;
    }
  }

  void clearFieldError(String field) {
    final errors = state.errors.withoutField(field);
    if (!identical(errors, state.errors)) {
      state = FormSubmitState(isSubmitting: state.isSubmitting, errors: errors);
    }
  }

  void clearStaleVersion() {
    if (state.isStale) {
      state = state.withoutStaleVersion();
    }
  }

  void clearErrorMessage() {
    if (state.errorMessage != null) {
      state = FormSubmitState(
        isSubmitting: state.isSubmitting,
        errors: state.errors.withoutMessage(),
      );
    }
  }
}

final userFormControllerProvider =
    NotifierProvider.autoDispose<UserFormController, FormSubmitState>(
      UserFormController.new,
    );

/// The admin "Reset password" dialog (`POST /users/{id}/password`).
class ResetPasswordController extends AutoDisposeNotifier<FormSubmitState> {
  static const Set<String> fieldNames = {'newPassword'};

  @override
  FormSubmitState build() => const FormSubmitState();

  /// `true` when the password was reset.
  Future<bool> submit(UserAccount user, String newPassword) async {
    if (state.isSubmitting) {
      return false;
    }
    state = const FormSubmitState(isSubmitting: true);
    try {
      await ref
          .read(userRepositoryProvider)
          .resetPassword(user.id, newPassword: newPassword);
      // The reset bumps the user's version (contract 7.2.4).
      ref.read(userChangesProvider.notifier).markChanged();
      ref.invalidate(userDetailProvider(user.id));
      state = const FormSubmitState();
      return true;
    } on ApiException catch (error) {
      state = FormSubmitState.failed(error, fields: fieldNames);
      return false;
    }
  }

  void clearFieldError(String field) {
    final errors = state.errors.withoutField(field);
    if (!identical(errors, state.errors)) {
      state = FormSubmitState(isSubmitting: state.isSubmitting, errors: errors);
    }
  }
}

final resetPasswordControllerProvider =
    NotifierProvider.autoDispose<ResetPasswordController, FormSubmitState>(
      ResetPasswordController.new,
    );
