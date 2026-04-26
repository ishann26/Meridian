import 'package:flutter/material.dart';

import 'package:meridian/core/theme/app_theme.dart';
import 'package:meridian/core/routes/app_router.dart';

void main() {
  runApp(const SmartLogiChainApp());
}

/// Root widget for SmartLogiChain.
///
/// Applies the custom theme and GoRouter for declarative navigation.
class SmartLogiChainApp extends StatelessWidget {
  const SmartLogiChainApp({super.key});

  @override
  Widget build(BuildContext context) {  
    return MaterialApp.router(
      title: 'SmartLogiChain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
