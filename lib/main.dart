import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/app/witrack_app.dart';
import 'package:witrack/core/config/feature_prefs_repair.dart';
import 'package:witrack/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await repairFeaturePrefsIfMassDisabled(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const WitrackApp(),
    ),
  );
}
