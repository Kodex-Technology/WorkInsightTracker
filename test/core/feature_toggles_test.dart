import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/core/config/feature_catalog.dart';
import 'package:witrack/core/config/feature_toggles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('master tracking core always on even if prefs say false', () async {
    SharedPreferences.setMockInitialValues({
      FeatureId.trackingCore.prefsKey: false,
      FeatureId.calendar.prefsKey: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = FeatureToggleState.fromPrefs(prefs);
    expect(state.isOn(FeatureId.trackingCore), isTrue);
    expect(state.isOn(FeatureId.calendar), isFalse);
  });

  test('copyWithFlag cannot disable master', () {
    const state = FeatureToggleState({});
    final next = state.copyWithFlag(FeatureId.trackingCore, false);
    expect(next.isOn(FeatureId.trackingCore), isTrue);
  });

  test('optional flags default from catalog when unset', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = FeatureToggleState.fromPrefs(prefs);
    expect(state.isOn(FeatureId.confirmTaskSwitch), isTrue);
    expect(state.isOn(FeatureId.backendSync), isFalse);
  });
}
