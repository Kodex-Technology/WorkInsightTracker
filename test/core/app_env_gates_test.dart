import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/core/config/app_env.dart';

void main() {
  test('default development enables local auth and disables Google', () {
    expect(AppEnv.isDevelopment, isTrue);
    expect(AppEnv.allowLocalDevAuth, isTrue);
    expect(AppEnv.enableGoogleAuth, isFalse);
  });
}
