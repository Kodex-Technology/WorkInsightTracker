import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell content transition — fade only (no slide).
///
/// Slide + fade was tearing the previous screen under the shell. Outgoing
/// pages fade via [secondaryAnimation]; incoming fade via [animation].
class FadeSlidePage<T> extends CustomTransitionPage<T> {
  FadeSlidePage({
    required super.child,
    super.name,
    super.arguments,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 140),
          reverseTransitionDuration: const Duration(milliseconds: 110),
          maintainState: true,
          opaque: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeIn = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            );
            final fadeOut = Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOut,
              ),
            );

            return FadeTransition(
              opacity: fadeIn,
              child: FadeTransition(
                opacity: fadeOut,
                child: child,
              ),
            );
          },
        );
}
