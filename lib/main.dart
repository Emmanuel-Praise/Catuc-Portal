import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'student/models/student_session.dart';
import 'teacher/models/teacher_session.dart';
import 'ea/models/ea_session.dart';
import 'admin/models/admin_session.dart';
import 'dean/models/dean_session.dart';
import 'dean/screens/dean_shell.dart';
import 'student/screens/student_auth_welcome_screen.dart';
import 'student/screens/student_shell.dart';
import 'teacher/screens/teacher_shell.dart';
import 'ea/screens/ea_shell.dart';
import 'admin/screens/admin_shell.dart';
import 'services/local_storage_service.dart';
import 'services/data_cache_service.dart';
import 'services/offline_sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/onboarding_service.dart';
import 'student/services/ai_learning_store.dart';
import 'theme/theme_service.dart';
import 'theme/app_theme.dart';
import 'onboarding/onboarding_screen.dart';
import 'screens/update_required_screen.dart';
import 'services/version_service.dart';
import 'models/app_version.dart';
import 'theme/app_colors.dart';
import 'services/ban_service.dart';
import 'services/ban_interceptor.dart';
import 'services/announcement_service.dart';
import 'models/admin_announcement.dart';
import 'shared/screens/banned_screen.dart';
import 'shared/widgets/announcement_popup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  try {
    try {
      await LocalStorageService.init();
    } catch (e) {
      debugPrint('LocalStorage init error: $e');
    }
    try {
      await DataCacheService.init();
    } catch (e) {
      debugPrint('DataCache init error: $e');
    }
    try {
      await OfflineSyncService.init();
    } catch (e) {
      debugPrint('OfflineSync init error: $e');
    }
    try {
      await ConnectivityService().init();
    } catch (e) {
      debugPrint('Connectivity init error: $e');
    }
    try {
      await ThemeService().init();
    } catch (e) {
      debugPrint('Theme init error: $e');
    }
    try {
      await AiLearningStore.init();
    } catch (e) {
      debugPrint('AiLearningStore init error: $e');
    }
    
    // Try to sync any pending actions if online
    if (ConnectivityService().isOnline) {
      const OfflineSyncService().checkAndSync();
    }
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  final session = const LocalStorageService().getSession();

  runApp(CatptApp(initialSession: session));
}

class CatptApp extends StatefulWidget {
  final Map<String, dynamic>? initialSession;

  const CatptApp({super.key, this.initialSession});

  @override
  State<CatptApp> createState() => _CatptAppState();
}

class _CatptAppState extends State<CatptApp> {
  static const int currentAppVersionCode = 1;
  // Version name for display purposes
  static const String currentAppVersionName = '1.0.0'; // ignore: unused_field

  bool _isOnboardingChecked = false;
  bool _shouldShowOnboarding = false;
  bool _isVersionChecked = false;
  AppVersion? _requiredVersion;
  Map<String, dynamic>? _banInfo; // null = not banned
  List<AdminAnnouncement> _announcements = [];
  bool _announcementsShown = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final onboardingCompleted = await OnboardingService.isOnboardingCompleted();
    
    // Check version status
    AppVersion? requiredVersion;
    try {
      requiredVersion = await const VersionService().fetchRequiredVersion();
    } catch (e) {
      debugPrint('Version check failed: $e');
    }

    // Check ban status if user has a session
    Map<String, dynamic>? banInfo;
    if (widget.initialSession != null) {
      final userId = (widget.initialSession!['user_id'] ?? '').toString();
      if (userId.isNotEmpty) {
        try {
          banInfo = await const BanService().checkBan(userId);
        } catch (e) {
          debugPrint('Ban check failed: $e');
        }
      }
    }

    // Fetch announcements
    List<AdminAnnouncement> announcements = [];
    try {
      announcements = await const AnnouncementService().fetchActiveAnnouncements();
    } catch (e) {
      debugPrint('Announcements fetch failed: $e');
    }

