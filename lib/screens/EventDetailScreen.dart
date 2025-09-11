import 'package:flutter/material.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final String userId;

  const EventDetailScreen({super.key, required this.eventId, required this.userId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _event;
  bool _isLoading = true;
  bool _canRegister = false;
  String _registrationError = '';

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
    _checkRegistrationEligibility();
  }

  Future<void> _loadEventDetails() async {
    try {
      final event = await _eventService.getEventDetails(widget.eventId);
      setState(() {
        _event = event;
        _isLoading = false;
      });
    } catch (e) {
      // Handle error
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkRegistrationEligibility() async {
    try {
      final eligibility = await _eventService.checkRegistrationEligibility(widget.eventId);
      setState(() {
        _canRegister = eligibility['canRegister'] ?? false;
        _registrationError = eligibility['reason'] ?? '';
      });
    } catch (e) {
      setState(() {
        _canRegister = false;
        _registrationError = 'Error checking eligibility';
      });
    }
  }

  Future<void> _registerForEvent() async {
    try {
      await _eventService.registerForEvent(widget.eventId, widget.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully registered for event!')),
      );
      _checkRegistrationEligibility();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Event Details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Event Details')),
        body: Center(child: Text('Event not found')),
      );
    }

    final event = _event!;
    final DateTime? eventDate = event['dateTime']?.toDate();
    final String? imageUrl = event['optimizedImageUrl'] ?? event['imageUrl'];

    return Scaffold(
      appBar: AppBar(title: Text('Event Details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                margin: EdgeInsets.only(bottom: 16),
              ),

            // Event Title
            Text(
              event['title'] ?? 'Untitled Event',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Event Details
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20),
                SizedBox(width: 8),
                Text(eventDate != null
                    ? '${eventDate.day}/${eventDate.month}/${eventDate.year}'
                    : 'Date not specified'),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 20),
                SizedBox(width: 8),
                Text(eventDate != null
                    ? '${eventDate.hour}:${eventDate.minute.toString().padLeft(2, '0')}'
                    : 'Time not specified'),
              ],
            ),
            SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.location_on, size: 20),
                SizedBox(width: 8),
                Text(event['venue'] ?? 'Venue not specified'),
              ],
            ),
            SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.people, size: 20),
                SizedBox(width: 8),
                Text('${event['currentParticipants'] ?? 0} / ${event['slotsAvailable'] ?? 0} slots filled'),
              ],
            ),
            SizedBox(height: 16),

            // Category and Department
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(event['category'] ?? 'General'),
                  backgroundColor: Colors.blue.shade100,
                ),
                Chip(
                  label: Text(event['department'] ?? 'General'),
                  backgroundColor: Colors.green.shade100,
                ),
              ],
            ),
            SizedBox(height: 16),

            // Full Description
            Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              event['description'] ?? 'No description available',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),

            // Organizer Info
            if (event['organizer'] != null) ...[
              Text(
                'Organizer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.person),
                title: Text(event['organizer']['name'] ?? 'Unknown'),
                subtitle: Text(event['organizer']['department'] ?? ''),
              ),
            ],

            // Event Rules
            if (event['eventRules'] != null && event['eventRules'].isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Event Rules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(event['eventRules']),
            ],

            // Registration Button
            if (_canRegister)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 24),
                child: ElevatedButton(
                  onPressed: _registerForEvent,
                  child: Text('Register for Event'),
                ),
              )
            else if (_registrationError.isNotEmpty)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 24),
                child: Text(
                  _registrationError,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}