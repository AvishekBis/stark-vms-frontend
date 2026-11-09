import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/feedback.dart';
import '../data/user_account.dart';
import 'user_providers.dart';

/// Opens the admin "Reset password" dialog for [user] (contract 7.3.3).
/// Resolves to `true` when the password was reset.
Future<bool> showResetPasswordDialog(
  BuildContext context, {
  required UserAccount user,
}) async {
  final reset = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ResetPasswordDialog(user: user),
  );
  if ((reset ?? false) && context.mounted) {
    AppFeedback.success(
      context,
      'Password of ${user.email} reset. Their open sessions have ended.',
    );
  }
  return reset ?? false;
}

class ResetPasswordDialog extends ConsumerStatefulWidget {
  const ResetPasswordDialog({super.key, required this.user});

  final UserAccount user;

  @override
  ConsumerState<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final reset = await ref
        .read(resetPasswordControllerProvider.notifier)
        .submit(widget.user, _password.text);
    if (reset && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);
    final controller = ref.read(resetPasswordControllerProvider.notifier);
    final theme = Theme.of(context);
    final generalError = state.errorMessage;

    return AlertDialog(
      key: const Key('resetPassword.dialog'),
      title: const Text('Reset password'),
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
                Text(
                  'Set a new password for ${widget.user.email}. Their open '
                  'sessions end on their next request; tell them the new '
                  'password and ask them to change it.',
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('resetPassword.new'),
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'New password *',
                    helperText:
                        'At least ${UserValidators.passwordMinLength} '
                        'characters.',
                    errorText: state.errorFor('newPassword'),
                    errorMaxLines: 2,
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: UserValidators.newPassword,
                  onChanged: (_) => controller.clearFieldError('newPassword'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('resetPassword.confirm'),
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Repeat new password *',
                  ),
                  validator: (value) =>
                      UserValidators.confirmPassword(value, _password.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (generalError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    generalError,
                    key: const Key('resetPassword.error'),
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
          key: const Key('resetPassword.cancel'),
          onPressed: state.isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('resetPassword.save'),
          onPressed: state.isSubmitting ? null : _submit,
          icon: state.isSubmitting
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset),
          label: const Text('Reset password'),
        ),
      ],
    );
  }
}
