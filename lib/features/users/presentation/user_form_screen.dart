import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/stale_version_dialog.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/user_account.dart';
import 'user_providers.dart';

/// Create (`/users/new`) and edit (`/users/:id/edit`) a user account
/// (v2.1, ADMIN only, contract 7.3.3). The e-mail is read-only on edit and
/// the password is only asked on create.
class UserFormScreen extends ConsumerWidget {
  const UserFormScreen({super.key, this.userId});

  /// `null` creates a new user; otherwise the user to edit.
  final int? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null) {
      return const Scaffold(body: _UserFormView(initial: null));
    }
    return Scaffold(
      body: AsyncValueView<UserAccount>(
        value: ref.watch(userDetailProvider(id)),
        onRetry: () => ref.invalidate(userDetailProvider(id)),
        loadingMessage: 'Loading user…',
        // Keyed by version too, so a reload refills the form.
        data: (user) => _UserFormView(
          key: ValueKey((user.id, user.version)),
          initial: user,
        ),
      ),
    );
  }
}

class _UserFormView extends ConsumerStatefulWidget {
  const _UserFormView({super.key, required this.initial});

  final UserAccount? initial;

  @override
  ConsumerState<_UserFormView> createState() => _UserFormViewState();
}

class _UserFormViewState extends ConsumerState<_UserFormView> {
  static const String selfModificationHint =
      'You cannot disable your own account or remove your own ADMIN role.';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _name;
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  late UserRole _role;
  late bool _enabled;
  bool _obscure = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final user = widget.initial;
    _email = TextEditingController(text: user?.email ?? '');
    _name = TextEditingController(text: user?.fullName ?? '');
    _role = user?.role ?? UserRole.staff;
    _enabled = user?.enabled ?? true;
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final controller = ref.read(userFormControllerProvider.notifier);
    final initial = widget.initial;
    final UserAccount? saved;
    if (initial == null) {
      saved = await controller.create(
        CreateUserInput(
          email: _email.text,
          fullName: _name.text,
          role: _role,
          password: _password.text,
        ),
      );
    } else {
      if (initial.enabled && !_enabled && !await _confirmDisable(initial)) {
        return;
      }
      saved = await controller.update(
        initial,
        UpdateUserInput(fullName: _name.text, role: _role, enabled: _enabled),
      );
    }
    if (!mounted) {
      return;
    }
    if (saved != null) {
      AppFeedback.success(
        context,
        _isEdit ? 'User ${saved.email} updated.' : 'User ${saved.email} added.',
      );
      context.go(AppRoutes.users);
      return;
    }
    final failure = ref.read(userFormControllerProvider);
    final staleMessage = failure.staleVersionMessage;
    if (staleMessage != null) {
      controller.clearStaleVersion();
      await _offerReload(staleMessage);
      return;
    }
    final message = failure.errorMessage;
    if (message != null) {
      AppFeedback.error(context, message);
      controller.clearErrorMessage();
    }
  }

  /// Disabling is destructive for that user: confirm first.
  Future<bool> _confirmDisable(UserAccount user) {
    return ConfirmDialog.show(
      context,
      title: 'Disable ${user.email}?',
      message:
          '${user.displayName} will no longer be able to log in, and their '
          'open sessions end on their next request. You can enable the '
          'account again later.',
      confirmLabel: 'Disable user',
      destructive: true,
    );
  }

  /// 409 stale-version (ADR 0023): Reload refetches the user and rebuilds
  /// the form from it; Cancel keeps the edits.
  Future<void> _offerReload(String message) async {
    final initial = widget.initial;
    final reload = await StaleVersionDialog.show(context, message: message);
    if (!reload || !mounted || initial == null) {
      return;
    }
    AppFeedback.success(context, StaleVersionDialog.reloadedMessage);
    ref.invalidate(userDetailProvider(initial.id));
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(userFormControllerProvider);
    final controller = ref.read(userFormControllerProvider.notifier);
    final initial = widget.initial;
    final isSelf =
        initial != null && initial.id == ref.watch(currentUserProvider)?.id;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEdit ? 'Edit user' : 'Add user',
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Fields marked * are required.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const Key('userForm.email'),
                      controller: _email,
                      readOnly: _isEdit,
                      enabled: !_isEdit,
                      autofocus: !_isEdit,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _isEdit ? 'E-mail' : 'E-mail *',
                        helperText: _isEdit
                            ? 'The e-mail cannot be changed.'
                            : 'Used to log in; stored in lower case.',
                        errorText: formState.errorFor('email'),
                        errorMaxLines: 2,
                      ),
                      validator: _isEdit ? null : UserValidators.email,
                      onChanged: (_) => controller.clearFieldError('email'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('userForm.fullName'),
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full name *',
                        errorText: formState.errorFor('fullName'),
                      ),
                      validator: UserValidators.fullName,
                      onChanged: (_) => controller.clearFieldError('fullName'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<UserRole>(
                      key: const Key('userForm.role'),
                      initialValue: _role,
                      decoration: InputDecoration(
                        labelText: 'Role *',
                        errorText: formState.errorFor('role'),
                        helperText: isSelf ? selfModificationHint : null,
                        helperMaxLines: 2,
                      ),
                      items: [
                        for (final role in UserRole.values)
                          DropdownMenuItem(
                            value: role,
                            child: Text(role.label),
                          ),
                      ],
                      onChanged: isSelf
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _role = value);
                                controller.clearFieldError('role');
                              }
                            },
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        key: const Key('userForm.enabled'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Account enabled'),
                        subtitle: Text(
                          isSelf
                              ? selfModificationHint
                              : _enabled
                              ? 'The user can log in.'
                              : 'The user cannot log in.',
                        ),
                        value: _enabled,
                        onChanged: isSelf
                            ? null
                            : (value) {
                                setState(() => _enabled = value);
                                controller.clearFieldError('enabled');
                              },
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('userForm.password'),
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          helperText:
                              'At least ${UserValidators.passwordMinLength} '
                              'characters. Tell the user and ask them to '
                              'change it.',
                          helperMaxLines: 2,
                          errorText: formState.errorFor('password'),
                          errorMaxLines: 2,
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: UserValidators.newPassword,
                        onChanged: (_) =>
                            controller.clearFieldError('password'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('userForm.confirmPassword'),
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Repeat password *',
                        ),
                        validator: (value) => UserValidators.confirmPassword(
                          value,
                          _password.text,
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton(
                          key: const Key('userForm.cancel'),
                          onPressed: formState.isSubmitting
                              ? null
                              : () => context.go(AppRoutes.users),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          key: const Key('userForm.save'),
                          onPressed: formState.isSubmitting ? null : _submit,
                          icon: formState.isSubmitting
                              ? const SizedBox.square(
                                  dimension: AppSpacing.md,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_isEdit ? 'Save changes' : 'Add user'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
