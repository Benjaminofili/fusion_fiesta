import 'package:flutter/material.dart';

class RegistrationList extends StatelessWidget {
  final List<Map<String, dynamic>> registrations;
  final Function(String) onApprove, onReject;
  final Function(String, String) onMessage;
  const RegistrationList({super.key, required this.registrations, required this.onApprove, required this.onReject, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: registrations.length,
      itemBuilder: (context, index) {
        final reg = registrations[index];
        return ListTile(
          title: Text(reg['uid'] ?? 'Unknown User'),
          subtitle: Text('Status: ${reg['status'] ?? 'pending'}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.check), onPressed: () => onApprove(reg['uid'])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => onReject(reg['uid'])),
          ]),
          onTap: () {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text('Message ${reg['uid']}'), content: TextField(decoration: const InputDecoration(labelText: 'Message'), onSubmitted: (msg) { onMessage(reg['uid'], msg); Navigator.pop(context); })));
          },
        );
      },
    );
  }
}