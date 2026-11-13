import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/core/config/app_env.dart';

void main() {
  test('admin roles expose isAdmin', () {
    expect(AuthRole.admin.isAdmin, isTrue);
    expect(AuthRole.superAdmin.isAdmin, isTrue);
    expect(AuthRole.user.isAdmin, isFalse);
  });
}
