import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();

  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? "Login" : "Signup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isLogin)
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (isLogin) {
                    await _authService.loginWithEmail(
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                    );
                  } else {
                    await _authService.signUpWithEmail(
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                      name: nameCtrl.text.trim(), role: '',
                    );
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Success ✅")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: Text(isLogin ? "Login" : "Signup"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await _authService.loginWithGoogle();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Google Login Success ✅")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              icon: const Icon(Icons.login),
              label: const Text("Login with Google"),
            ),
            TextButton(
              onPressed: () {
                setState(() => isLogin = !isLogin);
              },
              child: Text(isLogin
                  ? "No account? Signup"
                  : "Already have an account? Login"),
            )
          ],
        ),
      ),
    );
  }
}
