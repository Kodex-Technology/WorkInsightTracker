import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/app/witrack_app.dart';
import 'package:witrack/core/constants/app_constants.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to splash branding', (tester) async {
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
}