    setState(() {
      _shouldShowOnboarding = !onboardingCompleted;
      _isOnboardingChecked = true;
      _requiredVersion = requiredVersion;
      _isVersionChecked = true;
      _banInfo = banInfo;
      _announcements = announcements;
    });
  }

  void _showAnnouncementsIfNeeded(BuildContext context) {
    if (_announcementsShown || _announcements.isEmpty) return;
    _announcementsShown = true;
    // Show after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showAnnouncementPopup(context, _announcements);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnboardingChecked || !_isVersionChecked) {
      final primaryColor = ThemeService().primaryColor;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(primaryColor),
        darkTheme: AppTheme.dark(primaryColor),
        themeMode: ThemeMode.system,
        home: Scaffold(
          backgroundColor: ThemeMode.system == ThemeMode.dark ? AppColors.darkBackground : Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ),
      );
    }

    if (_requiredVersion != null && 
        const VersionService().isUpdateRequired(currentAppVersionCode, _requiredVersion!)) {
      final primaryColor = ThemeService().primaryColor;
      return MaterialApp(
        title: 'CATPT App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(primaryColor),
        darkTheme: AppTheme.dark(primaryColor),
        themeMode: ThemeMode.system,
        home: UpdateRequiredScreen(
          requiredVersion: _requiredVersion!.versionName,
          downloadUrl: _requiredVersion!.downloadUrl,
        ),
      );
    }

    if (_shouldShowOnboarding && widget.initialSession == null) {
      final primaryColor = ThemeService().primaryColor;
      return MaterialApp(
        title: 'CATPT App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(primaryColor),
        darkTheme: AppTheme.dark(primaryColor),
        themeMode: ThemeMode.system,
        home: const OnboardingScreen(),
      );
    }

    // Show banned screen if user is banned (blocks everything)
    if (_banInfo != null && widget.initialSession != null) {
      final userId = (widget.initialSession!['user_id'] ?? '').toString();
      final primaryColor = ThemeService().primaryColor;
      return MaterialApp(
        title: 'CATPT App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(primaryColor),
        darkTheme: AppTheme.dark(primaryColor),
        themeMode: ThemeMode.system,
        home: BannedScreen(
          userId: userId,
          reason: (_banInfo!['reason'] ?? '').toString(),
          bannedAt: (_banInfo!['banned_at'] ?? '').toString(),
        ),
      );
    }

    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        final primaryColor = ThemeService().primaryColor;

        Widget initialHome = const StudentAuthWelcomeScreen();
        if (widget.initialSession != null) {
          try {
            final role = (widget.initialSession!['role'] ?? '').toString().toLowerCase();
            if (role == 'student') {
              initialHome = StudentShell(
                user: StudentSession.fromJson(widget.initialSession!),
              );
            } else if (role == 'staff' || role == 'teacher' || role == 'lecturer' || role == 'hod') {
              initialHome = TeacherShell(
                user: TeacherSession.fromJson(widget.initialSession!),
              );
            } else if (role == 'dean') {
              initialHome = DeanShell(
                user: DeanSession.fromJson(widget.initialSession!),
              );
            } else if (role == 'ea') {
              initialHome = EaShell(user: EaSession.fromJson(widget.initialSession!));
            } else if (role == 'admin') {
              initialHome = AdminShell(user: AdminSession.fromJson(widget.initialSession!));
            }
          } catch (e) {
            debugPrint('Invalid saved session, showing auth welcome: $e');
          }
        }

        return MaterialApp(
          navigatorKey: BanInterceptor.navigatorKey,
          title: 'CATPT App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(primaryColor),
          darkTheme: AppTheme.dark(primaryColor),
          themeMode: ThemeMode.system,
          home: Builder(
            builder: (ctx) {
              _showAnnouncementsIfNeeded(ctx);
              return initialHome;
            },
          ),
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return _OfflineBannerWrapper(
              connectionStream: ConnectivityService().connectionStream,
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Auto-dismissing offline banner that slides in/out and doesn't block buttons
class _OfflineBannerWrapper extends StatefulWidget {
  final Stream<bool> connectionStream;
  final Widget child;

  const _OfflineBannerWrapper({
    required this.connectionStream,
    required this.child,
  });

  @override
  State<_OfflineBannerWrapper> createState() => _OfflineBannerWrapperState();
}

class _OfflineBannerWrapperState extends State<_OfflineBannerWrapper> {
  bool _showBanner = false;
  Timer? _hideTimer;
  StreamSubscription<bool>? _subscription;
  bool _lastKnownOnline = true;

  @override
  void initState() {
    super.initState();
    _lastKnownOnline = ConnectivityService().isOnline;
    _subscription = widget.connectionStream.listen((isOnline) {
      if (!isOnline && _lastKnownOnline) {
        // Just went offline — show the banner briefly
        _showBannerBriefly();
      } else if (isOnline && !_lastKnownOnline) {
        // Back online — show a "back online" briefly
        _showBannerBriefly();
      }
      _lastKnownOnline = isOnline;
    });

    // Show banner on initial load if already offline
    if (!ConnectivityService().isOnline) {
      _showBannerBriefly();
    }
  }

  void _showBannerBriefly() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() => _showBanner = true);
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showBanner = false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _lastKnownOnline;
    return Stack(
      children: [
        widget.child,
        // IgnorePointer so it never blocks touches
        IgnorePointer(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            offset: _showBanner ? Offset.zero : const Offset(0, -1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showBanner ? 1.0 : 0.0,
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, left: 24, right: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFF10B981).withValues(alpha: 0.95)
                          : const Color(0xFFEF4444).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'Back online' : 'Offline — Using cached data',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
