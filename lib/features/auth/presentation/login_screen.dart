import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/brand.dart';
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
    return Scaffold(
      body: Column(
        children: [
          const ConnectingBanner(),
          Expanded(
            child: DecoratedBox(
              // The sign-in page is one navy field with the card floating on
              // it: the first impression of the brand.
              decoration: const BoxDecoration(
                gradient: AppDecorations.headerGradient,
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BackdropPainter()),
                    ),
                  ),
                  _card(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The raised sign-in card that floats on the navy field.
  Widget _card(BuildContext context) {
    final submission = ref.watch(loginControllerProvider);
    final notice = ref.watch(authControllerProvider).valueOrNull?.notice;
    final isLoading = submission.isLoading;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.loginMaxWidth),
          child: DecoratedBox(
            decoration: AppDecorations.card(
              shadow: AppDecorations.raisedShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: IconPlate(
                          icon: Icons.local_shipping_outlined,
                          size: AppSpacing.xl * 1.75,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Stark Group VMS',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      Center(child: AppDecorations.goldRule()),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Vehicle Management System',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppPalette.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (notice != null && !submission.hasError) ...[
                        _Message(key: const Key('login.notice'), text: notice),
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
                              () => _obscurePassword = !_obscurePassword,
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
                        Center(
                          child: AppDecorations.goldRule(
                            width: AppSpacing.xl,
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          // The two credential lines come from dart-defines
                          // (AppConfig.demoAdmin / demoStaff) so a deploy can
                          // pass the accounts that work against ITS backend;
                          // without them the local seed values stand.
                          'Demo accounts (non-real credentials)\n'
                          'Admin: ${AppConfig.demoAdmin}\n'
                          'Staff: ${AppConfig.demoStaff}',
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
    );
  }
}

/// Faint gold arcs and a dotted grid behind the login card. One paint, no
/// animation, no assets.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppPalette.gold.withValues(alpha: 0.07);
    const step = 36.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppPalette.gold.withValues(alpha: 0.14);
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final base = size.shortestSide;
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: base * (0.34 + 0.16 * i)),
        -math.pi * 0.85,
        math.pi * 0.7,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
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
