import 'package:flutter/material.dart';

import 'connecting_banner.dart';
import 'state_views.dart';

/// Shown while a stored session is being restored after a page reload.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          ConnectingBanner(),
          Expanded(child: LoadingView(message: 'Loading Stark Group VMS…')),
        ],
      ),
    );
  }
}
