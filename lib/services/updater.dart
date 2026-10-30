import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Uygulama içi güncelleme: sunucudaki en yeni sürümü kontrol eder, indirip
/// Android'in kurulum ekranını açar. APK'lar GitHub Actions'ta derlenip
/// Supabase 'releases' kovasına yüklenir. (Kaldırıp yeniden kurmaya gerek yok.)
class Updater {
  static const int currentVersion = 1; // her sürümde pubspec +N ile birlikte artar
  static final available = ValueNotifier<Map<String, dynamic>?>(null);

  static Future<void> check() async {
    try {
      final rows = await sb
          .from('app_releases')
          .select()
          .gt('version_code', currentVersion)
          .order('version_code', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) available.value = rows.first;
    } catch (_) {}
  }

  static Future<File> _download(String path, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/evim_update.apk');
    final url = sb.storage.from('releases').getPublicUrl(path);
    final req = await HttpClient().getUrl(Uri.parse(url));
    final res = await req.close();
    final total = res.contentLength;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in res) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.close();
    return file;
  }

  static Future<void> run(BuildContext context) async {
    final rel = available.value;
    if (rel == null) return;
    final t = appTheme();
    final progress = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Güncelleniyor', style: t.displayStyle(20)),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (c, v, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: v == 0 ? null : v, color: t.accent, backgroundColor: t.surface2),
            const SizedBox(height: 12),
            Text('%${(v * 100).round()} indirildi', style: t.bodyStyle(14, color: t.muted)),
          ]),
        ),
      ),
    );
    try {
      final file = await _download(rel['path'], (v) => progress.value = v);
      if (context.mounted) Navigator.pop(context);
      await _install(file.path);
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context);
        toast(context, 'Güncelleme inemedi, interneti kontrol et');
      }
    }
  }

  static Future<void> _install(String path) async {
    const channel = MethodChannel('evim/installer');
    await channel.invokeMethod('install', {'path': path});
  }
}
