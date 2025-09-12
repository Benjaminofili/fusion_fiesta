import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../logic/user.dart';
import '../../logic/permissions.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final VoidCallback? onRegister, onUnregister;
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.onRegister,
    this.onUnregister,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isParticipant = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await Permissions.getUserData();
    if (mounted) {
      setState(() => _isParticipant = userData['userType'] == 'participant');
      print('UserType: ${userData['userType']}, isParticipant: $_isParticipant');
    }
  }

  void _refreshAfterAction() {
    if (mounted) setState(() {}); // Trigger a rebuild to refresh the Stream
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: UserLogic.getEventDetails(widget.eventId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final event = snapshot.data!;
          print('Event Data: registrationOpen: ${event['registrationOpen']}, slotsAvailable: ${event['slotsAvailable']}'); // Debug
          return StreamBuilder<bool>(
            stream: UserLogic.isUserRegisteredForEventStream(widget.eventId),
            builder: (context, registrationSnapshot) {
              if (!registrationSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final isRegistered = registrationSnapshot.data!;
              final qrDataFuture = isRegistered ? UserLogic.getUserRegistrationForEvent(widget.eventId) : Future.value(null);
              print('isRegistered: $isRegistered'); // Debug
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? 'No Title',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (event['imageUrl'] != null) Image.network(event['imageUrl']),
                    Text('Date/Time: ${(event['dateTime'] as Timestamp?)?.toDate() ?? 'N/A'}'),
                    Text('Location: ${event['location'] ?? 'N/A'}'),
                    Text('Available Slots: ${event['slotsAvailable'] ?? 0}'),
                    Text('Description: ${event['description'] ?? 'No description'}'),
                    Text('Organizer Contact: ${event['organizerContact'] ?? 'N/A'}'),
                    Text('Rules: ${event['rules'] ?? 'No rules'}'),
                    if (isRegistered)
                      FutureBuilder<Map<String, dynamic>?>(
                        future: qrDataFuture,
                        builder: (context, qrSnapshot) {
                          if (!qrSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final qrData = qrSnapshot.data?['qrData'] as String?;
                          if (qrData == null) return const SizedBox.shrink();
                          return QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 100,
                            backgroundColor: Colors.white,
                          );
                        },
                      ),
                    if (event['registrationOpen'] == true && event['slotsAvailable'] > 0 && _isParticipant && !isRegistered)
                      ElevatedButton(
                        onPressed: () {
                          if (widget.onRegister != null) {
                            widget.onRegister!();
                            _refreshAfterAction();
                          }
                        },
                        child: const Text('Register Now'),
                      ),
                    if (isRegistered)
                      ElevatedButton(
                        onPressed: () {
                          if (widget.onUnregister != null) {
                            widget.onUnregister!();
                            _refreshAfterAction();
                          }
                        },
                        child: const Text('Unregister'),
                      ),
                    if (event['registrationOpen'] != true)
                      const Text('Registration Closed'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}