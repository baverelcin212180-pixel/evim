import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';

/// Offline-first veri katmanı (Elçin'in kanıtlanmış v2 eşitleme motoru).
///
/// Tasarım ilkeleri — eski uygulamalardaki veri kaybı/silme hatalarını kökten çözer:
/// 1. YEREL ÖNCELİK: Sunucuya henüz ONAYLANMAMIŞ yerel değişiklik (kuyruk + gönderilemeyen)
///    sunucudan gelen eski halin ÜSTÜNE biner → silinen kayıt pull'da geri gelmez, yeni kayıt kaybolmaz.
/// 2. GARANTİLİ ÇEKME: Realtime'a güvenmeyiz (ücretsiz planda kopar). Belli aralıkla kesin çekeriz.
/// 3. SON-YAZAN-KAZANIR: İki cihaz aynı kaydı değiştirince updated_at/deleted_at en yenisi kazanır.
/// 4. SİLME = soft delete (deleted_at). Çöp kutusu = deleted_at dolu. Geri al = temizle.
/// 5. Kuyruk kalıcıdır; bağlantı sorununda korunur, kalıcı hata ayrı listeye alınır ama YİNE yerelde korunur.
class Store {
  static const _uuid = Uuid();
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  static final Map<String, ValueNotifier<int>> _ticks = {};
  static List<Map<String, dynamic>> _queue = [];
  static bool _flushing = false;
  static bool _pulling = false;
  static final online = ValueNotifier<bool>(true);
  static final pendingCount = ValueNotifier<int>(0);
  static final failedCount = ValueNotifier<int>(0);
  static final lastSync = ValueNotifier<DateTime?>(null);
  static List<Map<String, dynamic>> _failed = [];
  static SharedPreferences? _prefs;
  static final Map<String, Timer> _pullDebounce = {};
  static final Map<String, RealtimeChannel> _channels = {};
  static Timer? _pullTimer;
  static Timer? _flushTimer;

  /// Tüm veri tabloları (profiles/app_releases ayrı yönetilir).
  static const tables = [
    'incomes', 'expenses', 'savings', 'debts', 'installments', 'work_shifts', 'work_config',
    'change_log', 'app_errors',
  ];

  static ValueNotifier<int> tick(String table) =>
      _ticks.putIfAbsent(table, () => ValueNotifier<int>(0));

