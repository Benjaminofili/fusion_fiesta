import 'package:flutter/material.dart';
import '../../logic/organizer.dart';
import '../../components/organizers/registration_list.dart';
import '../../logic/permissions.dart';
import '../auth_screen.dart';

class OrganizerDashboard extends StatefulWidget {
  final String eventId;
  const OrganizerDashboard({super.key, required this.eventId});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    OrganizerLogic.init();
    _loadRegistrations();
  }

  Future<void> _loadRegistrations() async {
    setState(() => _isLoading = true);
    final regs = await OrganizerLogic.getEventRegistrations(widget.eventId);
    if (mounted) setState(() { _registrations = regs; _isLoading = false; });
    debugPrint('Loaded ${regs.length} registrations for ${widget.eventId}'); // Changed to debugPrint
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizer Dashboard'),actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: () async {
            await Permissions.signOut();
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>  AuthScreen()));
            }
          },
        ),
      ], ) ,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _registrations.isEmpty
          ? const Center(child: Text('No registrations yet'))
          : RegistrationList(
        registrations: _registrations,
        onApprove: (userId) => OrganizerLogic.approveRegistration(widget.eventId, userId),
        onReject: (userId) => OrganizerLogic.rejectRegistration(widget.eventId, userId),
        onMessage: (userId, msg) => OrganizerLogic.sendMessage(widget.eventId, userId, msg),
      ),
    );
  }
}