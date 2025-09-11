import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'event_list_screen.dart';

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
  final TextEditingController departmentCtrl = TextEditingController();
  final TextEditingController enrollmentCtrl = TextEditingController();

  bool isLogin = true;
  String selectedRole = "student"; // Default to student
  String selectedUserType = "visitor"; // Default to visitor for students
  bool _isLoading = false;

  final List<String> roles = ["student", "organizer", "admin"];
  final List<String> studentTypes = ["visitor", "participant"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Login" : "Sign Up"),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.event,
                    size: 64,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "FusionFiesta",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    isLogin ? "Welcome back!" : "Join our community",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Sign up fields
                    if (!isLogin) ...[
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: "Full Name *",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Role selection
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: "Select Role *",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: roles.map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(_getRoleDisplayName(role)),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value!;
                            // Reset user type when role changes
                            selectedUserType = "visitor";
                          });
                        },
                      ),
                      SizedBox(height: 16),

                      // User type selection (only for students)
                      if (selectedRole == "student") ...[
                        DropdownButtonFormField<String>(
                          value: selectedUserType,
                          decoration: InputDecoration(
                            labelText: "Student Type *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.school),
                          ),
                          items: studentTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(_getUserTypeDisplayName(type)),
                          )).toList(),
                          onChanged: (value) {
                            setState(() => selectedUserType = value!);
                          },
                        ),
                        SizedBox(height: 16),
                      ],

                      // Additional fields for student participants
                      if (selectedRole == "student" && selectedUserType == "participant") ...[
                        TextFormField(
                          controller: departmentCtrl,
                          decoration: InputDecoration(
                            labelText: "Department *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.business),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: enrollmentCtrl,
                          decoration: InputDecoration(
                            labelText: "Enrollment Number *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.badge),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Staff email validation notice
                      if (selectedRole == "organizer" || selectedRole == "admin") ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Staff members must use institutional email (ending with .edu) and require admin approval.",
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ],

                    // Email field
                    TextFormField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: "Email Address *",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: passCtrl,
                      decoration: InputDecoration(
                        labelText: "Password *",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                          isLogin ? "Sign In" : "Create Account",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Forgot password (only show during login)
                    if (isLogin)
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),

                    // Divider
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "OR",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),

                    // Google Sign-In button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        icon: Icon(Icons.login, color: Colors.red),
                        label: Text(
                          "Continue with Google",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Switch between login and signup
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin ? "Don't have an account? " : "Already have an account? ",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                      // Reset form when switching
                      _clearForm();
                    });
                  },
                  child: Text(
                    isLogin ? "Sign Up" : "Sign In",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case "student":
        return "Student";
      case "organizer":
        return "Staff (Organizer)";
      case "admin":
        return "Staff (Admin)";
      default:
        return role;
    }
  }

  String _getUserTypeDisplayName(String userType) {
    switch (userType) {
      case "visitor":
        return "Visitor (Browse events only)";
      case "participant":
        return "Participant (Register for events)";
      default:
        return userType;
    }
  }

  void _clearForm() {
    emailCtrl.clear();
    passCtrl.clear();
    nameCtrl.clear();
    departmentCtrl.clear();
    enrollmentCtrl.clear();
    selectedRole = "student";
    selectedUserType = "visitor";
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;

    // Basic validation
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      _showError("Please fill in all required fields");
      return;
    }

    if (!isLogin && nameCtrl.text.trim().isEmpty) {
      _showError("Please enter your full name");
      return;
    }

    if (!isLogin && selectedRole == "student" && selectedUserType == "participant") {
      if (departmentCtrl.text.trim().isEmpty || enrollmentCtrl.text.trim().isEmpty) {
        _showError("Student participants must provide department and enrollment number");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        final user = await _authService.loginWithEmail(
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim(),
        );

        if (user != null && mounted) {
          _navigateToMainApp(user.uid);
        }
      } else {
        final user = await _authService.signUpWithEmail(
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim(),
          name: nameCtrl.text.trim(),
          role: selectedRole,
          userType: selectedUserType,
          department: departmentCtrl.text.trim().isEmpty ? null : departmentCtrl.text.trim(),
          enrollmentNumber: enrollmentCtrl.text.trim().isEmpty ? null : enrollmentCtrl.text.trim(),
        );

        if (user != null && mounted) {
          if (selectedRole == "organizer" || selectedRole == "admin") {
            _showSuccess("Account created successfully! Please wait for admin approval before you can access staff features.");
          } else {
            _showSuccess("Account created successfully!");
          }
          _navigateToMainApp(user.uid);
        }
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.loginWithGoogle();

      if (user != null && mounted) {
        _showSuccess("Google sign-in successful!");
        _navigateToMainApp(user.uid);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController forgotEmailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email address to receive a password reset link.'),
            SizedBox(height: 16),
            TextFormField(
              controller: forgotEmailCtrl,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (forgotEmailCtrl.text.trim().isEmpty) {
                _showError("Please enter your email address");
                return;
              }

              try {
                await _authService.resetPassword(forgotEmailCtrl.text.trim());
                Navigator.pop(context);
                _showSuccess("Password reset link sent to your email!");
              } catch (e) {
                _showError(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _navigateToMainApp(String userId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EventListScreen(userId: userId),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}