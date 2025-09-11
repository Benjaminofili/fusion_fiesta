import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Fix: For Timestamp type
import '../../logic/user.dart';
import '../../logic/permissions.dart';

class EventDetailScreen extends StatefulWidget { // Fix: Stateful for async userData
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isParticipant = false; // Fix: Sync bool from async fetch

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await Permissions.getUserData();
    if (mounted) {
      setState(() {
        _isParticipant = userData['userType'] == 'participant';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Event Details')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: UserLogic.getEventDetails(widget.eventId), // Fix: Calls UserLogic selector
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final event = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event['title'] ?? 'No Title', style: Theme.of(context).textTheme.headlineMedium),
                if (event['imageUrl'] != null) Image.network(event['imageUrl']),
                Text('Date/Time: ${(event['dateTime'] as Timestamp?)?.toDate()}'), // Fix: Timestamp imported
                Text('Location: ${event['location']}'),
                Text('Available Slots: ${event['slotsAvailable']}'),
                Text('Description: ${event['description'] ?? 'No description'}'),
                Text('Organizer Contact: ${event['organizerContact'] ?? 'N/A'}'), // Email/phone
                Text('Rules: ${event['rules'] ?? 'No rules'}'),
                if (event['registrationOpen'] && event['slotsAvailable'] > 0 && _isParticipant) // Fix: Use sync bool
                  ElevatedButton(
                    onPressed: () async {
                      await UserLogic.registerForEvent(widget.eventId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registered successfully!')));
                      }
                    },
                    child: const Text('Register Now'),
                  ),
                if (!event['registrationOpen']) const Text('Registration Closed'),
              ],
            ),
          );
        },
      ),
    );
  }
}