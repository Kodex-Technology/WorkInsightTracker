import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/data/providers.dart';

/// Runtime feature map. Master ids always resolve to true.
class FeatureToggleState {
  const FeatureToggleState(this._values);

  final Map<FeatureId, bool> _values;

  bool isOn(FeatureId id) {
    if (id.isMaster) return true;
    return _values[id] ?? id.compileDefault;
  }

  FeatureToggleState copyWithFlag(FeatureId id, bool enabled) {
    if (id.isMaster) return this;
    return FeatureToggleState({..._values, id: enabled});
  }

  static FeatureToggleState fromPrefs(SharedPreferences prefs) {
    final map = <FeatureId, bool>{};
    for (final id in FeatureId.values) {
      if (id.isMaster) {
        map[id] = true;
        continue;
      }
      map[id] = prefs.getBool(id.prefsKey) ?? id.compileDefault;
    }
    return FeatureToggleState(map);
  }
}

class FeatureToggleController extends Notifier<FeatureToggleState> {
  @override
  FeatureToggleState build() {
    return FeatureToggleState.fromPrefs(ref.watch(sharedPreferencesProvider));
  }

  Future<void> setEnabled(FeatureId id, bool enabled) async {
    if (id.isMaster) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(id.prefsKey, enabled);
    state = state.copyWithFlag(id, enabled);
  }
}

final featureTogglesProvider =
    NotifierProvider<FeatureToggleController, FeatureToggleState>(
  FeatureToggleController.new,
);
