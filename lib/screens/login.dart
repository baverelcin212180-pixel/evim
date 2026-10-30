import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _err;

  Future<void> _login() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'Kullanıcı adı ve şifre gerekli');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final err = await Auth.signIn(_user.text, _pass.text);
    if (err != null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = err;
        });
      }
      return;
    }
    await bootSession();
  }

  @override
  Widget build(BuildContext context) {
    final t = appTheme();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EvimLogo(98),
                const SizedBox(height: 22),
                Text('Evim', style: t.displayStyle(46)),
                const SizedBox(height: 4),
                Text('Hane bütçesi', style: t.bodyStyle(15, color: t.muted)),
                const SizedBox(height: 36),
                TextField(
                  controller: _user,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: t.text),
                  decoration: fieldDeco(t, 'Kullanıcı adı'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: !_show,
                  style: TextStyle(color: t.text),
                  onSubmitted: (_) => _login(),
                  decoration: fieldDeco(t, 'Şifre').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_show ? Icons.visibility_off : Icons.visibility, color: t.muted),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                ),
                if (_err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_err!, style: TextStyle(color: t.danger, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _busy
                      ? Center(child: CircularProgressIndicator(color: t.accent))
                      : PrimaryBtn(t, 'Giriş yap', onTap: _login),
                ),
                const SizedBox(height: 24),
                Text('Her hane kendi kullanıcı adıyla girer.',
                    style: t.bodyStyle(12, color: t.muted), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
