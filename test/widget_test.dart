import 'package:flutter_test/flutter_test.dart';

import 'package:evim/services/app.dart';

void main() {
  test('money biçimi binlik ayracı koyar', () {
    expect(money(12500), '12.500₺');
    expect(money(0), '0₺');
    expect(money(-1500), '-1.500₺');
  });

  test('dmy gg.aa.yyyy biçimi', () {
    expect(dmy(DateTime(2026, 1, 5)), '05.01.2026');
  });
}
