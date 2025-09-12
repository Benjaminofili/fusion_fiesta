import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Fix: Added for User class
import 'package:firebase_storage/firebase_storage.dart';
import '../logic/permissions.dart';
import '../components/auth/text_field_component.dart';
import 'user/home_screen.dart'; // Updated path per structure
import 'admin/dashboard.dart';
import 'organizer/dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController departmentCtrl = TextEditingController();
  final TextEditingController enrollmentCtrl = TextEditingController();
  String? collegeIdProofUrl;

  bool isLogin = true;
  String selectedRole = "student";
  String selectedUserType = "visitor";
  bool _isLoading = false;

  final List<String> roles = ["student", "organizer", "admin"];
  final List<String> studentTypes = ["visitor", "participant"];

  Future<void> _uploadIdProof() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png']);
    if (result != null) {
      final file = result.files.first;
      final ref = FirebaseStorage.instance.ref('id_proofs/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      await ref.putData(file.bytes!);
      final url = await ref.getDownloadURL(); // Fix: Await outside setState
      setState(() {
        collegeIdProofUrl = url;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      _showError("Please fill in all required fields");
      return;
    }
    if (!isLogin && (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty)) {
      _showError("Please enter your full name and phone");
      return;
    }
    if (!isLogin && selectedRole == "student" && selectedUserType == "participant") {
      if (departmentCtrl.text.trim().isEmpty || enrollmentCtrl.text.trim().isEmpty || collegeIdProofUrl == null) {
        _showError("Student participants must provide department, enrollment, and ID proof");
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      User? user;
      if (isLogin) {
        user = await Permissions.loginWithEmail(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      } else {
        user = await Permissions.signUpWithEmail(
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim(),
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          role: selectedRole,
          userType: selectedUserType,
          department: departmentCtrl.text.trim().isEmpty ? null : departmentCtrl.text.trim(),
          enrollmentNumber: enrollmentCtrl.text.trim().isEmpty ? null : enrollmentCtrl.text.trim(),
          collegeIdProofUrl: collegeIdProofUrl,
        );
      }
      if (user != null && mounted) {
        final data = await Permissions.getUserData();
        if (mounted) {
          _navigateByRole(data['role'], data['userType'], data['approved']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await Permissions.loginWithGoogle();
      if (user != null && mounted) {
        _showSuccess("Google sign-in successful!");
        final data = await Permissions.getUserData();
        if (mounted) {
          _navigateByRole(data['role'], data['userType'], data['approved']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController forgotEmailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email address to receive a password reset link.'),
            SizedBox(height: 16),
            TextFieldComponent(
              controller: forgotEmailCtrl,
              labelText: 'Email Address',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (forgotEmailCtrl.text.trim().isEmpty) {
                _showError("Please enter your email address");
                return;
              }
              try {
                await Permissions.resetPassword(forgotEmailCtrl.text.trim());
                Navigator.pop(context);
                _showSuccess("Password reset link sent to your email!");
              } catch (e) {
                _showError(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _navigateByRole(String role, String userType, bool approved) {
    switch (role) {
      case 'student':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UsersHomeScreen(userType: userType, uid: FirebaseAuth.instance.currentUser!.uid),
          ),
        );
        break;
      case 'admin':
        if (!approved) {
          _showError("Admin account awaiting approval");
          return;
        }
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard()));
        break;
      case 'organizer':
        if (!approved) {
          _showError("Organizer account awaiting approval");
          return;
        }
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrganizerDashboard(eventId: 'eventId')));
        break;
      default:
        _showError("Invalid role");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
    phoneCtrl.clear();
    departmentCtrl.clear();
    enrollmentCtrl.clear();
    collegeIdProofUrl = null;
    selectedRole = "student";
    selectedUserType = "visitor";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Login" : "Sign Up"),
        backgroundColor: Colors.blue[50],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.event, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    "FusionFiesta",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[800]!),
                  ),
                  Text(
                    isLogin ? "Welcome back!" : "Join our community",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!isLogin) ...[
                      TextFieldComponent(controller: nameCtrl, labelText: "Full Name *", prefixIcon: Icons.person),
                      const SizedBox(height: 16),
                      TextFieldComponent(controller: phoneCtrl, labelText: "Phone Number *", prefixIcon: Icons.phone, keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: "Select Role *",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.group),
                        ),
                        items: roles.map((role) => DropdownMenuItem(value: role, child: Text(_getRoleDisplayName(role)))).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value!;
                            selectedUserType = "visitor";
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selectedRole == "student") ...[
                        DropdownButtonFormField<String>(
                          value: selectedUserType,
                          decoration: InputDecoration(
                            labelText: "Student Type *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.school),
                          ),
                          items: studentTypes.map((type) => DropdownMenuItem(value: type, child: Text(_getUserTypeDisplayName(type)))).toList(),
                          onChanged: (value) => setState(() => selectedUserType = value!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (selectedRole == "student" && selectedUserType == "participant") ...[
                        TextFieldComponent(controller: departmentCtrl, labelText: "Department *", prefixIcon: Icons.business),
                        const SizedBox(height: 16),
                        TextFieldComponent(controller: enrollmentCtrl, labelText: "Enrollment Number *", prefixIcon: Icons.badge),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _uploadIdProof,
                          child: const Text("Upload College ID Proof"),
                        ),
                        if (collegeIdProofUrl != null) const Text("ID Proof Uploaded"),
                        const SizedBox(height: 16),
                      ],
                      if (selectedRole == "organizer" || selectedRole == "admin") ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!), // Fix: Border.all() returns BoxBorder
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Staff members must use institutional email (ending with .edu) and require admin approval.",
                                  style: TextStyle(color: Colors.orange[800]!, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    TextFieldComponent(controller: emailCtrl, labelText: "Email Address *", prefixIcon: Icons.email, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    TextFieldComponent(controller: passCtrl, labelText: "Password *", prefixIcon: Icons.lock, obscureText: true),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                          isLogin ? "Sign In" : "Create Account",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (isLogin) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.blue)),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text("OR", style: TextStyle(color: Colors.grey)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        icon: const Icon(Icons.login, color: Colors.red),
                        label: Text(
                          "Continue with Google",
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin ? "Don't have an account? " : "Already have an account? ",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                      _clearForm();
                    });
                  },
                  child: Text(
                    isLogin ? "Sign Up" : "Sign In",
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}