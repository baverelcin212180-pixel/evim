import 'package:supabase_flutter/supabase_flutter.dart';

/// Kısa erişim: Supabase istemcisi.
SupabaseClient get sb => Supabase.instance.client;

String? get myUid => sb.auth.currentUser?.id;

/// Giriş yapan kişinin profili (profiles tablosundan). main/auth doldurur.
Map<String, dynamic> me = {};

/// Uygulama sürümü (main'de ayarlanır) — hata kayıtlarında kullanılır.
String appVersion = '';

String get myName => (me['display_name'] ?? me['username'] ?? '') as String;
String get myRole => (me['role'] ?? 'household') as String;

/// Hangi hane (h1 / h2). Admin'de null → RLS tüm haneleri döndürür.
String? get myHousehold => me['household'] as String?;
bool get isAdmin => myRole == 'admin';

/// Para biçimi (Türkçe, ₺). Örn: 12500 -> 12.500₺
String money(num? n) {
  final v = (n ?? 0).round();
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}${buf.toString()}₺';
}

/// gg.aa.yyyy
String dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

const aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];

String ayAdi(int m) => aylar[(m - 1) % 12];
String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Bugünün YYYY-MM-DD biçimi (kayıt tarihleri için).
String today() => DateTime.now().toIso8601String().substring(0, 10);
