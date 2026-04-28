import 'package:flutter/material.dart';

import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/core/routes/app_router.dart';

void main() {
  runApp(const MeridianApp());
}

/// Root widget for Meridian.
///
/// Applies the custom theme and GoRouter for declarative navigation.
class MeridianApp extends StatelessWidget {
  const MeridianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Meridian',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
