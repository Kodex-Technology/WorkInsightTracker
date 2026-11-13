import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/core/config/feature_catalog.dart';

/// One-shot repair when product-name path splits / admin toggles left the UI
/// with every optional module forced off (looks like a "broken" app).
Future<void> repairFeaturePrefsIfMassDisabled(SharedPreferences prefs) async {
  const marker = 'witrack.feature.repaired_v1';
  if (prefs.getBool(marker) == true) return;

  final optional = FeatureId.values.where((id) => !id.isMaster).toList();
  final storedOff = optional
      .where((id) => prefs.containsKey(id.prefsKey) && prefs.getBool(id.prefsKey) == false)
      .length;

  // Mass-disable: most stored flags explicitly false → clear so compile defaults apply.
  if (storedOff >= 4) {
    for (final id in optional) {
      await prefs.remove(id.prefsKey);
    }
  }

  await prefs.setBool(marker, true);
}
