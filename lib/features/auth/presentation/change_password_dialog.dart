import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/form_errors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/feedback.dart';
import 'auth_controller.dart';

/// Submits the own password change (contract 7.3.4) and keeps a wrong
/// current password (400, field `currentPassword`) under that field.
class ChangePasswordController extends AutoDisposeNotifier<FormSubmitState> {
  static const Set<String> fieldNames = {'currentPassword', 'newPassword'};

  @override
  FormSubmitState build() => const FormSubmitState();

  /// The outcome, or `null` when the server rejected the change.
  Future<PasswordChangeOutcome?> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.isSubmitting) {
      return null;
    }
    state = const FormSubmitState(isSubmitting: true);
    try {
      final outcome = await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = const FormSubmitState();
      return outcome;
    } on ApiException catch (error) {
      state = FormSubmitState.failed(error, fields: fieldNames);
      return null;
    }
  }

  void clearFieldError(String field) {
    final errors = state.errors.withoutField(field);
    if (!identical(errors, state.errors)) {
      state = FormSubmitState(isSubmitting: state.isSubmitting, errors: errors);
    }
  }
}

final changePasswordControllerProvider =
    NotifierProvider.autoDispose<ChangePasswordController, FormSubmitState>(
      ChangePasswordController.new,
    );

/// Opens "Change password" (user menu, every role).
Future<void> showChangePasswordDialog(BuildContext context) async {
  final outcome = await showDialog<PasswordChangeOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ChangePasswordDialog(),
  );
  if (outcome == PasswordChangeOutcome.reauthenticated && context.mounted) {
    AppFeedback.success(context, ChangePasswordDialog.successMessage);
  }
}

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  static const String successMessage = 'Password changed.';

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final outcome = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(currentPassword: _current.text, newPassword: _new.text);
    if (outcome != null && mounted) {
      Navigator.of(context).pop(outcome);
    }
  }

  String? _differentFromCurrent(String? value) {
    final policy = UserValidators.newPassword(value);
    if (policy != null) {
      return policy;
    }
    return value == _current.text
        ? 'The new password must be different from the current one.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);
    final controller = ref.read(changePasswordControllerProvider.notifier);
    final theme = Theme.of(context);
    final generalError = state.errorMessage;
    final visibilityToggle = IconButton(
      tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );

    return AlertDialog(
      key: const Key('changePassword.dialog'),
      title: const DialogTitle(icon: Icons.password, title: 'Change password'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.dialogMaxWidth),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('changePassword.current'),
                  controller: _current,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Current password *',
                    errorText: state.errorFor('currentPassword'),
                    suffixIcon: visibilityToggle,
                  ),
                  validator: Validators.password,
                  onChanged: (_) =>
                      controller.clearFieldError('currentPassword'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('changePassword.new'),
                  controller: _new,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'New password *',
                    helperText:
                        'At least ${UserValidators.passwordMinLength} '
                        'characters.',
                    errorText: state.errorFor('newPassword'),
                    errorMaxLines: 2,
                  ),
                  validator: _differentFromCurrent,
                  onChanged: (_) => controller.clearFieldError('newPassword'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('changePassword.confirm'),
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Repeat new password *',
                  ),
                  validator: (value) =>
                      UserValidators.confirmPassword(value, _new.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'You stay logged in on this device. Other open sessions '
                  'of your account end.',
                  style: theme.textTheme.bodySmall,
                ),
                if (generalError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    generalError,
                    key: const Key('changePassword.error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('changePassword.cancel'),
          onPressed: state.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('changePassword.save'),
          onPressed: state.isSubmitting ? null : _submit,
          child: state.isSubmitting
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change password'),
        ),
      ],
    );
  }
}
