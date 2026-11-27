import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/app/router.dart';
import 'package:witrack/app/witrack_app.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/data/settings/settings_repository.dart';
import 'package:witrack/features/auth/auth_controller.dart';

class _LoadingAuthController extends AuthController {
  @override
  AuthState build() => const AuthState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash reaches login when signed out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await db.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const WitrackApp(),
      ),
    );

    await tester.pump();
    expect(find.text(AppConstants.brandPrimary), findsWidgets);
    await tester.pump(AppConstants.splashDuration);
    await tester.pumpAndSettle();
    expect(find.text('Login With Portal'), findsOneWidget);
  });

  testWidgets('restored admin follows onboarding and cannot open admin route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    await container.read(authRepositoryProvider).signInLocalAdmin();

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WitrackApp(),
      ),
    );
    await tester.pump();
    await tester.pump(AppConstants.splashDuration);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final router = container.read(routerProvider);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/onboarding/permissions',
    );

    router.go('/app/admin');
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/onboarding/permissions',
    );

    await container
        .read(settingsRepositoryProvider)
        .save(const TrackingSettings(onboardingCompleted: true));
    router.go('/app/admin');
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/app/dashboard',
    );
    expect(find.text('Admin console'), findsNothing);
  });

  testWidgets('restored admin with completed onboarding reaches dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    await container.read(authRepositoryProvider).signInLocalAdmin();
    await container
        .read(settingsRepositoryProvider)
        .save(const TrackingSettings(onboardingCompleted: true));
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WitrackApp(),
      ),
    );
    await tester.pump();
    await tester.pump(AppConstants.splashDuration);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/app/dashboard',
    );
    expect(find.text('Admin console'), findsNothing);
  });

  testWidgets('admin route is blocked while authentication is loading', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        authControllerProvider.overrideWith(_LoadingAuthController.new),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      container.dispose();
      await tester.binding.setSurfaceSize(null);
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WitrackApp(),
      ),
    );
    final router = container.read(routerProvider);
    router.go('/app/admin');
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/app/dashboard',
    );
    expect(find.text('Admin console'), findsNothing);
  });

  for (final role in ['Admin', 'Super Admin', 'Employee', 'Manager']) {
    testWidgets('$role portal login reaches the user flow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      final onboardingCompleted = role != 'Manager';
      await container
          .read(settingsRepositoryProvider)
          .save(TrackingSettings(onboardingCompleted: onboardingCompleted));
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        container.dispose();
        await tester.binding.setSurfaceSize(null);
        await db.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WitrackApp(),
        ),
      );
      await tester.pump();
      await tester.pump(AppConstants.splashDuration);
      await tester.pumpAndSettle();
      expect(find.text('Login With Portal'), findsOneWidget);

      await container
          .read(authControllerProvider.notifier)
          .handlePortalToken(
            'test-token',
            userData: {
              'id': 42,
              'email': 'person@example.com',
              'user_role': {'role_type': role},
            },
          );
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        onboardingCompleted ? '/app/dashboard' : '/onboarding/permissions',
      );
      expect(find.text('Admin console'), findsNothing);
    });
  }
}
