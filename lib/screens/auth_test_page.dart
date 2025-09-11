import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthTestPage extends StatefulWidget {
  const AuthTestPage({super.key});

  @override
  State<AuthTestPage> createState() => _AuthTestPageState();
}

class _AuthTestPageState extends State<AuthTestPage> {
  final AuthService _authService = AuthService();

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _staffUidController = TextEditingController();

  String _status = "";

  // Role dropdown
  String _selectedRole = "visitor";
  final List<String> _roles = ["visitor", "participant", "staff"];

  // ✅ Signup method
  void _signup() async {
    try {
      await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
      );
      setState(() => _status = "Signed up as $_selectedRole ✅");
    } catch (e) {
      setState(() => _status = "❌ Signup failed: $e");
    }
  }

  // ✅ Login method
  void _login() async {
    try {
      await _authService.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() => _status = "Logged in ✅");
    } catch (e) {
      setState(() => _status = "❌ Login failed: $e");
    }
  }

  // ✅ Google login method
  void _loginGoogle() async {
    try {
      await _authService.loginWithGoogle();
      setState(() => _status = "Logged in with Google ✅");
    } catch (e) {
      setState(() => _status = "❌ Google login failed: $e");
    }
  }

  // ✅ Approve staff
  void _approveStaff() async {
    try {
      await _authService.approveStaff(_staffUidController.text.trim());
      setState(() => _status = "Staff approved ✅");
    } catch (e) {
      setState(() => _status = "❌ Approve failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Auth Test Page")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            // Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            const SizedBox(height: 16),

            // Dropdown for Role
            DropdownButton<String>(
              value: _selectedRole,
              items: _roles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
            ),

            const SizedBox(height: 16),

            // Signup
            ElevatedButton(onPressed: _signup, child: const Text("Sign Up")),

            // Login
            ElevatedButton(onPressed: _login, child: const Text("Login")),

            // Google Login
            ElevatedButton(
              onPressed: _loginGoogle,
              child: const Text("Login with Google"),
            ),

            const Divider(height: 32),

            // Admin approval
            TextField(
              controller: _staffUidController,
              decoration:
              const InputDecoration(labelText: "Staff UID (Admin Only)"),
            ),
            ElevatedButton(
              onPressed: _approveStaff,
              child: const Text("Approve Staff (Admin Action)"),
            ),

            const SizedBox(height: 20),

            // Status
            Text("Status: $_status",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
