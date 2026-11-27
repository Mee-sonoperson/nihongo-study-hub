// =============================================================================
// login_screen.dart - ログイン画面(学籍番号 + 暗証番号)
//   学籍番号と暗証番号(PIN)は、先生が受講記録シートの students タブで決めます。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  bool busy = false;
  bool showPin = false;
  String error = '';

  @override
  void dispose() {
    idCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (idCtrl.text.trim().isEmpty || pinCtrl.text.trim().isEmpty) {
      setState(() => error = 'Enter your Student ID and PIN.');
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    final msg =
        await context.read<AppData>().login(idCtrl.text, pinCtrl.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = msg ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                            colors: [kPrimary, kSecondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                      ),
                      alignment: Alignment.center,
                      child: const Text('学',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nihongo Study Hub',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Log in with the Student ID and PIN from your teacher.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: idCtrl,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Student ID',
                      hintText: 'e.g. S2026-0142',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pinCtrl,
                    obscureText: !showPin,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => busy ? null : _login(),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(showPin
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() => showPin = !showPin),
                      ),
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(error,
                        style: const TextStyle(
                            color: kRed, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: busy ? null : _login,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login_rounded),
                      label: Text(busy ? 'Logging in…' : 'Log in',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your work is saved to your school account, so you can '
                    'continue on another phone.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
