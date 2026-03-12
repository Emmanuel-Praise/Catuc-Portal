import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

class UserGuideOverlay extends StatefulWidget {
  final Widget child;
  final String userRole;

  const UserGuideOverlay({
    super.key,
    required this.child,
    required this.userRole,
  });

  static UserGuideState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_UserGuideOverlayState>();
    if (state == null) throw FlutterError('UserGuideOverlay not found in context');
    return state;
  }

  @override
  State<UserGuideOverlay> createState() => _UserGuideOverlayState();
}

abstract class UserGuideState {
  GlobalKey getKey(String name);
}

class _UserGuideOverlayState extends State<UserGuideOverlay>
    with TickerProviderStateMixin implements UserGuideState {
  bool _showGuide = false;
  int _currentStep = 0;
  late AnimationController _overlayController;
  late AnimationController _tooltipController;
  
  final Map<String, GlobalKey> _keys = {
    'dashboard': GlobalKey(),
    'navigation': GlobalKey(),
    'profile': GlobalKey(),
    'grades': GlobalKey(),
    'attendance': GlobalKey(),
    'courses': GlobalKey(),
    'academics': GlobalKey(),
    'people': GlobalKey(),
    'ai': GlobalKey(),
    'settings': GlobalKey(),
  };

  @override
  GlobalKey getKey(String name) => _keys[name] ?? GlobalKey();

  @override
  void initState() {
    super.initState();
    
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _tooltipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _checkFirstLogin();
  }

  Future<void> _checkFirstLogin() async {
    final isFirstLoginCompleted = await OnboardingService.isFirstLoginCompleted();
    if (!isFirstLoginCompleted && mounted) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _showGuide = true;
        });
        _overlayController.forward();
        _tooltipController.forward();
      });
    }
  }

  void _nextStep() {
    _tooltipController.reverse().then((_) {
      if (_currentStep < _getGuideSteps().length - 1) {
        setState(() {
          _currentStep++;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _tooltipController.forward();
        });
      } else {
        _completeGuide();
      }
    });
  }

  void _skipGuide() {
    _completeGuide();
  }

  void _completeGuide() async {
    await _tooltipController.reverse();
    await _overlayController.reverse();
    await OnboardingService.setFirstLoginCompleted(true);
    if (mounted) {
      setState(() {
        _showGuide = false;
      });
    }
  }
  
  @override
  void dispose() {
    _overlayController.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  List<GuideStep> _getGuideSteps() {
    switch (widget.userRole.toLowerCase()) {
      case 'student':
        return [
          GuideStep(
            title: 'Your Dashboard 👋',
            description: 'See summaries, announcements, and quick actions here.',
            targetKey: _keys['dashboard']!,
            position: GuidePosition.center,
          ),
          GuideStep(
            title: 'Courses & Materials 📚',
            description: 'Use the bottom tabs to switch between Home, Courses, and Profile.',
            targetKey: _keys['navigation']!,
            position: GuidePosition.bottom,
          ),
          GuideStep(
            title: 'Student Profile 👤',
            description: 'Tap Profile (person icon) to manage your details and settings.',
            targetKey: _keys['navigation']!,
            position: GuidePosition.bottom,
          ),
        ];
      case 'teacher':
        return [
          GuideStep(
            title: 'Teacher Hub 👨‍🏫',
            description: 'Manage your lecture schedule and see class performance at a glance.',
            targetKey: _keys['dashboard']!,
            position: GuidePosition.center,
          ),
          GuideStep(
            title: 'My Classes 🏫',
            description: 'Use the bottom tabs to switch between Home, Courses, and Profile.',
            targetKey: _keys['navigation']!,
            position: GuidePosition.bottom,
          ),
        ];
      case 'admin':
        return [
          GuideStep(
            title: 'Admin Overview',
            description: 'See system status, activity, and quick admin actions here.',
            targetKey: _keys['dashboard']!,
            position: GuidePosition.center,
          ),
          GuideStep(
            title: 'Bottom Navigation',
            description: 'Use these tabs to jump to Academics, People, AI, and Settings quickly.',
            targetKey: _keys['navigation']!,
            position: GuidePosition.bottom,
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showGuide && _currentStep < _getGuideSteps().length)
          UserGuideWidget(
            steps: _getGuideSteps(),
            currentStep: _currentStep,
            onNext: _nextStep,
            onSkip: _skipGuide,
          ),
      ],
    );
  }
}

