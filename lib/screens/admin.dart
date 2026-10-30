import 'package:flutter/material.dart';

import '../services/app.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Yönetici (Baver) paneli — iki haneye tam erişim.
/// Haneler bu hesabın varlığını görmez; burada her şey görülür, düzenlenir, silinir.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

const _haneler = {'h1': 'Bahar & Mustafa', 'h2': 'Berivan & Bünyamin'};
const _dataTables = [
  ('incomes', 'Gelir'), ('expenses', 'Gider'), ('work_shifts', 'Mesai'),
  ('savings', 'Birikim'), ('debts', 'Borç'), ('installments', 'Taksit'),
];

class _AdminScreenState extends State<AdminScreen> {
  String _hh = 'h1';
  String _tab = 'ozet';
  String _table = 'incomes';
  final t = appTheme();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        for (final tb in Store.tables) Store.tick(tb),
      ]),
      builder: (context, _) {
        return Column(children: [
          // hane seçici
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Segmented(t, items: const [('h1', 'Bahar & Mustafa'), ('h2', 'Berivan & Bünyamin')], value: _hh, onChanged: (v) => setState(() => _hh = v)),
          ),
          // tab seçici
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              for (final x in const [('ozet', 'Özet'), ('kayit', 'Kayıtlar'), ('cop', 'Çöp kutusu'), ('gecmis', 'Geçmiş'), ('tani', 'Tanılama')])
                Padding(padding: const EdgeInsets.only(right: 8), child: Pill(t, x.$2, on: _tab == x.$1, onTap: () => setState(() => _tab = x.$1))),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(child: _body()),
        ]);
      },
    );
  }

  Widget _body() {
    switch (_tab) {
      case 'kayit':
        return _kayitlar();
      case 'cop':
        return _cop();
      case 'gecmis':
        return _gecmis();
      case 'tani':
        return _tani();
      default:
        return _ozet();
    }
  }

  // ---- hesaplar ----
  bool _thisMonth(dynamic date) {
    final d = parseDate(date);
    final n = DateTime.now();
    return d != null && d.month == n.month && d.year == n.year;
  }

  num _income(String hh) => Store.list('incomes', household: hh).where((r) => _thisMonth(r['inc_date'])).fold<num>(0, (s, r) => s + (r['amount'] as num? ?? 0));
  num _workInc(String hh) => Store.list('work_shifts', household: hh).where((r) => _thisMonth(r['work_date'])).fold<num>(0, (s, r) => s + (r['earned'] as num? ?? 0));
  num _expense(String hh) => Store.list('expenses', household: hh).where((r) => _thisMonth(r['exp_date'])).fold<num>(0, (s, r) => s + (r['amount'] as num? ?? 0));
  num _instDue(String hh) => Store.list('installments', household: hh).where((l) {
        final tc = (l['total_count'] as num? ?? 0);
        final pc = (l['paid_count'] as num? ?? 0);
        return tc == 0 || pc < tc;
      }).fold<num>(0, (s, l) => s + (l['amount'] as num? ?? 0));
  num _savings(String hh) => Store.list('savings', household: hh).fold<num>(0, (s, g) => s + (g['saved'] as num? ?? 0));
  num _debtBize(String hh) => Store.list('debts', household: hh).where((d) => (d['direction'] ?? 'bize') == 'bize').fold<num>(0, (s, d) => s + ((d['amount'] as num? ?? 0) - (d['paid'] as num? ?? 0)));
  num _debtBiz(String hh) => Store.list('debts', household: hh).where((d) => (d['direction'] ?? 'bize') == 'biz').fold<num>(0, (s, d) => s + ((d['amount'] as num? ?? 0) - (d['paid'] as num? ?? 0)));

  // ---------- ÖZET ----------
  Widget _ozet() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      for (final hh in const ['h1', 'h2']) _householdCard(hh),
    ]);
  }

  Widget _householdCard(String hh) {
    final gelir = _income(hh) + _workInc(hh);
    final gider = _expense(hh) + _instDue(hh);
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Card2(t, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.home_rounded, color: t.accent, size: 20),
        const SizedBox(width: 8),
        Text(_haneler[hh]!, style: t.bodyStyle(16, weight: FontWeight.w800)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatTile(t, label: 'Ay kalan', value: money(gelir - gider), valueColor: gelir - gider >= 0 ? t.accent2 : t.danger)),
        const SizedBox(width: 8),
        Expanded(child: StatTile(t, label: 'Birikim', value: money(_savings(hh)), valueColor: t.accent)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: StatTile(t, label: 'Gelir', value: money(gelir), valueColor: t.accent2)),
        const SizedBox(width: 8),
        Expanded(child: StatTile(t, label: 'Gider', value: money(gider), valueColor: t.danger)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: StatTile(t, label: 'Bize borçlu', value: money(_debtBize(hh)))),
        const SizedBox(width: 8),
        Expanded(child: StatTile(t, label: 'Borcumuz', value: money(_debtBiz(hh)))),
      ]),
      const SizedBox(height: 10),
      GhostBtn(t, 'Kayıtları aç', icon: Icons.list, onTap: () => setState(() { _hh = hh; _tab = 'kayit'; })),
    ])));
  }

  // ---------- KAYITLAR ----------
  Widget _kayitlar() {
    final rows = Store.list(_table, household: _hh)..sort((a, b) => (b['updated_at'] ?? '').toString().compareTo((a['updated_at'] ?? '').toString()));
    return Column(children: [
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final x in _dataTables)
            Padding(padding: const EdgeInsets.only(right: 8), child: Pill(t, x.$2, on: _table == x.$1, onTap: () => setState(() => _table = x.$1))),
        ]),
      ),
      Expanded(child: rows.isEmpty
          ? emptyState(t, Icons.inbox, 'Bu hanede ${_dataTables.firstWhere((e) => e.$1 == _table).$2.toLowerCase()} kaydı yok.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (c, i) => _adminRow(rows[i]),
            )),
    ]);
  }

  Widget _adminRow(Map<String, dynamic> r) {
    return Card2(t, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_rowTitle(_table, r), style: t.bodyStyle(14, weight: FontWeight.w700)),
        Text(_rowSub(_table, r), style: t.bodyStyle(12, color: t.muted)),
      ])),
      if (_amountField(_table) != null)
        Text(money(r[_amountField(_table)] as num?), style: t.bodyStyle(15, weight: FontWeight.w800)),
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: t.muted, size: 20),
        color: t.surface,
        onSelected: (v) => _rowAction(v, r),
        itemBuilder: (c) => [
          if (_amountField(_table) != null) PopupMenuItem(value: 'edit', child: Text('Tutarı düzenle', style: t.bodyStyle(14))),
          PopupMenuItem(value: 'detay', child: Text('Detay (tüm alanlar)', style: t.bodyStyle(14))),
          PopupMenuItem(value: 'sil', child: Text('Sil (çöpe)', style: t.bodyStyle(14, color: t.danger))),
        ],
      ),
    ]));
  }

  Future<void> _rowAction(String v, Map<String, dynamic> r) async {
    final id = r['id'] as String;
    if (v == 'sil') {
      if (await confirmDelete(context, t, _rowTitle(_table, r))) {
        await Store.remove(_table, id, summary: 'Admin sildi · ${_rowTitle(_table, r)}');
        if (mounted) toast(context, 'Çöp kutusuna taşındı');
      }
    } else if (v == 'edit') {
      final f = _amountField(_table)!;
      final nv = await _numInput('${_rowTitle(_table, r)} · yeni tutar', initial: r[f] as num?);
      if (nv != null) await Store.update(_table, id, {f: nv}, summary: 'Admin düzenledi · ${_rowTitle(_table, r)}');
    } else if (v == 'detay') {
      _detail(r);
    }
  }

  void _detail(Map<String, dynamic> r) {
    openSheet(context, t, (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Kayıt detayı', style: t.displayStyle(20)),
      const SizedBox(height: 12),
      ...r.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(e.key, style: t.bodyStyle(12, color: t.muted, weight: FontWeight.w700))),
        Expanded(child: Text('${e.value}', style: t.bodyStyle(13))),
      ]))),
    ]));
  }

  String? _amountField(String table) {
    switch (table) {
      case 'incomes':
      case 'expenses':
      case 'debts':
      case 'installments':
        return 'amount';
      case 'savings':
        return 'saved';
      case 'work_shifts':
        return 'earned';
    }
    return null;
  }

  String _rowTitle(String table, Map<String, dynamic> r) {
    switch (table) {
      case 'incomes':
        return '${r['source'] ?? 'Gelir'}${(r['note'] ?? '').toString().isNotEmpty ? ' · ${r['note']}' : ''}';
      case 'expenses':
        return '${r['category'] ?? 'Gider'}${(r['note'] ?? '').toString().isNotEmpty ? ' · ${r['note']}' : ''}';
      case 'savings':
        return (r['name'] ?? 'Birikim').toString();
      case 'debts':
        return '${r['name'] ?? 'Borç'} (${r['direction'] == 'biz' ? 'bizim' : 'bize'})';
      case 'installments':
        return '${r['name'] ?? 'Taksit'} (${r['kind'] ?? ''})';
      case 'work_shifts':
        return '${r['worker'] ?? 'Vardiya'} mesai';
    }
    return table;
  }

  String _rowSub(String table, Map<String, dynamic> r) {
    final d = parseDate(r['inc_date'] ?? r['exp_date'] ?? r['debt_date'] ?? r['work_date'] ?? r['created_at']);
    final tarih = d != null ? dmy(d) : '';
    switch (table) {
      case 'savings':
        return 'Hedef ${money(r['target'] as num?)} · biriken ${money(r['saved'] as num?)}';
      case 'debts':
        return '$tarih · ödenen ${money(r['paid'] as num?)} / ${money(r['amount'] as num?)}';
      case 'installments':
        return '${r['paid_count'] ?? 0}/${r['total_count'] ?? 0} taksit · ${r['day_of_month'] ?? 1}. gün';
      case 'work_shifts':
        return '$tarih · ${r['start_time'] ?? ''}–${r['end_time'] ?? ''}';
      default:
        return tarih;
    }
  }

  // ---------- ÇÖP KUTUSU ----------
  Widget _cop() {
    final all = <Map<String, dynamic>>[];
    for (final tb in _dataTables) {
      for (final r in Store.trash(tb.$1, household: _hh)) {
        all.add({...r, '_table': tb.$1, '_tname': tb.$2});
      }
    }
    all.sort((a, b) => (b['deleted_at'] ?? '').toString().compareTo((a['deleted_at'] ?? '').toString()));
    if (all.isEmpty) return emptyState(t, Icons.delete_outline, 'Çöp kutusu boş.');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: all.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (c, i) {
        final r = all[i];
        final tb = r['_table'] as String;
        return Card2(t, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['_tname']} · ${_rowTitle(tb, r)}', style: t.bodyStyle(14, weight: FontWeight.w700)),
            Text('Silindi: ${parseDate(r['deleted_at']) != null ? dmy(parseDate(r['deleted_at'])!) : ''}', style: t.bodyStyle(12, color: t.muted)),
          ])),
          IconButton(icon: Icon(Icons.restore, color: t.accent2), tooltip: 'Geri al', onPressed: () async {
            await Store.restore(tb, r['id'] as String);
            if (mounted) toast(context, 'Geri alındı');
          }),
          IconButton(icon: Icon(Icons.delete_forever, color: t.danger), tooltip: 'Kalıcı sil', onPressed: () async {
            if (await confirmDelete(context, t, 'KALICI: ${_rowTitle(tb, r)}')) {
              await Store.hardRemove(tb, r['id'] as String);
              if (mounted) toast(context, 'Kalıcı silindi');
            }
          }),
        ]));
      },
    );
  }

  // ---------- GEÇMİŞ (change_log) ----------
  Widget _gecmis() {
    final rows = Store.allRows('change_log', household: _hh)..sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    if (rows.isEmpty) return emptyState(t, Icons.history, 'Henüz işlem geçmişi yok.');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rows.length > 200 ? 200 : rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (c, i) {
        final r = rows[i];
        final d = parseDate(r['created_at']);
        return Card2(t, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _actionColor(r['action']), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((r['summary'] ?? '').toString(), style: t.bodyStyle(13, weight: FontWeight.w600)),
            Text('${r['actor_name'] ?? ''} · ${d != null ? '${dmy(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : ''}', style: t.bodyStyle(11, color: t.muted)),
          ])),
        ]));
      },
    );
  }

  Color _actionColor(dynamic a) {
    switch (a) {
      case 'ekle':
        return t.accent2;
      case 'sil':
        return t.danger;
      case 'geri':
        return t.warn;
      default:
        return t.accent;
    }
  }

  // ---------- TANILAMA (app_errors) ----------
  Widget _tani() {
    final rows = Store.allRows('app_errors')..sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Expanded(child: Text('${rows.length} kayıt · her iki hane', style: t.bodyStyle(13, color: t.muted))),
          if (rows.isNotEmpty) GhostBtn(t, 'Temizle', icon: Icons.delete_sweep, tint: t.danger, onTap: () async {
            for (final r in List.of(rows)) {
              await Store.hardRemove('app_errors', r['id'] as String);
            }
            if (mounted) toast(context, 'Tanılama temizlendi');
          }),
        ]),
      ),
      Expanded(child: rows.isEmpty
          ? emptyState(t, Icons.verified, 'Hata kaydı yok. Her şey yolunda.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (c, i) {
                final r = rows[i];
                final d = parseDate(r['created_at']);
                return Card2(t, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.error_outline, size: 16, color: t.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${r['kind'] ?? ''} · ${r['user_email'] ?? ''}', style: t.bodyStyle(12, color: t.muted, weight: FontWeight.w700))),
                    Text(d != null ? dmy(d) : '', style: t.bodyStyle(11, color: t.muted)),
                  ]),
                  const SizedBox(height: 4),
                  Text((r['message'] ?? '').toString(), style: t.bodyStyle(13)),
                  if ((r['context'] ?? '').toString().isNotEmpty) Text(r['context'].toString(), style: t.bodyStyle(11, color: t.muted)),
                ]));
              },
            )),
    ]);
  }

  Future<num?> _numInput(String title, {num? initial}) async {
    final ctrl = TextEditingController(text: initial != null ? initial.round().toString() : '');
    return openSheet<num>(context, t, (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t.displayStyle(18)),
      const SizedBox(height: 14),
      TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.text), decoration: fieldDeco(t, 'Değer')),
      const SizedBox(height: 14),
      PrimaryBtn(t, 'Kaydet', onTap: () => Navigator.pop(c, num.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9.]'), '')))),
    ]));
  }
}
