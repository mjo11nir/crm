import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

String? _required(BuildContext c, String? v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(c).required : null;
String? _validEmail(BuildContext c, String? v) =>
    _required(c, v) ?? (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim()) ? null : AppLocalizations.of(c).invalidEmail);
String? _password(BuildContext c, String? v) => (v == null || v.length < 8) ? AppLocalizations.of(c).passwordTooShort : null;

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                    child: ColoredIconTile(icon: Icons.auto_awesome_rounded, background: c.primary, size: 72, radius: 22),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).login(_email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _AuthLayout(
      title: l.login,
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const Key('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l.email),
                validator: (v) => _validEmail(context, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(labelText: l.password),
                validator: (v) => _required(context, v),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: l.login, loading: _busy, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/register'), child: Text(l.noAccount)),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in ['fullName', 'businessName', 'phone', 'email', 'password']) k: TextEditingController(),
  };
  String _currency = 'EUR';
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).register({
        for (final e in _c.entries) e.key: e.value.text.trim(),
        'password': _c['password']!.text,
        'currency': _currency,
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _AuthLayout(
      title: l.register,
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _c['fullName'],
                decoration: InputDecoration(labelText: l.fullName),
                validator: (v) => _required(context, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['businessName'],
                decoration: InputDecoration(labelText: l.businessName),
                validator: (v) => _required(context, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['phone'],
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l.phone),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['email'],
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l.email),
                validator: (v) => _validEmail(context, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['password'],
                obscureText: true,
                decoration: InputDecoration(labelText: l.password),
                validator: (v) => _password(context, v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: InputDecoration(labelText: l.currency),
                items: [
                  for (final c in ['EUR', 'TRY', 'USD', 'RUB', 'BRL', 'GBP', 'KZT']) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _currency = v!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: l.register, loading: _busy, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/login'), child: Text(l.haveAccount)),
      ],
    );
  }
}
