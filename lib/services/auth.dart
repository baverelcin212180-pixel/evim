import '../config.dart';
import 'app.dart';

/// Kullanıcı adı + şifre ile giriş. E-posta içeride üretilir, kullanıcı görmez.
class Auth {
  static String emailFor(String username) =>
      '${username.trim().toLowerCase()}@$authEmailDomain';

  static Future<String?> signIn(String username, String password) async {
    try {
      await sb.auth.signInWithPassword(
        email: emailFor(username),
        password: '$password$authPassSuffix',
      );
      await loadProfile();
      return null;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('invalid') || s.contains('credential')) {
        return 'Kullanıcı adı veya şifre hatalı';
      }
      return 'Giriş yapılamadı. İnterneti kontrol et.';
    }
  }

  static Future<void> loadProfile() async {
    final uid = myUid;
    if (uid == null) return;
    try {
      final row = await sb
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      if (row != null) me = Map<String, dynamic>.from(row);
    } catch (_) {}
  }

  static Future<void> signOut() async {
    me = {};
    await sb.auth.signOut();
  }
}
