import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/data/providers.dart';

class SidebarCollapsedController extends Notifier<bool> {
  static const _key = 'witrack.ui.sidebarCollapsed';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    await setCollapsed(!state);
  }

  Future<void> setCollapsed(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedController, bool>(
  SidebarCollapsedController.new,
);
