import 'package:flutter/material.dart';
import '../../logic/permissions.dart';
import '../../logic/admin.dart';
import '../auth_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    AdminLogic.init();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    setState(() => _isLoading = true);
    final approvals = await AdminLogic.getPendingApprovals();
    if (mounted) setState(() { _pendingApprovals = approvals; _isLoading = false; });
    debugPrint('Loaded ${_pendingApprovals.length} pending approvals'); // Changed to debugPrint
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red[50],
        actions: [
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingApprovals.isEmpty
          ? const Center(child: Text('No pending approvals'))
          : ListView.builder(
        itemCount: _pendingApprovals.length,
        itemBuilder: (context, index) {
          final approval = _pendingApprovals[index];
          return ListTile(
            title: Text('User: ${approval['email']}'),
            trailing: ElevatedButton(
              onPressed: () => AdminLogic.handleApproval(approval['userId']),
              child: const Text('Approve'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadPendingApprovals,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}