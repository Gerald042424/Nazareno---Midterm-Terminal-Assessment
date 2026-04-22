import 'package:flutter_test/flutter_test.dart';
import 'package:strm/core/utils/validators.dart';

void main() {
  test('email validator accepts valid email', () {
    final String? error = Validators.validateEmail('agent@example.com');
    expect(error, isNull);
  });

  test('password validator rejects weak password', () {
    final String? error = Validators.validatePassword('123');
    expect(error, isNotNull);
  });
}
