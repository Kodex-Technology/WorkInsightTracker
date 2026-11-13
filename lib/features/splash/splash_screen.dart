import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/core/widgets/witrack_mark.dart';
import 'package:witrack/features/auth/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _rise;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _rise = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    Future<void>.delayed(AppConstants.splashDuration, _tryNavigate);
  }

  void _tryNavigate() {
    if (!mounted || _navigated) return;
    final auth = ref.read(authControllerProvider);
    if (auth.isLoading) {
      Future<void>.delayed(const Duration(milliseconds: 100), _tryNavigate);
      return;
    }
    _navigated = true;
    if (!auth.isAuthenticated) {
      context.go('/login');
      return;
    }
    context.go(
      auth.user?.isDevAdmin == true ? '/app/admin' : '/app/dashboard',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen(authControllerProvider, (previous, next) {
      if (!next.isLoading) {
        _tryNavigate();
      }
    });

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0B1020),
                    Color(0xFF111827),
                    Color(0xFF151B2E),
                  ]
                : const [
                    Color(0xFFF8FAFC),
                    Color(0xFFEEF2F7),
                    Color(0xFFE8EEF8),
                  ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fade.value,
                child: Transform.translate(
                  offset: Offset(0, _rise.value),
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WitrackMark(size: 88, showGlow: true),
                const SizedBox(height: 28),
                Text(
                  AppConstants.brandPrimary,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                Text(
                  AppConstants.brandSecondary,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.tagline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
