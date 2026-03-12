import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../student/screens/student_auth_welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatController;
  late AnimationController _pulseController;

  static const _totalPages = 4;

  // Brand colors
  static const _brandBlue = Color(0xFF0A1E6E);
  static const _accentBlue = Color(0xFF2563EB);
  static const _lightBlue = Color(0xFF3B82F6);
  static const _skyBlue = Color(0xFFDBEAFE);

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const StudentAuthWelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _next() {
    if (_currentPage == _totalPages - 1) {
      _completeOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skip() => _completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _currentPage == _totalPages - 1;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0A0E1A), const Color(0xFF111827)]
                    : [
                        _getPageBgColor(_currentPage),
                        isDark
                            ? const Color(0xFF111827)
                            : Colors.white,
                      ],
              ),
            ),
          ),

          // ── Decorative blurred circles ──
          Positioned(
            top: -60,
            right: -40,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    8 * math.sin(_floatController.value * math.pi),
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentBlue.withValues(alpha: isDark ? 0.08 : 0.12),
                      _accentBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    -6 * math.sin(_floatController.value * math.pi),
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _lightBlue.withValues(alpha: isDark ? 0.06 : 0.1),
                      _lightBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(
                          'assets/images/catuc_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CATUC',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Student Portal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Pages ──
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _buildWelcomePage(isDark, size),
                      _buildAcademicPage(isDark, size),
                      _buildAIPage(isDark, size),
                      _buildGetStartedPage(isDark, size),
                    ],
                  ),
                ),

                // ── Bottom controls ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots
                      Row(
                        children:
                            List.generate(_totalPages, (i) {
                          final selected = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            margin: const EdgeInsets.only(right: 6),
                            height: 8,
                            width: selected ? 28 : 8,
                            decoration: BoxDecoration(
                              color: selected
                                  ? _accentBlue
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      // CTA Button
                      _buildCTAButton(isLast, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 1: WELCOME — Full hero image with glass card
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWelcomePage(bool isDark, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // ── Hero image with stacked overlays ──
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main campus image
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: _brandBlue.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/Campus.png',
                          fit: BoxFit.cover,
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                        // Glass badge at bottom-left
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: _accentBlue
                                            .withValues(alpha: 0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'BAMENDA • CAMEROON',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Floating stat card (top-right)
                Positioned(
                  top: 16,
                  right: 8,
                  child: AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                            0,
                            4 *
                                math.sin(
                                    _floatController.value * math.pi)),
                        child: child,
                      );
                    },
                    child: _buildFloatingChip(
                      icon: Icons.people_alt_rounded,
                      label: '2000+ Students',
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // ── Text content ──
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildTagPill('WELCOME', isDark),
                  const SizedBox(height: 14),
                  Text(
                    'Welcome to\nCATUC Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your complete academic companion.\nResults, courses, and campus life — all in one app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 2: ACADEMIC EXCELLENCE — Stacked rounded images collage
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAcademicPage(bool isDark, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // ── Image collage ──
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    // Large image (left)
                    Positioned(
                      left: 0,
                      top: h * 0.05,
                      width: w * 0.62,
                      height: h * 0.75,
                      child: _buildRoundedImage(
                        'assets/images/graduates.png',
                        borderRadius: 28,
                        shadow: true,
                      ),
                    ),
                    // Small image (top-right)
                    Positioned(
                      right: 0,
                      top: 0,
                      width: w * 0.42,
                      height: h * 0.42,
                      child: _buildRoundedImage(
                        'assets/images/graduates1.webp',
                        borderRadius: 22,
                        shadow: true,
                      ),
                    ),
                    // Gradient card (bottom-right)
                    Positioned(
                      right: 0,
                      bottom: h * 0.08,
                      width: w * 0.42,
                      height: h * 0.35,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_accentBlue, _brandBlue],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accentBlue.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Track\nProgress',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Floating badge
                    Positioned(
                      left: w * 0.35,
                      top: h * 0.65,
                      child: AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              5 *
                                  math.sin(
                                      _floatController.value * math.pi),
                            ),
                            child: child,
                          );
                        },
                        child: _buildFloatingChip(
                          icon: Icons.emoji_events_rounded,
                          label: 'Excellence',
                          isDark: isDark,
                          bgColor: const Color(0xFFFEF3C7),
                          iconColor: const Color(0xFFF59E0B),
                          textColor: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          // ── Text ──
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildTagPill('ACADEMICS', isDark),
                  const SizedBox(height: 14),
                  Text(
                    'Achieve Your\nDreams',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Track your results, timetable, and academic\nprogress from year one to graduation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 3: AI LEARNING — No image, beautiful icon cards
  // ═══════════════════════════════════════════════════════════════════════════
  /*
   * NOTE: Deprecated. This old version caused overflow/layout issues on smaller screens.
   * Kept temporarily for reference.
   *
  Widget _buildAIPageOld(bool isDark, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  // Big AI icon
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale =
                          1.0 + 0.04 * math.sin(_pulseController.value * math.pi);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_accentBlue, Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: _accentBlue.withValues(alpha: 0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Feature cards row 1
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.summarize_rounded,
                          title: 'Summarize',
                          subtitle: 'Notes & docs',
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.quiz_rounded,
                          title: 'Quizzes',
                          subtitle: 'Auto-generated',
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Feature cards row 2
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.school_rounded,
                          title: 'Learn',
                          subtitle: 'Any topic',
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.record_voice_over_rounded,
                          title: 'Voice AI',
                          subtitle: 'Ask anything',
                          color: const Color(0xFFEC4899),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // ── Text ──
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildTagPill('CATU AI', isDark,
                      gradient: const [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                  const SizedBox(height: 14),
                  Text(
                    'Study Smarter\nwith AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Summarize notes, generate quizzes, and get\ninstant help with any academic topic.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 4: GET STARTED — Logo + highlights + CTA
  // ═══════════════════════════════════════════════════════════════════════════
  */

  Widget _buildAIPage(bool isDark, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale =
                              1.0 + 0.04 * math.sin(_pulseController.value * math.pi);
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_accentBlue, Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: _accentBlue.withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.summarize_rounded,
                              title: 'Summarize',
                              subtitle: 'Notes & docs',
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.quiz_rounded,
                              title: 'Quizzes',
                              subtitle: 'Auto-generated',
                              color: const Color(0xFFF59E0B),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.school_rounded,
                              title: 'Learn',
                              subtitle: 'Any topic',
                              color: const Color(0xFF8B5CF6),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.record_voice_over_rounded,
                              title: 'Voice AI',
                              subtitle: 'Ask anything',
                              color: const Color(0xFFEC4899),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildTagPill(
                        'CATU AI',
                        isDark,
                        gradient: const [Color(0xFF2563EB), Color(0xFF7C3AED)],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Study Smarter\nwith AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Summarize notes, generate quizzes, and get\ninstant help with any academic topic.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGetStartedPage(bool isDark, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Logo
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale =
                  1.0 + 0.03 * math.sin(_pulseController.value * math.pi);
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _accentBlue.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : _skyBlue.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Image.asset(
                'assets/images/catuc_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Everything You Need',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All in one place',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          // Feature list
          _buildHighlightRow(
            Icons.bar_chart_rounded,
            'Results & Transcripts',
            'View grades anytime',
            const Color(0xFF10B981),
            isDark,
          ),
          const SizedBox(height: 14),
          _buildHighlightRow(
            Icons.calendar_month_rounded,
            'Timetable & Schedule',
            'Never miss a class',
            _accentBlue,
            isDark,
          ),
          const SizedBox(height: 14),
          _buildHighlightRow(
            Icons.campaign_rounded,
            'Announcements',
            'Stay in the loop',
            const Color(0xFFF59E0B),
            isDark,
          ),
          const SizedBox(height: 14),
          _buildHighlightRow(
            Icons.auto_awesome_rounded,
            'AI Study Assistant',
            'Powered by Catu AI',
            const Color(0xFF8B5CF6),
            isDark,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Color _getPageBgColor(int page) {
    switch (page) {
      case 0:
        return const Color(0xFFF0F5FF);
      case 1:
        return const Color(0xFFF0F9FF);
      case 2:
        return const Color(0xFFF5F3FF);
      case 3:
        return const Color(0xFFF8FAFC);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  Widget _buildRoundedImage(
    String asset, {
    double borderRadius = 24,
    bool shadow = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildFloatingChip({
    required IconData icon,
    required String label,
    required bool isDark,
    Color? bgColor,
    Color? iconColor,
    Color? textColor,
  }) {
    final bg = bgColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white);
    final ic = iconColor ?? _accentBlue;
    final tc = textColor ??
        (isDark ? Colors.white : const Color(0xFF0F172A));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ic),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: tc,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : color.withValues(alpha: 0.12),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPill(String text, bool isDark,
      {List<Color>? gradient}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient != null
            ? LinearGradient(colors: gradient)
            : null,
        color: gradient == null
            ? (isDark
                ? _accentBlue.withValues(alpha: 0.15)
                : _skyBlue)
            : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: gradient != null ? Colors.white : _accentBlue,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildHighlightRow(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white54
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: color.withValues(alpha: 0.6),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton(bool isLast, bool isDark) {
    return GestureDetector(
      onTap: _next,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        height: 56,
        width: isLast ? 180 : 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_accentBlue, _brandBlue],
          ),
          borderRadius: BorderRadius.circular(isLast ? 28 : 16),
          boxShadow: [
            BoxShadow(
              color: _accentBlue.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(isLast ? 28 : 16),
            onTap: _next,
            child: Center(
              child: isLast
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    )
                  : const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
