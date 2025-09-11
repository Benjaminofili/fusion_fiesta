import 'package:flutter/material.dart';
import '../../logic/permissions.dart';
import '../../logic/admin.dart'; // Role selector
import '../auth_screen.dart';
// import '../../components/admins/approval_list.dart'; // Placeholder component

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Call role logic init (e.g., load pending approvals)
    AdminLogic.init();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red[50],
        actions: [
          // Temp logout button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await Permissions.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Admin Panel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('Manage approvals and events.'),
            // Later: ListView of pending staff via components/admins/approval_list.dart
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Temp: Call admin-specific logic
          AdminLogic.handleApproval('temp_uid');
        },
        child: const Icon(Icons.approval),
      ),
    );
  }
}