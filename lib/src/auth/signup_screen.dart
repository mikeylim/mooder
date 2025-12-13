// signup_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/app_copy.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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

  String _friendlySignupError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return AppCopy.errEmailInUse; // add to AppCopy (recommended)
      case 'invalid-email':
        return AppCopy.errInvalidEmail;
      case 'weak-password':
        return AppCopy.errWeakPassword; // add to AppCopy (recommended)
      case 'network-request-failed':
        return AppCopy.errNetwork;
      default:
        return AppCopy.errSignupFailed; // add to AppCopy (recommended)
    }
  }

  Future<void> _signup() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(
        () => _error = AppCopy.errEmailPasswordRequired,
      ); // add to AppCopy
      return;
    }

    if (password.length < 6) {
      setState(() => _error = AppCopy.errPasswordMin6);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlySignupError(e.code));
    } catch (_) {
      setState(() => _error = AppCopy.errGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppCopy.signupTitle)), // add to AppCopy
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppCopy.signupSubtitle, // add to AppCopy
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
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: AppCopy.passwordLabel,
                helperText: AppCopy.passwordHelper,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _loading ? null : _signup(),
            ),

            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],

            ElevatedButton(
              onPressed: _loading ? null : _signup,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppCopy.createAccount),
            ),
          ],
        ),
      ),
    );
  }
}
