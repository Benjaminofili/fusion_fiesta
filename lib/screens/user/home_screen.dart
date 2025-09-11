import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Fix: For Timestamp type
import '../../logic/permissions.dart';
import '../../logic/user.dart';
import '../auth_screen.dart';
import 'event_detail_screen.dart'; // New detail screen (same folder/package)
import '../../components/users/event_card.dart'; // Summary card component

class UsersHomeScreen extends StatefulWidget {
  final String userType;
  const UsersHomeScreen({super.key, required this.userType});

  @override
  State<UsersHomeScreen> createState() => _UsersHomeScreenState();
}

class _UsersHomeScreenState extends State<UsersHomeScreen> {
  String _searchQuery = '';
  String _sortBy = 'newest';
  String? _category, _department;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    UserLogic.init('uid'); // From auth
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> events;
    if (_searchQuery.isNotEmpty) {
      // Use search if query active
      final results = await UserLogic.searchEvents(_searchQuery);
      events = results['matches'] ?? []; // Fix: Use search results
    } else {
      // Use browse + sort
      events = await UserLogic.browseEvents(category: _category, department: _department);
      events = await UserLogic.getSortedEvents(sortBy: _sortBy, userDepartment: _department); // Fix: Call UserLogic selector
    }
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  // Fix: Separate async method for onChanged (TextField is sync)
  Future<void> _handleSearch(String value) async {
    setState(() => _searchQuery = value);
    await _loadEvents(); // Reload with search
  }

  // Fix: Separate async method for filter/sort changes
  Future<void> _handleFilterChange() async {
    await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Events - ${widget.userType}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await Permissions.signOut();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar with Autosuggestions
          TextField(
            onChanged: (value) {
              // Fix: Call async method (but onChanged is sync; debounce if needed)
              _handleSearch(value);
            },
            decoration: const InputDecoration(
              labelText: 'Search Events (keywords/tags)',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          // Filters/Sort
          Row(
            children: [
              DropdownButton<String>(
                value: _category,
                hint: const Text('Category'),
                items: ['technical', 'cultural', 'sports'].map((c) => DropdownMenuItem(value: c, child: Text(c.capitalize))).toList(),
                onChanged: (v) {
                  setState(() => _category = v);
                  _handleFilterChange(); // Fix: Async call
                },
              ),
              if (widget.userType == 'participant') DropdownButton<String>(
                value: _department,
                hint: const Text('Department'),
                items: ['CS', 'ME', 'EE'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), // From user data
                onChanged: (v) {
                  setState(() => _department = v);
                  _handleFilterChange(); // Fix: Async call
                },
              ),
              DropdownButton<String>(
                value: _sortBy,
                items: ['newest', 'popularity', 'eligible'].map((s) => DropdownMenuItem(value: s, child: Text(s.capitalize))).toList(),
                onChanged: (v) {
                  setState(() => _sortBy = v!);
                  _handleFilterChange(); // Fix: Async call
                },
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
                return EventCard(
                  title: event['title'] ?? 'Untitled',
                  imageUrl: event['imageUrl'], // Assume field
                  dateTime: (event['dateTime'] as Timestamp?)?.toDate(), // Fix: Timestamp imported
                  location: event['location'],
                  slotsAvailable: event['slotsAvailable'] ?? 0,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event['id']))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSuggestions(List<Map<String, dynamic>> suggestions) {
    // Implement overlay or dialog with suggestion cards
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
    // Navigate to detail
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event['id'])));
  }
}

// Extension for capitalize
extension StringExtension on String {
  String get capitalize => this[0].toUpperCase() + substring(1);
}