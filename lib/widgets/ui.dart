import 'package:flutter/material.dart';

import '../theme.dart';

/// Tasarım diline uygun ortak parçalar. Hepsi bir Palette alır.

BoxDecoration cardDeco(Palette t, {double radius = 20}) => BoxDecoration(
      color: t.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: t.border),
    );

class Card2 extends StatelessWidget {
  final Palette t;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  const Card2(this.t, {super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20, this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: color != null
            ? BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius))
            : cardDeco(t, radius: radius),
        child: child,
      );
}

/// Dolu (accent) buton.
class PrimaryBtn extends StatelessWidget {
  final Palette t;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const PrimaryBtn(this.t, this.label, {super.key, this.onTap, this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Text(label, style: t.bodyStyle(15, color: t.on, weight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.on,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

/// Kenarlıklı (ghost) buton.
class GhostBtn extends StatelessWidget {
  final Palette t;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? tint;
  const GhostBtn(this.t, this.label, {super.key, this.onTap, this.icon, this.tint});
  @override
  Widget build(BuildContext context) {
    final c = tint ?? t.text;
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: icon != null ? Icon(icon, size: 16, color: c) : const SizedBox.shrink(),
        label: Text(label, style: t.bodyStyle(14, color: c, weight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          backgroundColor: t.surface2,
          side: BorderSide(color: t.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Seçilebilir çip.
class Pill extends StatelessWidget {
  final Palette t;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const Pill(this.t, this.label, {super.key, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: on ? t.accent : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: on ? t.accent : t.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            child: Text(label, style: t.bodyStyle(13, color: on ? t.on : t.text, weight: FontWeight.w600)),
          ),
        ),
      );
}

/// İki seçenekli bölümlü anahtar.
class Segmented extends StatelessWidget {
  final Palette t;
  final List<(String, String)> items; // (değer, etiket)
  final String value;
  final ValueChanged<String> onChanged;
  const Segmented(this.t, {super.key, required this.items, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.border)),
        child: Row(children: items.map((x) {
          final sel = value == x.$1;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(x.$1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: sel ? t.accent : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Text(x.$2, style: t.bodyStyle(14, color: sel ? t.on : t.muted, weight: FontWeight.w700)),
              ),
            ),
          );
        }).toList()),
      );
}

/// İstatistik kutusu (küçük etiket + büyük rakam).
class StatTile extends StatelessWidget {
  final Palette t;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? bg;
  const StatTile(this.t, {super.key, required this.label, required this.value, this.valueColor, this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(color: bg ?? t.surface2, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: t.bodyStyle(11, color: t.muted, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: t.displayStyle(24, color: valueColor ?? t.text)),
        ]),
      );
}

/// Üst başlık.
class ScreenTitle extends StatelessWidget {
  final Palette t;
  final String title;
  final String? sub;
  const ScreenTitle(this.t, this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.displayStyle(30)),
          if (sub != null) Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(sub!, style: t.bodyStyle(13, color: t.muted)),
          ),
        ],
      );
}

Widget label(Palette t, String s) => Text(s.toUpperCase(),
    style: t.bodyStyle(11, color: t.muted, weight: FontWeight.w700));

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  m.showSnackBar(SnackBar(
    content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 1900),
  ));
}

/// Onaylı sil penceresi.
Future<bool> confirmDelete(BuildContext context, Palette t, String what) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: t.surface,
      title: Text('Silinsin mi?', style: t.displayStyle(20)),
      content: Text('$what silinecek. Çöp kutusundan geri alabilirsin.', style: t.bodyStyle(14, color: t.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Vazgeç', style: TextStyle(color: t.muted))),
        FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: t.danger), child: const Text('Sil')),
      ],
    ),
  );
  return r ?? false;
}

/// Alt sayfa (bottom sheet) çerçevesi.
Future<T?> openSheet<T>(BuildContext context, Palette t, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (c) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 24 + MediaQuery.of(c).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(999))),
        Flexible(child: SingleChildScrollView(child: builder(c))),
      ]),
    ),
  );
}

/// İlerleme çubuğu.
class Bar extends StatelessWidget {
  final Palette t;
  final double value; // 0..1
  final Color? color;
  final double height;
  const Bar(this.t, this.value, {super.key, this.color, this.height = 10});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: height,
          color: t.surface2,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: Container(color: color ?? t.accent),
          ),
        ),
      );
}

/// Metin giriş alanı.
InputDecoration fieldDeco(Palette t, String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: t.muted),
      filled: true,
      fillColor: t.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent, width: 2)),
    );

/// Boş durum mesajı.
Widget emptyState(Palette t, IconData icon, String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        Icon(icon, size: 40, color: t.muted),
        const SizedBox(height: 10),
        Text(msg, textAlign: TextAlign.center, style: t.bodyStyle(14, color: t.muted)),
      ]),
    );