  static void _bump(String table) {
    final n = tick(table);
    n.value = n.value + 1;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Cache anahtarı kullanıcıya özel: farklı hane/aynı cihazda karışmasın.
    final scope = myUid ?? 'anon';
    for (final t in tables) {
      final raw = _prefs!.getString('cache:$scope:$t');
      if (raw != null) {
        try {
          _cache[t] = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        } catch (_) {}
      } else {
        _cache[t] = [];
      }
    }
    final q = _prefs!.getString('outbox:$scope');
    if (q != null) {
      try {
        _queue = (jsonDecode(q) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    final fl = _prefs!.getString('failed:$scope');
    if (fl != null) {
      try {
        _failed = (jsonDecode(fl) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    // Açılışta gönderilemeyenleri bir kez daha kuyruğa al (sorun düzelmiş olabilir).
    if (_failed.isNotEmpty) {
      _queue.addAll(_failed);
      _failed = [];
      await _saveQueue();
      await _persistFailed();
    }
    pendingCount.value = _queue.length;
    failedCount.value = _failed.length;

    Connectivity().onConnectivityChanged.listen((r) {
      final up = !r.contains(ConnectivityResult.none);
      online.value = up;
      if (up) {
        flush();
        pullAll();
        _ensureSubscribed();
      }
    });

    // GARANTİ: belli aralıkla kesin gönder + çek. Realtime kopsa bile veri akar.
    _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) => flush());
    _pullTimer = Timer.periodic(const Duration(seconds: 25), (_) => pullAll());

    _ensureSubscribed();
    pullAll();
    flush();
  }

  static String get _scope => myUid ?? 'anon';

  /// Çıkışta timer/kanalları durdur (bellek sızıntısı olmasın).
  static Future<void> dispose() async {
    _pullTimer?.cancel();
    _flushTimer?.cancel();
    for (final c in _channels.values) {
      try {
        await sb.removeChannel(c);
      } catch (_) {}
    }
    _channels.clear();
    _cache.clear();
    _queue = [];
    _failed = [];
  }

  static void _ensureSubscribed() {
    for (final t in tables) {
      if (_channels[t] != null) continue;
      try {
        final ch = sb.channel('rt:$t');
        ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: t,
          callback: (_) => _debouncedPull(t),
        );
        ch.subscribe((status, [err]) {
          if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            _channels.remove(t);
          }
        });
        _channels[t] = ch;
      } catch (_) {
        _channels.remove(t);
      }
    }
  }

  static void _debouncedPull(String t) {
    _pullDebounce[t]?.cancel();
    _pullDebounce[t] = Timer(const Duration(milliseconds: 400), () => pull(t));
  }

  /// Elle "şimdi eşitle".
  static Future<void> forceSync() async {
    _ensureSubscribed();
    await flush();
    await pullAll();
  }

  static Future<void> pullAll() async {
    if (_pulling) return;
    _pulling = true;
    try {
      await Future.wait(tables.map(_pullQuiet));
      lastSync.value = DateTime.now();
    } finally {
      _pulling = false;
    }
  }

  static Future<void> _pullQuiet(String t) async {
    try {
      await pull(t);
    } catch (_) {}
  }

  static Future<void> pull(String t) async {
    try {
      final rows = await sb.from(t).select().timeout(const Duration(seconds: 12));
      _cache[t] = _merge(t, (rows as List).cast<Map<String, dynamic>>());
      await _persist(t);
      _bump(t);
      online.value = true;
    } catch (_) {
      online.value = false;
      rethrow;
    }
  }

  /// Kaydın "sürüm zamanı" — en yeniyi bulmak için (son-yazan-kazanır).
  static int _ver(Map<String, dynamic> r) {
    int ms(dynamic v) {
      if (v == null) return 0;
      try {
        return DateTime.parse(v.toString()).millisecondsSinceEpoch;
      } catch (_) {
        return 0;
      }
    }
    final a = ms(r['updated_at']);
    final b = ms(r['deleted_at']);
    final c = ms(r['created_at']);
    return [a, b, c].reduce((x, y) => x > y ? x : y);
  }

  /// Sunucu satırlarını mevcut yerel + bekleyen + gönderilemeyenle birleştirir (veri kaybını önler).
  static List<Map<String, dynamic>> _merge(String t, List<Map<String, dynamic>> server) {
    final map = <String, Map<String, dynamic>>{};
    for (final r in _cache[t] ?? []) {
      map[r['id'].toString()] = Map<String, dynamic>.from(r);
    }
    for (final r in server) {
      final id = r['id'].toString();
      final existing = map[id];
      if (existing == null || _ver(r) >= _ver(existing)) {
        map[id] = Map<String, dynamic>.from(r);
      }
    }
    for (final item in [..._queue, ..._failed]) {
      if (item['table'] != t) continue;
      if (item['op'] == 'upsert') {
        final row = item['row'] as Map<String, dynamic>;
        map[row['id'].toString()] = Map<String, dynamic>.from(row);
      } else if (item['op'] == 'delete') {
        map.remove(item['id'].toString());
      }
    }
    return map.values.toList();
  }

  static Future<void> _persist(String t) async {
    await _prefs?.setString('cache:$_scope:$t', jsonEncode(_cache[t] ?? []));
  }

  static Future<void> _saveQueue() async {
    await _prefs?.setString('outbox:$_scope', jsonEncode(_queue));
    pendingCount.value = _queue.length;
  }

  static Future<void> _persistFailed() async {
    await _prefs?.setString('failed:$_scope', jsonEncode(_failed));
  }

  // ---- okuma ----

  /// Silinmemiş kayıtlar (isteğe bağlı hane filtresi — admin tüm haneyi görür).
  static List<Map<String, dynamic>> list(String t, {String? household}) =>
      (_cache[t] ?? []).where((r) =>
          r['deleted_at'] == null &&
          (household == null || r['household'] == household)).toList();

  /// Silinmiş kayıtlar (çöp kutusu).
  static List<Map<String, dynamic>> trash(String t, {String? household}) =>
      (_cache[t] ?? []).where((r) =>
          r['deleted_at'] != null &&
          (household == null || r['household'] == household)).toList();

  /// Tüm satırlar (silinmişler dahil).
  static List<Map<String, dynamic>> allRows(String t, {String? household}) =>
      (_cache[t] ?? []).where((r) =>
          household == null || r['household'] == household).toList();

  static Map<String, dynamic>? byId(String t, String id) {
    for (final r in _cache[t] ?? []) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  // ---- yazma ----

  static Future<String> insert(String t, Map<String, dynamic> data,
      {String? summary, bool silentLog = false}) async {
    final id = (data['id'] ?? _uuid.v4()).toString();
    final row = Map<String, dynamic>.from(data);
    row['id'] = id;
    // Hane damgası: RLS with_check için zorunlu. Belirtilmemişse giriş yapanın hanesi.
    row.putIfAbsent('household', () => myHousehold);
    row.putIfAbsent('created_at', () => DateTime.now().toUtc().toIso8601String());
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (t != 'change_log' && t != 'app_errors') row['deleted_at'] = null;
    _cache.putIfAbsent(t, () => []);
    _cache[t]!.removeWhere((r) => r['id'] == id);
    _cache[t]!.add(row);
    await _persist(t);
    _bump(t);
    _enqueue({'op': 'upsert', 'table': t, 'row': row});
    if (t != 'change_log' && t != 'app_errors' && !silentLog) {
      await log('ekle', t, id, summary ?? _summary(t, row));
    }
    return id;
  }

  static Future<void> update(String t, String id, Map<String, dynamic> changes,
      {String? summary, bool silentLog = false}) async {
    final row = byId(t, id);
    if (row == null) return;
    final before = Map<String, dynamic>.from(row);
    row.addAll(changes);
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _persist(t);
    _bump(t);
    _enqueue({'op': 'upsert', 'table': t, 'row': row});
    if (!silentLog && t != 'change_log' && t != 'app_errors') {
      await log('deg', t, id, summary ?? _diffSummary(t, before, changes),
          oldVal: before, newVal: row);
    }
  }

  /// Soft-delete (çöp kutusuna). Haneler ve admin anında siler; geri alınabilir.
  static Future<void> remove(String t, String id, {String? summary}) async {
    final row = byId(t, id);
    if (row == null) return;
    row['deleted_at'] = DateTime.now().toUtc().toIso8601String();
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _persist(t);
    _bump(t);
    _enqueue({'op': 'upsert', 'table': t, 'row': row});
    await log('sil', t, id, summary ?? 'Silindi · ${_summary(t, row)}');
  }

  static Future<void> restore(String t, String id) async {
    final row = byId(t, id);
    if (row == null) return;
    row['deleted_at'] = null;
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _persist(t);
    _bump(t);
    _enqueue({'op': 'upsert', 'table': t, 'row': row});
    await log('geri', t, id, 'Geri alındı · ${_summary(t, row)}');
  }

  /// Kalıcı sil (çöp kutusundan tamamen kaldır) — yalnızca admin kullanır.
  static Future<void> hardRemove(String t, String id) async {
    _cache[t]?.removeWhere((r) => r['id'] == id);
    _queue.removeWhere((i) => i['table'] == t && (i['row']?['id'] == id || i['id'] == id));
    _failed.removeWhere((i) => i['table'] == t && (i['row']?['id'] == id || i['id'] == id));
    await _persist(t);
    await _saveQueue();
    await _persistFailed();
    failedCount.value = _failed.length;
    _bump(t);
    _enqueue({'op': 'delete', 'table': t, 'id': id});
  }

  /// Değişiklik geçmişine kayıt (admin denetimi).
  static Future<void> log(String action, String entity, String? entityId, String summary,
      {Map<String, dynamic>? oldVal, Map<String, dynamic>? newVal}) async {
    final row = {
      'id': _uuid.v4(),
      'actor_id': myUid,
      'actor_name': myName,
      'household': myHousehold,
      'action': action,
      'entity': entity,
      'entity_id': entityId, // TEXT kolon: her değer kabul, asla takılmaz
      'summary': summary,
      'old_value': oldVal,
      'new_value': newVal,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    _cache.putIfAbsent('change_log', () => []);
    _cache['change_log']!.add(row);
    await _persist('change_log');
    _bump('change_log');
    _enqueue({'op': 'upsert', 'table': 'change_log', 'row': row});
  }

  static void _enqueue(Map<String, dynamic> item) {
    _queue.add(item);
    _saveQueue();
    flush();
  }

  static Future<void> flush() async {
    if (_flushing || _queue.isEmpty || sb.auth.currentUser == null) return;
    _flushing = true;
    try {
      var guard = 0;
      while (_queue.isNotEmpty && guard < 1000) {
        guard++;
        final item = _queue.first;
        final t = item['table'] as String;
        try {
          if (item['op'] == 'upsert') {
            await sb.from(t).upsert(item['row']).timeout(const Duration(seconds: 15));
          } else if (item['op'] == 'delete') {
            await sb.from(t).delete().eq('id', item['id']).timeout(const Duration(seconds: 15));
          }
          _queue.removeAt(0);
          await _saveQueue();
        } catch (e) {
          final s = e.toString().toLowerCase();
          // Şema toleransı: 'updated_at' sütunu yoksa o alanı çıkar, tekrar dene.
          if (item['op'] == 'upsert' && s.contains('updated_at') && s.contains('column') &&
              item['row'] is Map && (item['row'] as Map).containsKey('updated_at')) {
            (item['row'] as Map).remove('updated_at');
            await _saveQueue();
            continue;
          }
          if (e is TimeoutException || s.contains('socket') || s.contains('network') ||
              s.contains('host') || s.contains('connection') || s.contains('timeout') ||
              s.contains('failed host') || s.contains('clientexception')) {
            online.value = false; // bağlantı sorunu — kuyruğu KORU, sonra tekrar dene
            break;
          }
          // Kalıcı hata — kaydı ayır ki kuyruğu kilitlemesin (yerelde yine korunur).
          item['_error'] = e.toString();
          item['_failed_at'] = DateTime.now().toUtc().toIso8601String();
          _failed.add(Map<String, dynamic>.from(item));
          failedCount.value = _failed.length;
          _queue.removeAt(0);
          await _saveQueue();
          await _persistFailed();
          reportError('eşitleme', 'Kayıt gönderilemedi: $t', e.toString());
        }
      }
      if (_queue.isEmpty) online.value = true;
    } finally {
      _flushing = false;
    }
  }

  static Future<void> retryFailed() async {
    _queue.addAll(_failed);
    _failed = [];
    failedCount.value = 0;
    await _saveQueue();
    await _persistFailed();
    await flush();
  }

  static List<Map<String, dynamic>> get failed => _failed;

  /// Çalışma zamanı hatasını admin tanılama paneline bildirir.
  static Future<void> reportError(String kind, String message, [String? context]) async {
    try {
      await sb.from('app_errors').insert({
        'household': myHousehold,
        'user_email': sb.auth.currentUser?.email,
        'kind': kind,
        'message': message,
        'context': context,
        'version': appVersion,
      });
    } catch (_) {}
  }

  // ---- özet metinleri (change_log) ----

  static String _summary(String t, Map<String, dynamic> r) {
    switch (t) {
      case 'incomes':
        return 'Gelir · ${r['source'] ?? ''} ${money(r['amount'])}';
      case 'expenses':
        return 'Gider · ${r['category'] ?? ''} ${money(r['amount'])}';
      case 'savings':
        return 'Birikim · ${r['name'] ?? ''}';
      case 'debts':
        return 'Borç · ${r['name'] ?? ''} ${money(r['amount'])}';
      case 'installments':
        return 'Taksit · ${r['name'] ?? ''} ${money(r['amount'])}';
      case 'work_shifts':
        return 'Vardiya · ${r['worker'] ?? ''} ${money(r['earned'])}';
      default:
        return r['name']?.toString() ?? r['title']?.toString() ?? t;
    }
  }

  static String _diffSummary(String t, Map<String, dynamic> before, Map<String, dynamic> changes) {
    final parts = <String>[];
    changes.forEach((k, v) {
      if (k == 'updated_at') return;
      final o = before[k];
      if (o?.toString() != v?.toString()) parts.add('$k: $o → $v');
    });
    final head = _summary(t, before);
    return parts.isEmpty ? head : '$head · ${parts.join(', ')}';
  }
}
