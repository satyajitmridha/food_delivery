import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'config.dart';
import 'state.dart';
import 'ui.dart';

class LoginScreen extends StatefulWidget {
  final bool startRegister;
  const LoginScreen({super.key, this.startRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _register = widget.startRegister;
  final _ident = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_ident, _pass, _name, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await s.register(_name.text.trim(), _email.text.trim(), _phone.text.trim(), _pass.text);
      } else {
        await s.login(_ident.text.trim(), _pass.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppConfig.appName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Log in to order, track your rider and save addresses.', style: TextStyle(color: kMuted)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Log in')),
                  ButtonSegment(value: true, label: Text('Sign up')),
                ],
                selected: {_register},
                onSelectionChanged: (s) => setState(() {
                  _register = s.first;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFDF0F0), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: kRed, fontWeight: FontWeight.w600)),
              ),
            if (_register) ...[
              TextField(controller: _name, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 14),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 14),
              TextField(controller: _phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber], decoration: const InputDecoration(labelText: 'Mobile number')),
            ] else
              TextField(controller: _ident, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(labelText: 'Email or mobile number')),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: _hide,
              autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _register ? 'At least 8 characters' : null,
                suffixIcon: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_register ? 'Create account' : 'Log in'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Shown instead of a screen that needs an account.
class LoginPrompt extends StatelessWidget {
  final String title;
  final String subtitle;
  const LoginPrompt({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.lock_outline,
      title: title,
      subtitle: subtitle,
      action: FilledButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
        child: const Text('Log in or sign up'),
      ),
    );
  }
}
