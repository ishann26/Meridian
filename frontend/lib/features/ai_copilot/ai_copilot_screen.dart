import 'package:flutter/material.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/shared/widgets/placeholder_screen.dart';

/// AI Copilot — intelligent logistics assistant.
///
/// Will surface AI-driven disruption predictions, route
/// recommendations, and natural-language supply chain Q&A.
class AiCopilotScreen extends StatelessWidget {
  const AiCopilotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'AI Copilot',
      subtitle:
          'Your AI logistics brain. Predicts disruptions, recommends routes, and answers supply-chain questions.',
      icon: Icons.auto_awesome_rounded,
      accentColor: AppColors.accentTan,
    );
  }
}
