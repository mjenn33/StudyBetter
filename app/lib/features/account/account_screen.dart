import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/api_client.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = await ref.read(apiClientProvider.future);
      await api.authenticate(
        email: _email.text.trim(),
        password: _password.text,
        username: _register ? _username.text.trim() : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'Create account' : 'Sign in')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (s) =>
                        s != null &&
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(s.trim())
                        ? null
                        : 'Enter a valid email.',
                  ),
                  if (_register)
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (s) => (s?.trim().length ?? 0) >= 3
                          ? null
                          : 'Use at least 3 characters.',
                    ),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    autofillHints: const [AutofillHints.password],
                    validator: (s) => (s?.length ?? 0) >= 8
                        ? null
                        : 'Use at least 8 characters.',
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Text(_error!, semanticsLabel: 'Sign in error: $_error'),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Please wait…'
                          : _register
                          ? 'Register'
                          : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _register = !_register),
                    child: Text(
                      _register
                          ? 'Already have an account? Sign in'
                          : 'Create an account',
                    ),
                  ),
                  const Text(
                    'Quizzes and flashcards work offline without an account.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
