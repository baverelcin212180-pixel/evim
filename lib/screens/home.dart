import 'package:flutter/material.dart';

import '../services/app.dart';
import '../services/settings.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Taksit/ödeme ekranındaki hazır ödeme ön-tanımları (isim, tür).
/// Dokununca ismi+türü doldurur; istenirse ad elle de yazılır.
const _odemePresetleri = <(String, String)>[
  ('Elektrik', 'fatura'), ('Su', 'fatura'), ('Doğalgaz', 'fatura'),
  ('İnternet', 'fatura'), ('Telefon', 'fatura'), ('Aidat', 'fatura'),
  ('Tivibu', 'abonelik'), ('Netflix', 'abonelik'), ('Spotify', 'abonelik'),
  ('YouTube', 'abonelik'), ('Disney+', 'abonelik'), ('Exxen', 'abonelik'),
  ('BluTV', 'abonelik'), ('Amazon Prime', 'abonelik'), ('Spor salonu', 'abonelik'),
  ('TOKİ', 'toki'), ('Kira', 'kira'), ('Sigorta', 'fatura'), ('Okul', 'diger'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'ozet';
  String _mesaiView = 'takvim';
  final t = appTheme();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        Store.tick('incomes'), Store.tick('expenses'), Store.tick('savings'),
        Store.tick('debts'), Store.tick('installments'), Store.tick('work_shifts'), Store.tick('work_config'), Settings.changed,
      ]),
      builder: (context, _) {
        Widget body;
        switch (_tab) {
          case 'akis':
            body = _gelirGider();
            break;
          case 'mesai':
            body = _mesai();
            break;
          case 'taksit':
            body = _taksit();
            break;
          case 'borc':
            body = _borc();
            break;
          case 'birikim':
            body = _birikim();
            break;
          default:
            body = _ozet();
        }
        return Column(children: [Expanded(child: body), _nav()]);
      },
    );
  }

  // ---- hesaplar ----
  bool _thisMonth(dynamic date) {
    final d = parseDate(date);
    final n = DateTime.now();
    return d != null && d.month == n.month && d.year == n.year;
  }

  num get _income => Store.list('incomes').where((r) => _thisMonth(r['inc_date'])).fold<num>(0, (s, r) => s + (r['amount'] as num? ?? 0));
  num get _workIncome => Store.list('work_shifts').where((r) => _thisMonth(r['work_date'])).fold<num>(0, (s, r) => s + (r['earned'] as num? ?? 0));
  num get _totalIncome => _income + _workIncome;
  num get _expense => Store.list('expenses').where((r) => _thisMonth(r['exp_date'])).fold<num>(0, (s, r) => s + (r['amount'] as num? ?? 0));

  List<Map<String, dynamic>> get _activeInstallments => Store.list('installments').where((l) {
        final tc = (l['total_count'] as num? ?? 0);
        final pc = (l['paid_count'] as num? ?? 0);
        return tc == 0 || pc < tc;
      }).toList();

  num get _installmentDue => _activeInstallments.fold<num>(0, (s, l) => s + (l['amount'] as num? ?? 0));

  // ---------- ÖZET ----------
  Widget _ozet() {
    final now = DateTime.now();
    final gelir = _totalIncome;
    final gider = _expense + _installmentDue;
    final net = gelir - gider;
    final paidCount = _activeInstallments.where((l) => l['paid_month'] == monthKey(now)).length;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [t.accent, t.accent2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${ayAdi(now.month).toUpperCase()} · AY SONU KALAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, color: t.on)),
          const SizedBox(height: 6),
          Text(money(net), style: t.displayStyle(50, color: t.on)),
          const SizedBox(height: 10),
          Row(children: [
            _mini('Gelir', money(gelir)),
            const SizedBox(width: 20),
            _mini('Gider', money(gider)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: StatTile(t, label: 'Bu ay gelir', value: money(gelir), valueColor: t.accent2)),
        const SizedBox(width: 10),
        Expanded(child: StatTile(t, label: 'Bu ay gider', value: money(gider), valueColor: t.danger)),
      ]),
      const SizedBox(height: 14),
      Card2(t, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Bu ay ödenecek taksitler', style: t.bodyStyle(15, weight: FontWeight.w800)),
          Text('${_activeInstallments.length} kalem · $paidCount ödendi', style: t.bodyStyle(12, color: t.muted)),
        ]),
        const SizedBox(height: 6),
        if (_activeInstallments.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: GhostBtn(t, '+ Taksit / kredi ekle', onTap: _addInstallment)),
        ..._activeInstallments.map((l) {
          final paid = l['paid_month'] == monthKey(now);
          return InkWell(
            onTap: () => _togglePay(l),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
              Container(width: 26, height: 26, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: paid ? t.accent2 : Colors.transparent, border: Border.all(color: paid ? t.accent2 : t.muted, width: 2)), child: paid ? Icon(Icons.check, size: 16, color: t.on) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((l['name'] ?? '').toString(), style: t.bodyStyle(15, weight: FontWeight.w700)),
                Text('${l['day_of_month'] ?? 1}. gün${paid ? ' · ödendi' : ''}', style: t.bodyStyle(12, color: t.muted)),
              ])),
              Text(money(l['amount'] as num?), style: t.bodyStyle(15, weight: FontWeight.w800)),
            ])),
          );
        }),
      ])),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: GhostBtn(t, '+ Gelir', icon: Icons.add, tint: t.accent2, onTap: _addIncome)),
        const SizedBox(width: 8),
        Expanded(child: GhostBtn(t, '+ Gider', icon: Icons.remove, tint: t.danger, onTap: _addExpense)),
      ]),
      const SizedBox(height: 10),
      _recentExpenses(now),
    ]);
  }

  Widget _mini(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.on.withValues(alpha: 0.8))),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.on)),
      ]);

  Widget _recentExpenses(DateTime now) {
    final exps = Store.list('expenses').where((e) => _thisMonth(e['exp_date'])).toList()
      ..sort((a, b) => (b['exp_date'] ?? '').toString().compareTo((a['exp_date'] ?? '').toString()));
    if (exps.isEmpty) return const SizedBox.shrink();
    return Card2(t, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Son giderler', style: t.bodyStyle(15, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      ...exps.take(6).map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        Expanded(child: Text('${e['category'] ?? ''} · ${dmy(parseDate(e['exp_date']) ?? now)}', style: t.bodyStyle(14))),
        Text('− ${money(e['amount'] as num?)}', style: t.bodyStyle(14, color: t.danger, weight: FontWeight.w700)),
        _del('expenses', e['id'] as String, 'Gider'),
      ]))),
    ]));
  }

  // ---------- GELİR / GİDER ----------
  Widget _gelirGider() {
    final now = DateTime.now();
    final items = <Map<String, dynamic>>[];
    for (final r in Store.list('incomes').where((e) => _thisMonth(e['inc_date']))) {
      items.add({'d': r['inc_date'], 'kind': 'inc', 'title': _incLabel(r), 'amt': r['amount'], 'id': r['id'], 'table': 'incomes'});
    }
    for (final r in Store.list('expenses').where((e) => _thisMonth(e['exp_date']))) {
      items.add({'d': r['exp_date'], 'kind': 'exp', 'title': '${r['category'] ?? 'Gider'}${(r['note'] ?? '').toString().isNotEmpty ? ' · ${r['note']}' : ''}', 'amt': r['amount'], 'id': r['id'], 'table': 'expenses'});
    }
    items.sort((a, b) => (b['d'] ?? '').toString().compareTo((a['d'] ?? '').toString()));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      ScreenTitle(t, 'Gelir & Gider', sub: ayAdi(now.month)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatTile(t, label: 'Gelir', value: money(_totalIncome), valueColor: t.accent2)),
        const SizedBox(width: 10),
        Expanded(child: StatTile(t, label: 'Gider', value: money(_expense), valueColor: t.danger)),
      ]),
      if (_workIncome > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Gelire mesai dahildir: ${money(_workIncome)} (Mesai sekmesi)', style: t.bodyStyle(12, color: t.muted))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: PrimaryBtn(t, 'Gelir ekle', icon: Icons.add, onTap: _addIncome)),
        const SizedBox(width: 10),
        Expanded(child: GhostBtn(t, 'Gider ekle', icon: Icons.remove, tint: t.danger, onTap: _addExpense)),
      ]),
      const SizedBox(height: 12),
      if (items.isEmpty) emptyState(t, Icons.receipt_long, 'Bu ay henüz kayıt yok.\nGelir ya da gider ekle.'),
      ...items.map((it) => Card2(t, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: (it['kind'] == 'inc' ? t.accent2 : t.danger).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(it['kind'] == 'inc' ? Icons.south_west : Icons.north_east, color: it['kind'] == 'inc' ? t.accent2 : t.danger, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it['title'].toString(), style: t.bodyStyle(14, weight: FontWeight.w700)),
          Text(dmy(parseDate(it['d']) ?? now), style: t.bodyStyle(12, color: t.muted)),
        ])),
        Text('${it['kind'] == 'inc' ? '+' : '−'} ${money(it['amt'] as num?)}', style: t.bodyStyle(15, color: it['kind'] == 'inc' ? t.accent2 : t.danger, weight: FontWeight.w800)),
        _del(it['table'] as String, it['id'] as String, it['title'].toString()),
      ]))).expand((w) => [w, const SizedBox(height: 10)]),
    ]);
  }

  String _incLabel(Map<String, dynamic> r) {
    const names = {'maas': 'Maaş', 'yardim': 'Yardım', 'kira': 'Kira geliri', 'diger': 'Diğer gelir'};
    final base = names[r['source']] ?? 'Gelir';
    final note = (r['note'] ?? '').toString();
    return note.isNotEmpty ? '$base · $note' : base;
  }

  // ---------- TAKSİT ----------
  Widget _taksit() {
    final list = Store.list('installments');
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ScreenTitle(t, 'Taksitler'),
        GhostBtn(t, '+ Ekle', onTap: _addInstallment),
      ]),
      const SizedBox(height: 6),
      Text('Aylık toplam taksit: ${money(_installmentDue)}', style: t.bodyStyle(13, color: t.muted)),
      const SizedBox(height: 12),
      if (list.isEmpty) emptyState(t, Icons.credit_card, 'Taksit/kredi yok.\nTOKİ, kira, kredi veya kart ekleyebilirsin.'),
      ...list.map((l) {
        final tc = (l['total_count'] as num? ?? 0);
        final pc = (l['paid_count'] as num? ?? 0);
        final kalan = tc > 0 ? (tc - pc) : null;
        final totalDebt = (l['total_debt'] as num? ?? 0);
        final paidDebt = (l['paid_debt'] as num? ?? 0);
        final paidNow = l['paid_month'] == monthKey(DateTime.now());
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Card2(t, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(8)), child: Text(_kindName(l['kind']), style: t.bodyStyle(11, color: t.muted, weight: FontWeight.w700))),
              const SizedBox(width: 8),
              Text((l['name'] ?? '').toString(), style: t.bodyStyle(16, weight: FontWeight.w800)),
            ]),
            Text(money(l['amount'] as num?), style: t.bodyStyle(16, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          if (tc > 0) ...[
            Bar(t, tc > 0 ? (pc / tc).clamp(0.0, 1.0) : 0, color: t.accent2, height: 10),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$pc / $tc taksit ödendi', style: t.bodyStyle(13, color: t.muted)),
              if (kalan != null) Text('$kalan kaldı', style: t.bodyStyle(13, color: t.muted)),
            ]),
          ],
          if (totalDebt > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Kalan borç ${money(totalDebt - paidDebt)} / ${money(totalDebt)}', style: t.bodyStyle(13, color: t.muted))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: paidNow
                ? GhostBtn(t, 'Bu ay ödendi ✓', tint: t.accent2, onTap: () => _togglePay(l))
                : PrimaryBtn(t, 'Bu ay ödendi işaretle', onTap: () => _togglePay(l))),
          ]),
          Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(onPressed: () => _editInstallment(l), child: Text('Düzenle', style: TextStyle(color: t.accent))),
            _del('installments', l['id'] as String, 'Taksit · ${l['name']}'),
          ])),
        ])));
      }),
    ]);
  }

  String _kindName(dynamic k) {
    const m = {'toki': 'TOKİ', 'kira': 'Kira', 'kredi': 'Kredi', 'kart': 'Kart', 'fatura': 'Fatura', 'abonelik': 'Abonelik', 'diger': 'Diğer'};
    return m[k] ?? 'Ödeme';
  }

  Future<void> _togglePay(Map<String, dynamic> l) async {
    final mk = monthKey(DateTime.now());
    final paid = l['paid_month'] != mk;
    final changes = <String, dynamic>{'paid_month': paid ? mk : null};
    final pc = (l['paid_count'] as num? ?? 0);
    final amt = (l['amount'] as num? ?? 0);
    final pd = (l['paid_debt'] as num? ?? 0);
    if (paid) {
      changes['paid_count'] = pc + 1;
      changes['paid_debt'] = pd + amt;
    } else {
      changes['paid_count'] = (pc - 1).clamp(0, 1 << 31);
      changes['paid_debt'] = (pd - amt).clamp(0, 1 << 52);
    }
    await Store.update('installments', l['id'] as String, changes, summary: '${l['name']} ${paid ? 'ödendi' : 'geri alındı'}');
  }

  // ---------- BORÇ ----------
  String _debtTab = 'bize';
  Widget _borc() {
    final list = Store.list('debts').where((d) => (d['direction'] ?? 'bize') == _debtTab).toList();
    final total = list.fold<num>(0, (s, d) => s + ((d['amount'] as num? ?? 0) - (d['paid'] as num? ?? 0)));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ScreenTitle(t, 'Borç defteri'),
        GhostBtn(t, '+ Ekle', onTap: _addDebt),
      ]),
      const SizedBox(height: 12),
      Segmented(t, items: const [('bize', 'Bize borçlu'), ('biz', 'Bizim borcumuz')], value: _debtTab, onChanged: (v) => setState(() => _debtTab = v)),
      const SizedBox(height: 12),
      StatTile(t, label: _debtTab == 'bize' ? 'Alacağımız toplam' : 'Borcumuz toplam', value: money(total), valueColor: _debtTab == 'bize' ? t.accent2 : t.danger),
      const SizedBox(height: 12),
      if (list.isEmpty) emptyState(t, Icons.menu_book, 'Kayıt yok.'),
      ...list.map((d) {
        final kalan = (d['amount'] as num? ?? 0) - (d['paid'] as num? ?? 0);
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Card2(t, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text((d['name'] ?? '').toString(), style: t.bodyStyle(16, weight: FontWeight.w800))),
            Text(money(kalan), style: t.displayStyle(20, color: _debtTab == 'bize' ? t.accent2 : t.danger)),
          ]),
          Text('${d['debt_date'] != null ? dmy(parseDate(d['debt_date'])!) : ''} · toplam ${money(d['amount'] as num?)}${(d['paid'] as num? ?? 0) > 0 ? ', ödenen ${money(d['paid'] as num?)}' : ''}', style: t.bodyStyle(12, color: t.muted)),
          if ((d['note'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(d['note'].toString(), style: t.bodyStyle(12, color: t.muted))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: PrimaryBtn(t, 'Ödeme al/ver', onTap: () => _debtPay(d, kalan))),
            const SizedBox(width: 8),
            _del('debts', d['id'] as String, 'Borç · ${d['name']}'),
          ]),
        ])));
      }),
    ]);
  }

  Future<void> _debtPay(Map<String, dynamic> d, num kalan) async {
    final v = await _numInput('Ödenen miktar (₺)', initial: kalan);
    if (v == null) return;
    final newPaid = (d['paid'] as num? ?? 0) + v;
    if (newPaid >= (d['amount'] as num? ?? 0)) {
      await Store.update('debts', d['id'] as String, {'paid': d['amount']}, summary: 'Borç kapandı · ${d['name']}');
      await Store.remove('debts', d['id'] as String, summary: 'Borç kapandı · ${d['name']}');
      if (mounted) toast(context, 'Borç tamamen kapandı');
    } else {
      await Store.update('debts', d['id'] as String, {'paid': newPaid}, summary: 'Ödeme · ${d['name']} ${money(v)}');
    }
  }

  // ---------- BİRİKİM ----------
  Widget _birikim() {
    final list = Store.list('savings');
    final total = list.fold<num>(0, (s, g) => s + (g['saved'] as num? ?? 0));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ScreenTitle(t, 'Birikim'),
        GhostBtn(t, '+ Hedef', onTap: _addSaving),
      ]),
      const SizedBox(height: 12),
      StatTile(t, label: 'Toplam birikim', value: money(total), valueColor: t.accent),
      const SizedBox(height: 12),
      if (list.isEmpty) emptyState(t, Icons.savings, 'Birikim hedefi yok.\nÖrn. Araba, Tatil, Acil fon.'),
      ...list.map((g) {
        final target = (g['target'] as num? ?? 0).toDouble();
        final saved = (g['saved'] as num? ?? 0).toDouble();
        final p = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Card2(t, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text((g['name'] ?? '').toString(), style: t.bodyStyle(16, weight: FontWeight.w800)),
            Text('%${(p * 100).round()}', style: t.bodyStyle(14, color: t.accent, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Bar(t, p, color: t.accent, height: 12),
          const SizedBox(height: 6),
          Text(target > 0 ? '${money(saved)} / ${money(target)}' : money(saved), style: t.bodyStyle(13, color: t.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: PrimaryBtn(t, 'Para ekle/çıkar', onTap: () => _editSaving(g))),
            const SizedBox(width: 8),
            _del('savings', g['id'] as String, 'Birikim · ${g['name']}'),
          ]),
        ])));
      }),
    ]);
  }

  // ---------- MESAİ / VARDİYA ----------
  static const _workers = ['Mustafa', 'Bünyamin'];

  int? _parseHm(dynamic v) {
    if (v == null) return null;
    final parts = v.toString().trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  double _hoursOf(dynamic start, dynamic end, dynamic breakMin) {
    final s = _parseHm(start);
    final e = _parseHm(end);
    if (s == null || e == null) return 0;
    var mins = e - s;
    if (mins <= 0) mins += 24 * 60; // gece vardiyası (ertesi gün)
    mins -= ((breakMin is num ? breakMin : num.tryParse('$breakMin') ?? 0)).toInt();
    return mins <= 0 ? 0 : mins / 60.0;
  }

  double _shiftHours(Map<String, dynamic> r) => _hoursOf(r['start_time'], r['end_time'], r['break_min']);

  double _earnOf(double hours, num hourly, num otAfter, num otMult) {
    final normal = hours <= otAfter ? hours : otAfter.toDouble();
    final ot = hours > otAfter ? hours - otAfter : 0.0;
    return normal * hourly + ot * hourly * otMult;
  }

  Map<String, dynamic>? _cfg() {
    final l = Store.list('work_config');
    return l.isNotEmpty ? l.first : null;
  }

  bool _allWagesZero(Map<String, dynamic> c) =>
      (c['normal_wage'] as num? ?? 0) == 0 && (c['mesai_wage'] as num? ?? 0) == 0 &&
      (c['sabah_wage'] as num? ?? 0) == 0 && (c['yarim_wage'] as num? ?? 0) == 0;

  Color _dayTypeColor(String? type) {
    switch (type) {
      case 'normal': return t.accent2;
      case 'mesai': return t.accent;
      case 'sabah': return t.danger;
      case 'yarim': return t.muted;
      default: return t.accent;
    }
  }

  String _dayTypeName(String? type) {
    switch (type) {
      case 'normal': return 'Mesaisiz';
      case 'mesai': return 'Mesaili';
      case 'sabah': return 'Sabahlama';
      case 'yarim': return 'Yarım gün';
      default: return 'Vardiya';
    }
  }

  Widget _mesai() {
    final now = DateTime.now();
    final shifts = Store.list('work_shifts').where((r) => _thisMonth(r['work_date'])).toList();
    final totalHours = shifts.fold<double>(0, (s, r) => s + _shiftHours(r));
    final totalEarn = shifts.fold<num>(0, (s, r) => s + (r['earned'] as num? ?? 0));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            ScreenTitle(t, 'Mesai', sub: ayAdi(now.month)),
            IconButton(onPressed: _workSettings, icon: Icon(Icons.settings, color: t.muted), tooltip: 'Günlük ücret ayarları'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: StatTile(t, label: 'Bu ay gün/saat', value: '${shifts.length} gün', valueColor: t.accent)),
            const SizedBox(width: 10),
            Expanded(child: StatTile(t, label: 'Bu ay kazanç', value: money(totalEarn), valueColor: t.accent2)),
          ]),
          if (totalHours > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Saatli vardiyalar: ${totalHours.toStringAsFixed(1)} saat', style: t.bodyStyle(12, color: t.muted))),
          const SizedBox(height: 10),
          Segmented(t, items: const [('takvim', 'Takvim'), ('liste', 'Liste')], value: _mesaiView, onChanged: (v) => setState(() => _mesaiView = v)),
          const SizedBox(height: 10),
        ]),
      ),
      Expanded(child: _mesaiView == 'liste' ? _mesaiListe(now) : _mesaiTakvim(now)),
    ]);
  }

  Widget _mesaiTakvim(DateTime now) {
    final cfg = _cfg();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final first = DateTime(now.year, now.month, 1);
    final lead = (first.weekday + 6) % 7; // Pazartesi = 0
    final byDay = <int, Map<String, dynamic>>{};
    for (final r in Store.list('work_shifts')) {
      final d = parseDate(r['work_date']);
      if (d != null && d.month == now.month && d.year == now.year) byDay[d.day] = r;
    }
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final r = byDay[day];
      final col = r == null ? null : _dayTypeColor(r['day_type'] as String?);
      final isToday = day == now.day;
      cells.add(InkWell(
        onTap: () => _dayQuick(DateTime(now.year, now.month, day), r),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: col?.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isToday ? t.accent : t.border, width: isToday ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: t.bodyStyle(14, weight: FontWeight.w700, color: col ?? t.text)),
            if (r != null) Container(margin: const EdgeInsets.only(top: 3), width: 6, height: 6, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          ]),
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      if (cfg == null || _allWagesZero(cfg)) _wageHint(),
      Card2(t, child: Column(children: [
        Row(children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((d) => Expanded(child: Center(child: Text(d, style: t.bodyStyle(11, color: t.muted, weight: FontWeight.w700))))).toList()),
        const SizedBox(height: 8),
        GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: 0.82, children: cells),
      ])),
      const SizedBox(height: 12),
      Card2(t, child: Wrap(spacing: 14, runSpacing: 8, children: const [('normal', 'Mesaisiz'), ('mesai', 'Mesaili'), ('sabah', 'Sabahlama'), ('yarim', 'Yarım')].map((x) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: _dayTypeColor(x.$1), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(x.$2, style: t.bodyStyle(12, color: t.muted)),
      ])).toList())),
    ]);
  }

  Widget _mesaiListe(DateTime now) {
    final shifts = Store.list('work_shifts').where((r) => _thisMonth(r['work_date'])).toList()
      ..sort((a, b) => (b['work_date'] ?? '').toString().compareTo((a['work_date'] ?? '').toString()));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      PrimaryBtn(t, '+ Vardiya (giriş-çıkış saatiyle)', icon: Icons.more_time, onTap: _addShift),
      const SizedBox(height: 12),
      if (shifts.isEmpty) emptyState(t, Icons.schedule, 'Bu ay vardiya yok.\nTakvimden hızlı işaretle ya da giriş-çıkış saatiyle ekle.'),
      ...shifts.map((r) {
        final hasTime = (r['start_time'] ?? '').toString().isNotEmpty;
        final hrs = _shiftHours(r);
        final br = (r['break_min'] as num? ?? 0);
        final sub = hasTime
            ? '${r['start_time']}–${r['end_time']}${br > 0 ? ' · ${br.toInt()}dk' : ''} · ${hrs.toStringAsFixed(1)} saat'
            : _dayTypeName(r['day_type'] as String?);
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card2(t, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: _dayTypeColor(r['day_type'] as String?).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.schedule, color: _dayTypeColor(r['day_type'] as String?), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['worker'] ?? ''} · ${dmy(parseDate(r['work_date']) ?? now)}', style: t.bodyStyle(14, weight: FontWeight.w700)),
            Text(sub, style: t.bodyStyle(12, color: t.muted)),
          ])),
          Text(money(r['earned'] as num?), style: t.bodyStyle(15, color: t.accent2, weight: FontWeight.w800)),
          _del('work_shifts', r['id'] as String, 'Vardiya'),
        ])));
      }),
    ]);
  }

  Widget _wageHint() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: _workSettings,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.warn.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: t.warn.withValues(alpha: 0.4))),
            child: Row(children: [
              Icon(Icons.info_outline, color: t.warn, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Takvimden hızlı işaretlemek için önce günlük ücretleri ayarla (dişli).', style: t.bodyStyle(13))),
            ]),
          ),
        ),
      );

  Future<void> _dayQuick(DateTime date, Map<String, dynamic>? existing) async {
    final cfg = _cfg();
    if (cfg == null || _allWagesZero(cfg)) {
      await _workSettings();
      return;
    }
    await openSheet(context, t, (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${date.day} ${ayAdi(date.month)}', style: t.displayStyle(22)),
      const SizedBox(height: 4),
      Text('Gün tipini seç — kazanç otomatik gelire yazılır.', style: t.bodyStyle(12, color: t.muted)),
      const SizedBox(height: 14),
      _quickBtn(c, date, 'normal', 'Mesaisiz', cfg['normal_wage']),
      _quickBtn(c, date, 'mesai', 'Mesaili', cfg['mesai_wage']),
      _quickBtn(c, date, 'sabah', 'Sabahlama', cfg['sabah_wage']),
      _quickBtn(c, date, 'yarim', 'Yarım gün', cfg['yarim_wage']),
      if (existing != null) Padding(padding: const EdgeInsets.only(top: 6), child: GhostBtn(t, 'Bu günü temizle', icon: Icons.clear, tint: t.danger, onTap: () async {
        Navigator.pop(c);
        await _clearDay(date);
      })),
    ]));
  }

  Widget _quickBtn(BuildContext c, DateTime date, String type, String label, dynamic wage) {
    final w = (wage as num? ?? 0);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(
      onTap: () async {
        Navigator.pop(c);
        await _setDay(date, type, w);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(color: _dayTypeColor(type).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: _dayTypeColor(type).withValues(alpha: 0.5))),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: _dayTypeColor(type), shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: t.bodyStyle(15, weight: FontWeight.w700))),
          Text(money(w), style: t.bodyStyle(15, weight: FontWeight.w800, color: t.accent2)),
        ]),
      ),
    ));
  }

  Future<void> _setDay(DateTime date, String type, num wage) async {
    final cfg = _cfg();
    final worker = (cfg?['worker'] ?? (myHousehold == 'h1' ? 'Mustafa' : 'Bünyamin')).toString();
    final ds = date.toIso8601String().substring(0, 10);
    Map<String, dynamic>? existing;
    for (final r in Store.list('work_shifts')) {
      if (r['work_date']?.toString().substring(0, 10) == ds) {
        existing = r;
        break;
      }
    }
    final data = {'work_date': ds, 'worker': worker, 'day_type': type, 'earned': wage, 'start_time': null, 'end_time': null, 'break_min': 0};
    if (existing != null) {
      await Store.update('work_shifts', existing['id'] as String, data, summary: 'Vardiya · $worker ${_dayTypeName(type)} ${money(wage)}');
    } else {
      await Store.insert('work_shifts', data, summary: 'Vardiya · $worker ${_dayTypeName(type)} ${money(wage)}');
    }
    if (mounted) toast(context, '${_dayTypeName(type)} · ${money(wage)} gelire yazıldı');
  }

  Future<void> _clearDay(DateTime date) async {
    final ds = date.toIso8601String().substring(0, 10);
    for (final r in Store.list('work_shifts')) {
      if (r['work_date']?.toString().substring(0, 10) == ds) {
        await Store.remove('work_shifts', r['id'] as String, summary: 'Vardiya silindi');
      }
    }
    if (mounted) toast(context, 'Gün temizlendi');
  }

  Future<void> _workSettings() async {
    final cfg = _cfg();
    String wageText(String k) {
      final v = cfg?[k] as num?;
      return (v == null || v == 0) ? '' : v.round().toString();
    }
    final workerCtrl = TextEditingController(text: (cfg?['worker'] ?? (myHousehold == 'h1' ? 'Mustafa' : 'Bünyamin')).toString());
    final normalCtrl = TextEditingController(text: wageText('normal_wage'));
    final mesaiCtrl = TextEditingController(text: wageText('mesai_wage'));
    final sabahCtrl = TextEditingController(text: wageText('sabah_wage'));
    final yarimCtrl = TextEditingController(text: wageText('yarim_wage'));
    Widget wf(TextEditingController cc, String hint) => TextField(controller: cc, keyboardType: TextInputType.number, style: TextStyle(color: t.text), decoration: fieldDeco(t, hint));
    final ok = await openSheet<bool>(context, t, (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mesai ayarları', style: t.displayStyle(22)),
      const SizedBox(height: 4),
      Text('Takvimde güne dokununca bu günlük ücretler yazılır.', style: t.bodyStyle(12, color: t.muted)),
      const SizedBox(height: 14),
      wf(workerCtrl, 'Çalışan adı'),
      const SizedBox(height: 10),
      wf(normalCtrl, 'Mesaisiz gün (₺)'),
      const SizedBox(height: 10),
      wf(mesaiCtrl, 'Mesaili gün (₺)'),
      const SizedBox(height: 10),
      wf(sabahCtrl, 'Sabahlama (₺)'),
      const SizedBox(height: 10),
      wf(yarimCtrl, 'Yarım gün (₺)'),
      const SizedBox(height: 14),
      PrimaryBtn(t, 'Kaydet', onTap: () => Navigator.pop(c, true)),
    ]));
    if (ok != true) return;
    num p(TextEditingController cc) => num.tryParse(cc.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final data = {
      'worker': workerCtrl.text.trim(),
      'normal_wage': p(normalCtrl), 'mesai_wage': p(mesaiCtrl),
      'sabah_wage': p(sabahCtrl), 'yarim_wage': p(yarimCtrl),
    };
    if (cfg != null) {
      await Store.update('work_config', cfg['id'] as String, data, summary: 'Mesai ayarları güncellendi');
    } else {
      await Store.insert('work_config', data, summary: 'Mesai ayarları');
    }
    if (mounted) toast(context, 'Kaydedildi');
  }

  Future<void> _addShift() async {
    final existing = Store.list('work_shifts')..sort((a, b) => (b['work_date'] ?? '').toString().compareTo((a['work_date'] ?? '').toString()));
    final lastHourly = existing.isNotEmpty ? (existing.first['hourly'] as num? ?? 0) : 0;
    final lastOtAfter = existing.isNotEmpty ? (existing.first['ot_after'] as num? ?? 8) : 8;
    final lastOtMult = existing.isNotEmpty ? (existing.first['ot_mult'] as num? ?? 1.5) : 1.5;
    String worker = myHousehold == 'h1' ? 'Mustafa' : 'Bünyamin';
    DateTime date = DateTime.now();
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '18:00');
    final breakCtrl = TextEditingController(text: '0');
    final hourlyCtrl = TextEditingController(text: lastHourly > 0 ? lastHourly.round().toString() : '');
    final otAfterCtrl = TextEditingController(text: lastOtAfter.toString());
    final otMultCtrl = TextEditingController(text: lastOtMult.toString());
    bool advanced = false;

    final ok = await openSheet<bool>(context, t, (c) => StatefulBuilder(builder: (c, setSt) {
      final hrs = _hoursOf(startCtrl.text, endCtrl.text, int.tryParse(breakCtrl.text) ?? 0);
      final hourly = num.tryParse(hourlyCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final otA = num.tryParse(otAfterCtrl.text.replaceAll(',', '.')) ?? 8;
      final otM = num.tryParse(otMultCtrl.text.replaceAll(',', '.')) ?? 1.5;
      final earn = _earnOf(hrs, hourly, otA, otM);
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vardiya ekle', style: t.displayStyle(24)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: _workers.map((w) => Pill(t, w, on: worker == w, onTap: () => setSt(() => worker = w))).toList()),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2023), lastDate: DateTime(2100));
            if (d != null) setSt(() => date = d);
          },
          child: Container(
            height: 50, padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
            child: Row(children: [Icon(Icons.calendar_today, size: 18, color: t.muted), const SizedBox(width: 10), Text('Tarih: ${dmy(date)}', style: t.bodyStyle(15))]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: startCtrl, keyboardType: TextInputType.datetime, onChanged: (_) => setSt(() {}), style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Giriş (09:00)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: endCtrl, keyboardType: TextInputType.datetime, onChanged: (_) => setSt(() {}), style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Çıkış (18:00)'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: breakCtrl, keyboardType: TextInputType.number, onChanged: (_) => setSt(() {}), style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Mola (dk)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: hourlyCtrl, keyboardType: TextInputType.number, onChanged: (_) => setSt(() {}), style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Saatlik ücret (₺)'))),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => setSt(() => advanced = !advanced),
          child: Row(children: [
            Icon(advanced ? Icons.expand_less : Icons.expand_more, size: 20, color: t.muted),
            const SizedBox(width: 4),
            Text('Mesai ayarları', style: t.bodyStyle(13, color: t.muted, weight: FontWeight.w600)),
          ]),
        ),
        if (advanced) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
          Expanded(child: TextField(controller: otAfterCtrl, keyboardType: TextInputType.number, onChanged: (_) => setSt(() {}), style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Mesai sonrası saat'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: otMultCtrl, keyboardType: TextInputType.number, onChanged: (_) => setSt(() {}), style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Çarpan (1.5)'))),
        ])),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${hrs.toStringAsFixed(1)} saat çalışma', style: t.bodyStyle(14, weight: FontWeight.w700)),
            Text(money(earn), style: t.displayStyle(22, color: t.accent2)),
          ]),
        ),
        const SizedBox(height: 14),
        PrimaryBtn(t, 'Kaydet', onTap: () => Navigator.pop(c, true)),
      ]);
    }));
    if (ok != true) return;
    if (_parseHm(startCtrl.text) == null || _parseHm(endCtrl.text) == null) {
      if (mounted) toast(context, 'Saat biçimi 09:00 gibi olmalı');
      return;
    }
    final hrs = _hoursOf(startCtrl.text, endCtrl.text, int.tryParse(breakCtrl.text) ?? 0);
    final hourly = num.tryParse(hourlyCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final otA = num.tryParse(otAfterCtrl.text.replaceAll(',', '.')) ?? 8;
    final otM = num.tryParse(otMultCtrl.text.replaceAll(',', '.')) ?? 1.5;
    final earn = _earnOf(hrs, hourly, otA, otM);
    await Store.insert('work_shifts', {
      'work_date': date.toIso8601String().substring(0, 10),
      'worker': worker, 'start_time': startCtrl.text.trim(), 'end_time': endCtrl.text.trim(),
      'break_min': int.tryParse(breakCtrl.text) ?? 0, 'hourly': hourly,
      'ot_after': otA, 'ot_mult': otM, 'earned': earn,
    }, summary: 'Vardiya · $worker ${money(earn)}');
    if (mounted) toast(context, 'Vardiya eklendi · ${money(earn)} gelire yazıldı');
  }

  // ---- ortak silme tuşu ----
  Widget _del(String table, String id, String what) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          if (await confirmDelete(context, t, what)) {
            await Store.remove(table, id, summary: 'Silindi · $what');
            if (mounted) toast(context, 'Silindi (çöp kutusunda)');
          }
        },
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 20, color: t.muted)),
      );

  // ---------- alt gezinme ----------
  Widget _nav() {
    final items = <(String, IconData, String)>[
      ('ozet', Icons.home_rounded, 'Özet'),
      ('akis', Icons.swap_vert, 'Akış'),
      ('mesai', Icons.schedule, 'Mesai'),
      ('taksit', Icons.credit_card, 'Taksit'),
      ('borc', Icons.menu_book, 'Borç'),
      ('birikim', Icons.savings, 'Birikim'),
    ];
    return Container(
      decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(children: items.map((it) {
        final on = _tab == it.$1;
        return Expanded(child: InkWell(onTap: () => setState(() => _tab = it.$1), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(it.$2, color: on ? t.accent : t.muted, size: 22),
          const SizedBox(height: 3),
          Text(it.$3, style: t.bodyStyle(10, color: on ? t.accent : t.muted, weight: FontWeight.w600)),
        ])));
      }).toList()),
    );
  }

  // ---------- ekleme/düzenleme sheet'leri ----------
  Future<void> _addIncome() async {
    final noteCtrl = TextEditingController();
    String source = 'maas';
    final amt = await _form(title: 'Gelir ekle', amtHint: 'Tutar (₺)', extra: (setSt) => [
      Wrap(spacing: 8, runSpacing: 8, children: const [('maas', 'Maaş'), ('yardim', 'Yardım'), ('kira', 'Kira'), ('diger', 'Diğer')]
          .map((x) => Pill(t, x.$2, on: source == x.$1, onTap: () => setSt(() => source = x.$1))).toList()),
      const SizedBox(height: 10),
      TextField(controller: noteCtrl, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Açıklama (isteğe bağlı)')),
    ]);
    if (amt == null) return;
    await Store.insert('incomes', {'inc_date': today(), 'source': source, 'amount': amt, 'note': noteCtrl.text.trim()});
  }

  Future<void> _addExpense() async {
    final cats = ['Market', 'Fatura', 'Kira', 'Okul', 'Sağlık', 'Ulaşım', 'Giyim', 'Diğer'];
    String cat = cats.first;
    final noteCtrl = TextEditingController();
    final amt = await _form(title: 'Gider ekle', extra: (setSt) => [
      Wrap(spacing: 8, runSpacing: 8, children: cats.map((x) => Pill(t, x, on: cat == x, onTap: () => setSt(() => cat = x))).toList()),
      const SizedBox(height: 10),
      TextField(controller: noteCtrl, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Açıklama (isteğe bağlı)')),
    ]);
    if (amt == null) return;
    await Store.insert('expenses', {'exp_date': today(), 'category': cat, 'amount': amt, 'note': noteCtrl.text.trim()});
  }

  Future<void> _addInstallment() async {
    final nameCtrl = TextEditingController();
    String kind = 'kredi';
    final dayCtrl = TextEditingController(text: '1');
    final totalCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');
    final debtCtrl = TextEditingController();
    final amt = await _form(title: 'Ödeme / taksit ekle', amtHint: 'Aylık tutar (₺)', extra: (setSt) => [
      Text('Hazır ödemeler', style: t.bodyStyle(13, color: t.muted, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _odemePresetleri.map((p) => Pill(t, p.$1, on: nameCtrl.text == p.$1, onTap: () => setSt(() { nameCtrl.text = p.$1; kind = p.$2; }))).toList()),
      const SizedBox(height: 14),
      Text('Tür', style: t.bodyStyle(13, color: t.muted, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: const [('toki', 'TOKİ'), ('kira', 'Kira'), ('kredi', 'Kredi'), ('kart', 'Kart'), ('fatura', 'Fatura'), ('abonelik', 'Abonelik'), ('diger', 'Diğer')]
          .map((x) => Pill(t, x.$2, on: kind == x.$1, onTap: () => setSt(() => kind = x.$1))).toList()),
      const SizedBox(height: 12),
      TextField(controller: nameCtrl, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Ad (elle de yazabilirsin, örn. Konut kredisi)'), onChanged: (_) => setSt(() {})),
      const SizedBox(height: 10),
      TextField(controller: dayCtrl, keyboardType: TextInputType.number, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Ödeme günü (1-31)')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: totalCtrl, keyboardType: TextInputType.number, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Toplam taksit'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: paidCtrl, keyboardType: TextInputType.number, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Ödenen'))),
      ]),
      const SizedBox(height: 10),
      TextField(controller: debtCtrl, keyboardType: TextInputType.number, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Toplam borç (₺, isteğe bağlı)')),
    ]);
    if (amt == null || nameCtrl.text.trim().isEmpty) return;
    final pc = int.tryParse(paidCtrl.text) ?? 0;
    await Store.insert('installments', {
      'name': nameCtrl.text.trim(), 'kind': kind, 'amount': amt,
      'day_of_month': int.tryParse(dayCtrl.text) ?? 1,
      'total_count': int.tryParse(totalCtrl.text) ?? 0, 'paid_count': pc,
      'total_debt': num.tryParse(debtCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      'paid_debt': pc * amt,
    });
  }

  Future<void> _editInstallment(Map<String, dynamic> l) async {
    final amt = await _numInput('${l['name']} aylık taksit (₺)', initial: l['amount'] as num?);
    if (amt != null) await Store.update('installments', l['id'] as String, {'amount': amt}, summary: '${l['name']} taksit güncellendi');
  }

  Future<void> _addDebt() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final amt = await _form(title: _debtTab == 'bize' ? 'Bize borçlu ekle' : 'Bizim borcumuz ekle', amtHint: 'Tutar (₺)', extra: (setSt) => [
      TextField(controller: nameCtrl, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Kişi')),
      const SizedBox(height: 10),
      TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Telefon (isteğe bağlı)')),
      const SizedBox(height: 10),
      TextField(controller: noteCtrl, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Açıklama (isteğe bağlı)')),
    ]);
    if (amt == null || nameCtrl.text.trim().isEmpty) return;
    await Store.insert('debts', {
      'direction': _debtTab, 'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(),
      'amount': amt, 'paid': 0, 'debt_date': today(), 'note': noteCtrl.text.trim(),
    });
  }

  Future<void> _addSaving() async {
    final nameCtrl = TextEditingController();
    final amt = await _form(title: 'Birikim hedefi', amtHint: 'Hedef tutar (₺)', extra: (setSt) => [
      TextField(controller: nameCtrl, style: TextStyle(color: t.text), decoration: fieldDeco(t, 'Ad (örn. Araba)')),
    ]);
    if (amt == null || nameCtrl.text.trim().isEmpty) return;
    await Store.insert('savings', {'name': nameCtrl.text.trim(), 'target': amt, 'saved': 0});
  }

  Future<void> _editSaving(Map<String, dynamic> g) async {
    final v = await _numInput('Biriken tutar · ${g['name']} (₺)', initial: g['saved'] as num?);
    if (v != null) await Store.update('savings', g['id'] as String, {'saved': v}, summary: 'Birikim · ${g['name']} güncellendi');
  }

  /// Ortak form: ekstra alanlar + alttaki tutar alanı.
  Future<num?> _form({required String title, String amtHint = 'Tutar (₺)', required List<Widget> Function(StateSetter) extra}) async {
    final amtCtrl = TextEditingController();
    return openSheet<num>(context, t, (c) => StatefulBuilder(builder: (c, setSt) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t.displayStyle(24)),
      const SizedBox(height: 14),
      ...extra(setSt),
      const SizedBox(height: 12),
      TextField(controller: amtCtrl, keyboardType: TextInputType.number, style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w700), decoration: fieldDeco(t, amtHint)),
      const SizedBox(height: 14),
      PrimaryBtn(t, 'Kaydet', onTap: () => Navigator.pop(c, num.tryParse(amtCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')))),
    ])));
  }

  Future<num?> _numInput(String title, {num? initial}) async {
    final ctrl = TextEditingController(text: initial != null ? initial.round().toString() : '');
    return openSheet<num>(context, t, (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t.displayStyle(20)),
      const SizedBox(height: 14),
      TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.text), decoration: fieldDeco(t, 'Değer')),
      const SizedBox(height: 14),
      PrimaryBtn(t, 'Kaydet', onTap: () => Navigator.pop(c, num.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9.]'), '')))),
    ]));
  }
}
