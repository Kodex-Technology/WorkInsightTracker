import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/core/config/app_env.dart';

void main() {
  test('default development enables local auth and disables Google', () {
    expect(AppEnv.isDevelopment, isTrue);
    expect(AppEnv.allowLocalDevAuth, isTrue);
    expect(AppEnv.enableGoogleAuth, isFalse);
  });

  test(
    'API URL uses build configuration unless a runtime file overrides it',
    () async {
      final originalDirectory = Directory.current;
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'witrack_env_test_',
      );
      addTearDown(() async {
        Directory.current = originalDirectory;
        await temporaryDirectory.delete(recursive: true);
      });
      Directory.current = temporaryDirectory;

      await AppEnv.initialize();
      expect(
        AppEnv.apiBaseUrl,
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://demo.workinsight.net/api/',
        ),
      );

      await File('.env').writeAsString(
        'API_BASE_URL=https://dev.kodextech.com/WorkInsight-Backend-PHP/api\n',
      );
      await AppEnv.initialize();
      expect(
        AppEnv.apiUri('tracker/generate-token').toString(),
        'https://dev.kodextech.com/WorkInsight-Backend-PHP/api/tracker/generate-token',
      );
    },
  );
}
