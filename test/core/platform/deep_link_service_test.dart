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

    test('decodes JSON string in userData parameter', () {
      final uri = Uri.parse(
        'witrack://login?token=validToken&userData=%7B%22email%22%3A%22user%40example.com%22%2C%22first_name%22%3A%22Jane%22%7D',
      );
      final callback = parsePortalLoginCallback(uri);

      expect(callback?.token, 'validToken');
      expect(callback?.userData?['email'], 'user@example.com');
      expect(callback?.userData?['first_name'], 'Jane');
    });

    test(
      'preserves the complete nested user JSON and extracts nested role type',
      () {
        final uri = Uri.parse(
          'witrack://login?token=validToken&userData=%7B%22email%22%3A%22admin%40example.com%22%2C%22first_name%22%3A%22Demo%22%2C%22user_role%22%3A%7B%22role_name%22%3A%22Super%20Admin%22%2C%22role_type%22%3A%22Admin%22%7D%2C%22organization%22%3A%7B%22name%22%3A%22WorkInsight%22%7D%7D',
        );
        final callback = parsePortalLoginCallback(uri);

        expect(callback?.userData?['email'], 'admin@example.com');
        expect(callback?.userData?['organization']['name'], 'WorkInsight');
        expect(callback?.roleType, 'Admin');
      },
    );

    test('rejects malformed userData JSON', () {
      final uri = Uri.parse(
        'witrack://login?token=validToken&userData=%7Bnot-json',
      );

      expect(
        () => parsePortalLoginCallback(uri),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles JS object stringification [object Object] and falls back to top-level params', () {
      final uri = Uri.parse(
        'witrack://login?token=validToken&userData=%5Bobject%20Object%5D&email=fallback%40example.com&name=John%20Doe',
      );
      final callback = parsePortalLoginCallback(uri);

      expect(callback?.token, 'validToken');
      expect(callback?.userData?['email'], 'fallback@example.com');
      expect(callback?.userData?['name'], 'John Doe');
    });

    test('filters out literal undefined or null token values', () {
      final uri = Uri.parse('witrack://login?token=undefined&role_type=User');
      final callback = parsePortalLoginCallback(uri);

      expect(callback?.token, isNull);
      expect(callback?.roleType, 'User');
    });

    test('parses cancelled status and message from portal callback', () {
      final uri = Uri.parse(
        'witrack://login?status=cancelled&message=You%20cancelled%20the%20tracker%20authentication.',
      );
      final callback = parsePortalLoginCallback(uri);

      expect(callback, isNotNull);
      expect(callback?.token, isNull);
      expect(callback?.status, 'cancelled');
      expect(callback?.message, 'You cancelled the tracker authentication.');
      expect(callback?.isCancelled, isTrue);
      expect(callback?.hasToken, isFalse);
    });

    test('handles cancellation through the alternate scheme', () {
      final callback = parsePortalLoginCallback(
        Uri.parse(
          'workinsighttracker://login?status=cancelled&message=cancelled',
        ),
      );

      expect(callback?.isCancelled, isTrue);
      expect(callback?.hasToken, isFalse);
    });

    test(
      'parses error description parameter and detects cancellation keyword',
      () {
        final uri = Uri.parse(
          'witrack://login?error=cancelled&error_description=User%20cancelled%20the%20login%20flow',
        );
        final callback = parsePortalLoginCallback(uri);

        expect(callback, isNotNull);
        expect(callback?.token, isNull);
        expect(callback?.status, 'cancelled');
        expect(callback?.message, 'User cancelled the login flow');
        expect(callback?.isCancelled, isTrue);
      },
    );
  });
}
