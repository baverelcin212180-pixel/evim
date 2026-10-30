import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'services/app.dart';
import 'services/auth.dart';
import 'services/settings.dart';
import 'services/store.dart';
import 'services/updater.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'theme.dart';

final loggedIn = ValueNotifier<bool>(false);
final themeTick = ValueNotifier<int>(0);

Future<void> main() async {
  appVersion = '1.0.0+1';
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      Store.reportError('uygulama', d.exceptionAsString(), d.library);
    };
    runApp(const EvimApp());
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey, debug: false);
    } catch (_) {}
    await _backgroundBoot();
  }, (e, s) {
    Store.reportError('uygulama', e.toString());
  });
}

Future<void> _backgroundBoot() async {
  await _safe(Settings.init);
  if (sb.auth.currentSession != null) {
    await _safe(Auth.loadProfile);
    await _safe(Store.init);
    loggedIn.value = true;
    Updater.check();
  }
}

Future<void> _safe(Future<void> Function() fn) async {
  try {
    await fn();
  } catch (_) {}
}

/// Giriş ekranından çağrılır.
Future<void> bootSession() async {
  await _safe(Auth.loadProfile);
  await _safe(Store.init);
  loggedIn.value = true;
  Updater.check();
}

/// Çıkış.
Future<void> logout() async {
  await Store.dispose();
  await Auth.signOut();
  loggedIn.value = false;
}

class EvimApp extends StatelessWidget {
  const EvimApp({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([loggedIn, themeTick, Settings.changed]),
      builder: (c, _) {
        final t = appTheme();
        return MaterialApp(
          title: 'Evim',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: t.dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: t.bg,
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.accent,
              brightness: t.dark ? Brightness.dark : Brightness.light,
            ),
          ),
          home: loggedIn.value ? const Shell() : const LoginScreen(),
        );
      },
    );
  }
}
