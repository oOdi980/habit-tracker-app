// Format tanggal berbahasa Indonesia tanpa paket `intl` (tidak perlu inisialisasi locale).
//
// Server mengirim tanggal sebagai 'Y-m-d' dalam zona waktu SESI. Teks itu sengaja diperlakukan
// sebagai tanggal kalender polos (bukan momen waktu), jadi tidak ada konversi zona di sini.

const List<String> _dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const List<String> _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

final RegExp _ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// 'Y-m-d' menjadi tanggal kalender (jam 00:00 lokal). Teks lain ditolak keras.
DateTime parseYmd(String value) {
  final match = _ymd.firstMatch(value);
  if (match == null) throw FormatException('Tanggal tidak valid: $value');

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String dayName(DateTime date) => _dayNames[date.weekday - 1]; // weekday: 1 = Senin ... 7 = Minggu

/// "Minggu, 8 Nov 2026"
String formatLongDate(String ymd) {
  final d = parseYmd(ymd);
  return '${dayName(d)}, ${d.day} ${_monthNames[d.month - 1]} ${d.year}';
}

/// "8 Nov"
String formatShortDate(String ymd) {
  final d = parseYmd(ymd);
  return '${d.day} ${_monthNames[d.month - 1]}';
}

/// "Senin, 9 Nov"
String formatDayAndShortDate(String ymd) {
  final d = parseYmd(ymd);
  return '${dayName(d)}, ${d.day} ${_monthNames[d.month - 1]}';
}

/// "2–8 Nov" (satu bulan) atau "30 Nov – 6 Des" (lintas bulan).
String formatWeekRange(String startYmd, String endYmd) {
  final s = parseYmd(startYmd);
  final e = parseYmd(endYmd);

  if (s.year == e.year && s.month == e.month) {
    return '${s.day}–${e.day} ${_monthNames[e.month - 1]}';
  }
  return '${s.day} ${_monthNames[s.month - 1]} – ${e.day} ${_monthNames[e.month - 1]}';
}

/// "Senin, 9 Nov 14:30" dalam zona waktu perangkat.
String formatLocalDateTime(DateTime moment) {
  final local = moment.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${dayName(local)}, ${local.day} ${_monthNames[local.month - 1]} $hh:$mm';
}

/// Waktu ISO-8601 UTC tanpa pecahan detik, mis. "2026-11-09T16:58:03Z".
/// Server mewajibkan zona eksplisit dan menolak yang ambigu; toIso8601String() milik Dart untuk
/// waktu lokal TIDAK menyertakan zona, dan di mobile menambah mikrodetik, jadi dirakit manual.
String utcIso8601(DateTime moment) {
  final u = moment.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');

  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
      'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
}
