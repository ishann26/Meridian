import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meridian/core/theme/app_colors.dart';
import 'package:meridian/core/theme/app_theme.dart';

/// AI Copilot — conversational what-if logistics planner.
///
/// Shows a centered chat layout with prompt chips, user bubbles,
/// and mock AI response cards with predictions and recommendations.
class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  static const _prompts = [
    'What if Chennai port congestion rises 40%?',
    'Reroute Mumbai to Delhi avoiding cyclone risk',
    'Compare road vs rail vs air',
    'Maximize air cargo utilization',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate AI response after a short delay.
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: text.trim(),
          isUser: false,
          response: _mockResponse(text.trim()),
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  _AiResponse _mockResponse(String query) {
    final q = query.toLowerCase();

    if (q.contains('chennai') || q.contains('congestion')) {
      return const _AiResponse(
        prediction:
            'If Chennai port congestion increases by 40%, average dwell '
            'time rises from 3.2 to 5.1 days. This impacts 4 active '
            'shipments on the India-SE Asia corridor.',
        recommendation:
            'Preemptively reroute SHP-004 and SHP-006 through Vizag '
            'port. Schedule departures 48h earlier to absorb buffer.',
        savings: '\$12.4k saved · 2.1 days faster',
        confidence: 87,
        riskLevel: 'HIGH',
      );
    }

    if (q.contains('reroute') || q.contains('cyclone')) {
      return const _AiResponse(
        prediction:
            'Cyclone risk on the Mumbai–Delhi corridor peaks at 62% '
            'probability over the next 72h. Road transport faces '
            '18–24h delays; rail remains viable via the southern route.',
        recommendation:
            'Switch SHP-001 from road to rail via Ahmedabad–Jaipur '
            'corridor. This bypasses the high-risk western coast zone.',
        savings: '\$3.2k saved · Avoids 22h delay',
        confidence: 79,
        riskLevel: 'MEDIUM',
      );
    }

    if (q.contains('compare') || q.contains('road') || q.contains('rail')) {
      return const _AiResponse(
        prediction:
            'For a 12-ton shipment on the Delhi–Bangalore corridor:\n'
            '• Road: 4 days, \$2,800, 1.8t CO₂\n'
            '• Rail: 3 days, \$1,900, 0.6t CO₂\n'
            '• Air: 8 hours, \$8,200, 3.1t CO₂',
        recommendation:
            'Rail is optimal for cost and sustainability. Air only '
            'justified if ETA is under 24h. Road is the least '
            'efficient option for this corridor.',
        savings: 'Rail saves 32% cost · 67% less CO₂ vs road',
        confidence: 94,
        riskLevel: 'LOW',
      );
    }

    if (q.contains('maximize') || q.contains('utilization')) {
      return const _AiResponse(
        prediction:
            'Current air cargo utilization is at 61%. Three flights '
            'on the Frankfurt–Dubai corridor have 30%+ spare capacity '
            'over the next 5 days.',
        recommendation:
            'Consolidate SHP-003 with pending Dubai-bound pharma '
            'shipments. Pre-book the DXB–FRA return leg for inbound '
            'electronics to push utilization above 85%.',
        savings: '\$6.1k revenue uplift · 85% utilization target',
        confidence: 82,
        riskLevel: 'LOW',
      );
    }

    // Generic fallback
    return const _AiResponse(
      prediction:
          'Based on current supply chain data, I see moderate risk '
          'on 2 active corridors. Overall network health is 87% '
          'with 3 shipments on track and 1 flagged for delay.',
      recommendation:
          'Monitor SHP-002 closely — Pacific corridor weather '
          'window closes in 48h. Consider pre-positioning buffer '
          'stock at the LA warehouse.',
      savings: 'Potential \$8.5k loss avoidance',
      confidence: 74,
      riskLevel: 'MEDIUM',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Messages area (scrollable) ─────────────────
            Expanded(
              child: _messages.isEmpty
                  ? _buildIntro()
                  : _buildChat(),
            ),

            // ── Input area ─────────────────────────────────
            _buildInput(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // INTRO (shown when chat is empty)
  // ─────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.panelDark,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 26, color: AppColors.accentMint),
            ),
            const SizedBox(height: 20),

            Text(
              'Meridian Copilot',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Ask Meridian to predict, simulate,\nor reroute shipments',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Prompt chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _prompts.map((p) => _PromptChip(
                text: p,
                onTap: () => _send(p),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CHAT MESSAGES
  // ─────────────────────────────────────────────────────────
  Widget _buildChat() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg, AppTheme.spacingMd,
        AppTheme.spacingLg, AppTheme.spacingSm,
      ),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, i) {
        // Typing indicator
        if (i == _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[i];
        if (msg.isUser) {
          return _buildUserBubble(msg);
        }
        return _buildAiResponse(msg);
      },
    );
  }

  Widget _buildUserBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 60),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.panelDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textOnDark,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResponse(_ChatMessage msg) {
    final r = msg.response!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.panelDark,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.accentMint),
          ),
          const SizedBox(width: 10),

          // Response card
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Meridian + badges
                  Row(
                    children: [
                      Text('Meridian',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      _badge('${r.confidence}% conf.',
                          AppColors.accentMintDark),
                      const SizedBox(width: 6),
                      _badge(r.riskLevel, _riskBadgeColor(r.riskLevel)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Prediction
                  _sectionLabel('Prediction'),
                  const SizedBox(height: 4),
                  Text(r.prediction,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Recommendation
                  _sectionLabel('Recommendation'),
                  const SizedBox(height: 4),
                  Text(r.recommendation,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Savings strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentMint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up_rounded,
                            size: 14, color: AppColors.accentMintDark),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(r.savings,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentMintDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/simulation'),
                      icon: const Icon(Icons.science_rounded, size: 16),
                      label: const Text('Run Simulation'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.panelDark,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.accentMint),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _PulsingDot(delay: i * 200),
              )),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // INPUT BAR
  // ─────────────────────────────────────────────────────────
  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: AppColors.bgPrimary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Center(
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask Meridian...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(_controller.text),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: AppColors.panelDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  size: 20, color: AppColors.textOnDark),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _riskBadgeColor(String level) {
    switch (level) {
      case 'HIGH':
        return AppColors.warning;
      case 'MEDIUM':
        return AppColors.accentTan;
      default:
        return AppColors.accentMintDark;
    }
  }
}

// ─────────────────────────────────────────────────────────
// PROMPT CHIP
// ─────────────────────────────────────────────────────────
class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Text(text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PULSING DOT (typing indicator)
// ─────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.delay});
  final int delay;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _ctrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Opacity(
          opacity: _anim.value,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────
class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.response,
  });
  final String text;
  final bool isUser;
  final _AiResponse? response;
}

class _AiResponse {
  const _AiResponse({
    required this.prediction,
    required this.recommendation,
    required this.savings,
    required this.confidence,
    required this.riskLevel,
  });
  final String prediction;
  final String recommendation;
  final String savings;
  final int confidence;
  final String riskLevel;
}
