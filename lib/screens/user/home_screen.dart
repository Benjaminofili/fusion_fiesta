import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../logic/permissions.dart';
import '../../logic/user.dart';
import '../auth_screen.dart';
import 'event_detail_screen.dart';
import 'upgrade_screen.dart';
import '../../components/users/event_card.dart';

class UsersHomeScreen extends StatefulWidget {
  final String userType;
  final String uid;
  const UsersHomeScreen({super.key, required this.userType, required this.uid});

  @override
  State<UsersHomeScreen> createState() => _UsersHomeScreenState();
}

class _UsersHomeScreenState extends State<UsersHomeScreen> {
  String _searchQuery = '';
  String _sortBy = 'newest';
  String? _category, _department;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _registeredEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    UserLogic.init(widget.uid);
    _loadEvents();
    _loadRegisteredEvents();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> events;
    if (_searchQuery.isNotEmpty) {
      final results = await UserLogic.searchEvents(_searchQuery);
      events = results['matches'] ?? [];
    } else {
      events = await UserLogic.browseEvents(category: _category, department: _department);
    }
    final sortedEvents = await UserLogic.getSortedEvents(events: events, sortBy: _sortBy, userDepartment: _department);
    if (mounted) {
      setState(() {
        _events = sortedEvents;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRegisteredEvents() async {
    if (!mounted) return;
    final events = await UserLogic.getUserRegisteredEvents();
    if (mounted) setState(() => _registeredEvents = events);
  }

  Future<void> _handleSearch(String value) async {
    if (!mounted || value == _searchQuery) return;
    setState(() => _searchQuery = value);
    await _loadEvents();
    if (value.isNotEmpty && mounted) {
      final results = await UserLogic.searchEvents(value);
      _showSuggestions(results['suggestions'] ?? []);
    }
  }

  Future<void> _handleFilterChange() async {
    if (!mounted) return;
    await _loadEvents();
  }

  Future<void> _registerForEvent(String eventId) async {
    if (!mounted) return;
    try {
      await UserLogic.registerForEvent(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registered successfully!')));
        await _loadRegisteredEvents();
        await _updateEventList(eventId); // Refresh event list after registration
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('Complete your project')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => UpgradeScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unregisterFromEvent(String eventId) async {
    if (!mounted) return;
    try {
      await UserLogic.unregisterFromEvent(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unregistered successfully!')));
        await _loadRegisteredEvents();
        await _updateEventList(eventId); // Refresh event list after unregistration
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateEventList(String eventId) async {
    final index = _events.indexWhere((e) => e['id'] == eventId);
    if (index != -1) {
      final isRegistered = await UserLogic.isUserRegisteredForEvent(eventId);
      setState(() {
        _events[index]['isRegistered'] = isRegistered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              onChanged: _handleSearch,
              decoration: const InputDecoration(labelText: 'Search Events'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _sortBy,
                  items: ['newest', 'popularity', 'eligible'].map((s) => DropdownMenuItem(value: s, child: Text(s.capitalize))).toList(),
                  onChanged: (v) {
                    if (mounted) setState(() => _sortBy = v!);
                    _handleFilterChange();
                  },
                ),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return FutureBuilder<bool>(
                  future: UserLogic.isUserRegisteredForEvent(event['id']),
                  builder: (context, snapshot) {
                    final isRegistered = snapshot.data ?? false;
                    return EventCard(
                      title: event['title'] ?? 'Untitled',
                      imageUrl: event['imageUrl'],
                      dateTime: (event['dateTime'] as Timestamp?)?.toDate(),
                      location: event['location'],
                      slotsAvailable: event['slotsAvailable'] ?? 0,
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailScreen(
                              eventId: event['id'],
                              onRegister: () => _registerForEvent(event['id']),
                              onUnregister: () => _unregisterFromEvent(event['id']),
                            ),
                          ),
                        );
                      }, isRegistered: isRegistered,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSuggestions(List<Map<String, dynamic>> suggestions) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggestions'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(suggestions[index]['title'] ?? ''),
              onTap: () => _selectSuggestion(suggestions[index]),
            ),
          ),
        ),
      ),
    );
  }

  void _selectSuggestion(Map<String, dynamic> event) {
    Navigator.pop(context);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(
            eventId: event['id'],
            onRegister: () => _registerForEvent(event['id']),
            onUnregister: () => _unregisterFromEvent(event['id']),
          ),
        ),
      );
    }
  }
}

extension StringExtension on String {
  String get capitalize => isEmpty ? '' : this[0].toUpperCase() + substring(1);
}