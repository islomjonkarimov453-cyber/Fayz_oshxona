import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_shell.dart';

/// Kirish ekrani: username + parol -> o'z sahifasi (rol bo'yicha).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _roleIndex = {'waiter': 0, 'cook': 1, 'admin': 2};

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Login va parolni kiriting');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final role = await widget.store.login(username, password);
      if (!mounted) return;
      final index = _roleIndex[role] ?? 2;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeShell(store: widget.store, initialIndex: index, locked: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openSettings() async {
    final url = await promptServerUrl(context, widget.store.baseUrl);
    if (url == null) return;
    if (!mounted) return;
    await widget.store.setBaseUrl(url);
    if (!mounted) return;
    showMessage(
      context,
      widget.store.online ? 'Serverga ulandi ✓' : 'Server topilmadi. Manzilni tekshiring.',
      error: !widget.store.online,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.pri, palette.ok],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🐟', style: TextStyle(fontSize: 42)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Fayz Baliqxonasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.tx,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kirish uchun login va parol',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.mut, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  Center(child: StatusPill(online: widget.store.online)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Login',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Parol',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.bad, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_busy ? 'Kirilmoqda...' : 'Kirish'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: const Text('Serverni sozlash'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
