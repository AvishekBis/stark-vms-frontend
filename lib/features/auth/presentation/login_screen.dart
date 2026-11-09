import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/connecting_banner.dart';
import '../../../shared/widgets/state_views.dart';
import 'auth_controller.dart';
import 'login_controller.dart';

/// Login with email and password (FR-AUTH-01). On success the router
/// redirects to the dashboard.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscurePassword = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(loginControllerProvider);
    final notice = ref.watch(authControllerProvider).valueOrNull?.notice;
    final isLoading = submission.isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          const ConnectingBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.loginMaxWidth,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _autovalidateMode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: AppSpacing.xl * 1.5,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Stark Group VMS',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                'Vehicle Management System',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (notice != null && !submission.hasError) ...[
                                _Message(
                                  key: const Key('login.notice'),
                                  text: notice,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (submission.hasError) ...[
                                _Message(
                                  key: const Key('login.error'),
                                  text: ErrorView.messageFor(submission.error!),
                                  isError: true,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              TextFormField(
                                key: const Key('login.email'),
                                controller: _email,
                                enabled: !isLoading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: Validators.email,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                key: const Key('login.password'),
                                controller: _password,
                                enabled: !isLoading,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    key: const Key('login.togglePassword'),
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: Validators.password,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton(
                                key: const Key('login.submit'),
                                onPressed: isLoading ? null : _submit,
                                child: isLoading
                                    ? const SizedBox.square(
                                        dimension: AppSpacing.lg,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Log in'),
                              ),
                              if (isLoading) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Signing in…',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              if (AppConfig.showDemoCredentials) ...[
                                const SizedBox(height: AppSpacing.lg),
                                const Divider(),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Demo accounts (non-real credentials)\n'
                                  'Admin: admin@stark.local / Admin@12345\n'
                                  'Staff: staff@stark.local / Staff@12345',
                                  key: const Key('login.demoHint'),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isError
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: foreground,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
