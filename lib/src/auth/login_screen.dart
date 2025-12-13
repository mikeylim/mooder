// login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/app_copy.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return AppCopy.errUserNotFound;
      case 'wrong-password':
        return AppCopy.errWrongPassword;
      case 'invalid-email':
        return AppCopy.errInvalidEmail;
      case 'too-many-requests':
        return AppCopy.errTooManyRequests;
      case 'network-request-failed':
        return AppCopy.errNetwork;
      default:
        return AppCopy.errSignInFailed; // add to AppCopy (recommended)
    }
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = AppCopy.errEnterEmailPassword);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // AuthGate will redirect automatically.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.code));
    } catch (_) {
      setState(() => _error = AppCopy.errGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppCopy.welcomeBackTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppCopy.welcomeBackSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: AppCopy.emailLabel,
                hintText: AppCopy.emailHint,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: AppCopy.passwordLabel,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _loading ? null : _login(),
            ),

            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],

            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppCopy.signIn),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
              child: const Text(AppCopy.createAccountLink),
            ),
          ],
        ),
      ),
    );
  }
}
