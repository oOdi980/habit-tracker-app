import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/core/util/dates.dart';

void main() {
  group('format tanggal', () {
    test('parseYmd menolak teks yang bukan Y-m-d', () {
      expect(() => parseYmd('8/11/2026'), throwsFormatException);
      expect(() => parseYmd('2026-11-08T10:00:00'), throwsFormatException);
      expect(() => parseYmd(''), throwsFormatException);
    });

    test('hari dan bulan dalam bahasa Indonesia', () {
      // 8 Nov 2026 hari Minggu, 9 Nov Senin.
      expect(formatLongDate('2026-11-08'), 'Minggu, 8 Nov 2026');
      expect(formatLongDate('2026-11-09'), 'Senin, 9 Nov 2026');
      expect(formatShortDate('2026-05-01'), '1 Mei');
      expect(formatShortDate('2026-08-17'), '17 Agu');
      expect(formatShortDate('2026-12-31'), '31 Des');
      expect(formatDayAndShortDate('2026-11-09'), 'Senin, 9 Nov');
    });

    test('rentang minggu satu bulan dan lintas bulan', () {
      expect(formatWeekRange('2026-11-02', '2026-11-08'), '2–8 Nov');
      expect(formatWeekRange('2026-11-30', '2026-12-06'), '30 Nov – 6 Des');
    });

    test('waktu lokal untuk tampilan', () {
      expect(formatLocalDateTime(DateTime(2026, 11, 9, 14, 5)), 'Senin, 9 Nov 14:05');
    });
  });

  group('utcIso8601', () {
    test('format tetap tanpa pecahan detik dan berakhiran Z', () {
      final text = utcIso8601(DateTime.utc(2026, 11, 9, 16, 58, 3, 456, 789));

      expect(text, '2026-11-09T16:58:03Z');
    });

    test('waktu lokal dikonversi ke UTC dan bisa dibaca balik tanpa bergeser', () {
      final local = DateTime(2026, 11, 9, 23, 58, 3); // zona mesin tes, apa pun itu

      final text = utcIso8601(local);

      expect(text, endsWith('Z'));
      expect(DateTime.parse(text).isAtSameMomentAs(local), isTrue);
    });

    test('cocok dengan pola yang diwajibkan server', () {
      // Salinan regex di CheckInRequest.
      final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})$');

      expect(pattern.hasMatch(utcIso8601(DateTime.now())), isTrue);
      expect(pattern.hasMatch(utcIso8601(DateTime.utc(2026, 1, 2, 3, 4, 5))), isTrue);
    });
  });
}
