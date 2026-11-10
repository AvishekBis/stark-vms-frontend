import 'package:flutter/material.dart';

import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_spacing.dart';
import 'connecting_banner.dart';
import 'state_views.dart';

/// Shown while a stored session is being restored after a page reload: the
/// warm page wash with the ornamented loading card in the middle, so the
/// first frame already belongs to the brand.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppDecorations.pageGradient),
        child: Column(
          children: [
            ConnectingBanner(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: LoadingView(message: 'Loading Stark Group VMS…'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
