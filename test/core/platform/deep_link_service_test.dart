import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/core/platform/deep_link_service.dart';

void main() {
  group('parsePortalLoginCallback', () {
    test('decodes token and role type from the witrack login URI', () {
      final callback = parsePortalLoginCallback(
        Uri.parse(
          'witrack://login?token=temporary%20token&role_type=Team%20Lead',
        ),
      );

      expect(callback?.token, 'temporary token');
      expect(callback?.roleType, 'Team Lead');
    });

    test('accepts the alternate scheme and a login path', () {
      final callback = parsePortalLoginCallback(
        Uri.parse('workinsighttracker:/login?token=dynamic&role_type=User'),
      );

      expect(callback?.token, 'dynamic');
      expect(callback?.roleType, 'User');
    });

    test('returns a callback with a missing token for the error UI', () {
      final callback = parsePortalLoginCallback(
        Uri.parse('witrack://login?role_type=Admin'),
      );

      expect(callback?.token, isNull);
      expect(callback?.roleType, 'Admin');
    });

    test('ignores unsupported schemes and non-login hosts', () {
      expect(
        parsePortalLoginCallback(Uri.parse('https://login?token=secret')),
        isNull,
      );
      expect(
        parsePortalLoginCallback(Uri.parse('witrack://settings?token=secret')),
        isNull,
      );
    });
  });
}
