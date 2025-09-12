import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final DateTime? dateTime;
  final String? location;
  final int slotsAvailable;
  final bool isRegistered; // Added parameter
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.dateTime,
    this.location,
    required this.slotsAvailable,
    required this.isRegistered, // Required parameter
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: imageUrl != null ? Image.network(imageUrl!, width: 50, height: 50, fit: BoxFit.cover) : const Icon(Icons.event),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateTime != null) Text('Date: ${dateTime!.toString().split(' ')[0]}'),
            if (location != null) Text('Location: $location'),
            Text('Slots: $slotsAvailable'),
            if (isRegistered) Text('Registered', style: TextStyle(color: Colors.green)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}