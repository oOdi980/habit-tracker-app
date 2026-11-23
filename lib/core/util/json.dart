/// Objek JSON hasil decode.
typedef Json = Map<String, dynamic>;

// Pembantu parsing yang melempar FormatException berpesan jelas (nama field) bila bentuk JSON
// dari server meleset, alih-alih TypeError samar di tengah widget.

Json asJson(Object? value, [String field = 'respons']) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$field bukan objek JSON');
}

List<Json> asJsonList(Object? value, [String field = 'daftar']) {
  if (value is List) return value.map((item) => asJson(item, field)).toList();
  throw FormatException('$field bukan array JSON');
}

int asInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num && value == value.truncate()) return value.toInt();
  throw FormatException('$field bukan bilangan bulat');
}

int? asIntOrNull(Object? value, String field) => value == null ? null : asInt(value, field);

String asString(Object? value, String field) {
  if (value is String) return value;
  throw FormatException('$field bukan teks');
}

String? asStringOrNull(Object? value, String field) => value == null ? null : asString(value, field);

bool asBool(Object? value, String field) {
  if (value is bool) return value;
  throw FormatException('$field bukan boolean');
}
