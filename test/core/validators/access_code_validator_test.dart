import 'package:cardcipher/bana.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinata_go/core/validators/access_code_validator.dart';

void main() {
  test('3-prefixed creation follows the installed cipher implementation', () {
    expect(
      AccessCodeValidator.isValidBanapassAccessCode('30746056644448171490'),
      BanapassCipher.isAvailable(),
    );
    expect(
      AccessCodeValidator.isValidAimeAccessCode('30746056644448171490'),
      isFalse,
    );
    expect(
      AccessCodeValidator.isValidAimeAccessCode('01234567890123456789'),
      isTrue,
    );
  });

  test('neither library accepts malformed Banapass access codes', () {
    for (final code in <String?>[
      null,
      '',
      '3',
      '30746056644448171491',
      '307460566444481714900',
      '3074605664444817149a',
      '39999999999999999999',
    ]) {
      expect(
        AccessCodeValidator.isValidBanapassAccessCode(code),
        isFalse,
        reason: code,
      );
    }
  });
}