class GuideStep {
  final String title;
  final String description;
  final GlobalKey targetKey;
  final GuidePosition position;

  GuideStep({
    required this.title,
    required this.description,
    required this.targetKey,
    required this.position,
  });
}

enum GuidePosition { top, bottom, left, right, center }

class UserGuideWidget extends StatefulWidget {
  final List<GuideStep> steps;
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const UserGuideWidget({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<UserGuideWidget> createState() => _UserGuideWidgetState();
}

class _UserGuideWidgetState extends State<UserGuideWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentStep >= widget.steps.length) return const SizedBox.shrink();

    final currentStep = widget.steps[widget.currentStep];
    final targetRect = _targetRectForKey(currentStep.targetKey);
    
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _pulseController]),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final screen = media.size;
        final safeTop = media.padding.top + 12;
        final safeBottom = media.padding.bottom + 12;

        final rect = targetRect;
        bool placeTooltipBelow;
        if (rect == null) {
          placeTooltipBelow = currentStep.position == GuidePosition.bottom;
        } else {
          final spaceBelow = screen.height - rect.bottom - safeBottom;
          final spaceAbove = rect.top - safeTop;
          placeTooltipBelow = spaceBelow >= 240 || spaceBelow >= spaceAbove;
        }

        return Opacity(
          opacity: _fadeAnimation.value,
          child: Stack(
            children: [
              const ModalBarrier(dismissible: false, color: Colors.transparent),
              _GuideHighlight(
                targetKey: currentStep.targetKey,
                pulseT: _pulseController.value,
                placeTooltipBelow: placeTooltipBelow,
                child: _GuideTooltip(
                  title: currentStep.title,
                  description: currentStep.description,
                  position: currentStep.position,
                  targetRect: targetRect,
                  stepIndex: widget.currentStep,
                  stepCount: widget.steps.length,
                  onNext: widget.onNext,
                  onSkip: widget.onSkip,
                  isLastStep: widget.currentStep == widget.steps.length - 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Rect? _targetRectForKey(GlobalKey key) {
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(position.dx, position.dy, renderBox.size.width, renderBox.size.height);
  }
}

class _GuideHighlight extends StatelessWidget {
  final GlobalKey targetKey;
  final double pulseT;
  final bool placeTooltipBelow;
  final Widget child;

  const _GuideHighlight({
    required this.targetKey,
    required this.pulseT,
    required this.placeTooltipBelow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: _HighlightPainter(
            targetKey: targetKey,
            pulseT: pulseT,
            accentColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        _GuidePointer(
          targetKey: targetKey,
          pulseT: pulseT,
          placeTooltipBelow: placeTooltipBelow,
          color: Theme.of(context).colorScheme.primary,
        ),
        child,
      ],
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final GlobalKey targetKey;
  final double pulseT;
  final Color accentColor;

  _HighlightPainter({
    required this.targetKey,
    required this.pulseT,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      final paint = Paint()
        ..color = Colors.black.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final rect = Rect.fromLTWH(position.dx - 8, position.dy - 8, targetSize.width + 16, targetSize.height + 16);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(rrect),
      ),
      paint,
    );

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55 + 0.25 * pulseT)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rrect, borderPaint);
    
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.10 + 0.18 * pulseT)
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, 12 + 10 * pulseT)
      ..strokeWidth = 7;
    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) => true;
}

class _GuidePointer extends StatelessWidget {
  final GlobalKey targetKey;
  final double pulseT;
  final bool placeTooltipBelow;
  final Color color;

  const _GuidePointer({
    required this.targetKey,
    required this.pulseT,
    required this.placeTooltipBelow,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final screen = media.size;

    final position = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final rect = Rect.fromLTWH(position.dx, position.dy, targetSize.width, targetSize.height);

    final dx = (rect.center.dx - 20).clamp(10.0, screen.width - 50.0);
    final isBelow = placeTooltipBelow;
    final dy = isBelow
        ? (rect.bottom + 10).clamp(10.0, screen.height - 60.0)
        : (rect.top - 46).clamp(10.0, screen.height - 60.0);

    final offsetY = (1 - pulseT) * (isBelow ? 8 : -8);

    return Positioned(
      left: dx,
      top: dy + offsetY,
      child: IgnorePointer(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35 + 0.15 * pulseT),
                blurRadius: 18 + 12 * pulseT,
                spreadRadius: 1 + 1 * pulseT,
              ),
            ],
          ),
          child: Icon(
            isBelow ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: Colors.white.withValues(alpha: 0.96),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _GuideTooltip extends StatelessWidget {
  final String title;
  final String description;
  final GuidePosition position;
  final Rect? targetRect;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLastStep;

  const _GuideTooltip({
    required this.title,
    required this.description,
    required this.position,
    required this.targetRect,
    required this.stepIndex,
    required this.stepCount,
    required this.onNext,
    required this.onSkip,
    required this.isLastStep,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final media = MediaQuery.of(context);
    final screen = media.size;
    final safeTop = media.padding.top + 12;
    final safeBottom = media.padding.bottom + 12;
    const horizontalMargin = 20.0;

    final rect = targetRect;
    bool placeBelow;
    if (rect == null) {
      placeBelow = position == GuidePosition.bottom;
    } else {
      final spaceBelow = screen.height - rect.bottom - safeBottom;
      final spaceAbove = rect.top - safeTop;
      placeBelow = spaceBelow >= 240 || spaceBelow >= spaceAbove;
    }

    // Keep the tooltip fully on-screen by clamping its TOP position.
    // (Using `bottom:` can push the card off-screen on some layouts.)
    final estimatedHeight = (screen.height * 0.36).clamp(240.0, 340.0);
    final maxTop = (screen.height - safeBottom - estimatedHeight).clamp(safeTop, screen.height);

    double top;
    if (rect == null) {
      top = (safeTop + 110).clamp(safeTop, maxTop);
    } else if (placeBelow) {
      top = (rect.bottom + 14).clamp(safeTop, maxTop);
    } else {
      top = (rect.top - 14 - estimatedHeight).clamp(safeTop, maxTop);
    }

    final arrowFraction = rect == null
        ? 0.5
        : ((rect.center.dx - horizontalMargin) / (screen.width - horizontalMargin * 2))
            .clamp(0.12, 0.88);
    final arrowAlignmentX = arrowFraction * 2 - 1; // -1..1
    final progress = stepCount <= 1 ? 1.0 : (stepIndex + 1) / stepCount;

    final maxWidth = screen.width >= 560 ? 520.0 : double.infinity;
    final cardBg = (isDark ? const Color(0xFF0B1220) : Colors.white).withValues(alpha: 0.92);
    final textColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A);
    final bodyColor = isDark ? Colors.white.withValues(alpha: 0.72) : Colors.black.withValues(alpha: 0.60);

    return Positioned(
      top: top,
      left: horizontalMargin,
      right: horizontalMargin,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: placeBelow ? Alignment(arrowAlignmentX, -1) : Alignment(arrowAlignmentX, 1),
                      child: Transform.translate(
                        offset: Offset(0, placeBelow ? -14 : 14),
                        child: CustomPaint(
                          size: const Size(28, 14),
                          painter: _TooltipArrowPainter(
                            color: cardBg,
                            pointUp: placeBelow,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'TUTORIAL • ${stepIndex + 1}/$stepCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  height: 6,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress.clamp(0.0, 1.0),
                                    child: Container(color: primaryColor),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [primaryColor, primaryColor.withValues(alpha: 0.78)],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  height: 1.05,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: screen.height * 0.26),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 16,
                                color: bodyColor,
                                height: 1.55,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            TextButton(
                              onPressed: onSkip,
                              style: TextButton.styleFrom(
                                foregroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: onNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                isLastStep ? 'Finish' : 'Next',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TooltipArrowPainter extends CustomPainter {
  final Color color;
  final bool pointUp;

  _TooltipArrowPainter({
    required this.color,
    required this.pointUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointUp) {
      // Triangle pointing up (towards the highlighted target above the card).
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      // Triangle pointing down.
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
      path.close();
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TooltipArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointUp != pointUp;
  }
}

class GuideTarget extends StatelessWidget {
  final Widget child;
  final String name;

  const GuideTarget({
    super.key,
    required this.child,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final key = UserGuideOverlay.of(context).getKey(name);
      return Container(
        key: key,
        child: child,
      );
    } catch (e) {
      return child;
    }
  }
}
