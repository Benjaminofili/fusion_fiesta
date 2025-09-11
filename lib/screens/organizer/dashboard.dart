import 'package:flutter/material.dart';
import '../../logic/permissions.dart';
import '../../logic/organizer.dart'; // Role selector
import '../auth_screen.dart';
// import '../../components/organizers/event_form.dart'; // Placeholder component

class OrganizerDashboard extends StatelessWidget {
  const OrganizerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Call role logic init (e.g., load events)
    OrganizerLogic.init();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Dashboard'),
        backgroundColor: Colors.green[50],
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
            Text('Organizer Panel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('Create and manage events.'),
            // Later: Form for events via components/organizers/event_form.dart
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Temp: Call organizer-specific logic
      //     OrganizerLogic.addEvent(); // Define in organizer.dart
      //   },
      //   child: const Icon(Icons.add_event),
      // ),
    );
  }
}