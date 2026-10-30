import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app.dart';
import '../services/settings.dart';
import '../services/store.dart';
import '../services/updater.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import '../widgets/ui.dart';
import 'home.dart';
import 'admin.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final t = appTheme();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(t),
          _UpdateBanner(t),
          Expanded(child: isAdmin ? const AdminScreen() : const HomeScreen()),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Palette t;
  const _TopBar(this.t);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.border))),
      child: Row(children: [
        const EvimLogo(34, shadow: false),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(isAdmin ? 'Evim · Yönetici' : 'Evim', style: t.displayStyle(18)),
          Text(myName, style: t.bodyStyle(11, color: t.muted)),
        ]),
        const Spacer(),
        _SyncDot(t),
        IconButton(
          icon: Icon(Icons.more_vert, color: t.text),
          onPressed: () => _menu(context),
        ),
      ]),
    );
  }

  void _menu(BuildContext context) {
    openSheet(context, t, (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ayarlar', style: t.displayStyle(22)),
      const SizedBox(height: 16),
      Text('Tema', style: t.bodyStyle(13, color: t.muted, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: themes.map((p) {
        final sel = appTheme().key == p.key;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Pill(t, p.name, on: sel, onTap: () async {
            await Settings.setLocal('theme', p.key);
            themeTick.value++;
            if (c.mounted) Navigator.pop(c);
          }),
        );
      }).toList()),
      const SizedBox(height: 20),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.sync, color: t.accent),
        title: Text('Şimdi eşitle', style: t.bodyStyle(15)),
        onTap: () async {
          Navigator.pop(c);
          await Store.forceSync();
          if (context.mounted) toast(context, 'Eşitlendi');
        },
      ),
      ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: Updater.available,
        builder: (c2, rel, _) => rel == null ? const SizedBox.shrink() : ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.system_update, color: t.accent2),
          title: Text('Güncelle (${rel['version_name']})', style: t.bodyStyle(15)),
          onTap: () {
            Navigator.pop(c);
            Updater.run(context);
          },
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.logout, color: t.danger),
        title: Text('Çıkış yap', style: t.bodyStyle(15)),
        onTap: () async {
          Navigator.pop(c);
          await logout();
        },
      ),
      const SizedBox(height: 8),
      Center(child: Text('Evim · sürüm $appVersion', style: t.bodyStyle(11, color: t.muted))),
    ]));
  }
}

class _SyncDot extends StatelessWidget {
  final Palette t;
  const _SyncDot(this.t);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => Store.forceSync(),
      child: AnimatedBuilder(
        animation: Listenable.merge([Store.online, Store.pendingCount]),
        builder: (c, _) {
          final up = Store.online.value;
          final pending = Store.pendingCount.value;
          final color = !up ? t.warn : (pending > 0 ? t.accent2 : t.ok);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(!up ? 'çevrimdışı' : (pending > 0 ? '$pending bekliyor' : 'eşitli'),
                  style: t.bodyStyle(11, color: t.muted, weight: FontWeight.w600)),
            ]),
          );
        },
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  final Palette t;
  const _UpdateBanner(this.t);
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: Updater.available,
      builder: (c, rel, _) {
        if (rel == null) return const SizedBox.shrink();
        return InkWell(
          onTap: () => Updater.run(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: t.accent2,
            child: Row(children: [
              Icon(Icons.system_update, size: 18, color: t.on),
              const SizedBox(width: 10),
              Expanded(child: Text('Yeni sürüm hazır (${rel['version_name']}) · dokun, uygulama içinden güncelle',
                  style: t.bodyStyle(13, color: t.on, weight: FontWeight.w700))),
            ]),
          ),
        );
      },
    );
  }
}
