import 'package:flutter/material.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';

class EventListScreen extends StatefulWidget {
  final String userId;

  const EventListScreen({super.key, required this.userId});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen>
    with TickerProviderStateMixin {
  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _registeredEvents = [];
  bool _isLoading = false;
  String _currentFilter = 'all';
  String _currentSort = 'upcoming';
  String _userRole = 'student';
  String _userType = 'visitor';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _slotsController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _slotsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final roleAndType = await _authService.getUserRoleAndType();
      setState(() {
        _userRole = roleAndType['role'] ?? 'student';
        _userType = roleAndType['userType'] ?? 'visitor';
      });
    } catch (e) {
      _showError('Failed to load user profile: $e');
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      // First check authentication
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        _showError('User not authenticated. Please sign in again.');
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      // Check if user document exists
      final userProfile = await _authService.getCurrentUserProfile();
      if (userProfile == null) {
        _showError('User profile not found. Please contact support.');
        return;
      }

      print('Loading events for user: ${currentUser.uid}');
      print('User role: ${userProfile['role']}, Type: ${userProfile['userType']}');

      List<Map<String, dynamic>> events;

      switch (_currentFilter) {
        case 'all':
          events = await _eventService.getAllEvents();
          break;
        case 'academic':
        case 'sports':
        case 'cultural':
        case 'technical':
          events = await _eventService.getEventsByCategory(_currentFilter);
          break;
        default:
          events = await _eventService.sortEvents(_currentSort);
      }

      // Apply sorting if not already sorted by filter
      if (_currentFilter == 'all' || !['newest', 'popular', 'upcoming'].contains(_currentFilter)) {
        events = await _eventService.sortEvents(_currentSort);
      }

      print('Loaded ${events.length} events');
      setState(() {
        _events = events;
      });
    } catch (e) {
      print('Error loading events: $e');
      _showError('Failed to load events: ${e.toString().replaceAll('Exception: ', '')}');

      // If permission denied, show helpful message
      if (e.toString().contains('permission-denied')) {
        _showError('Permission denied. Please ensure you are properly signed in and your account is approved.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRegisteredEvents() async {
    if (_userRole == 'student' && _userType == 'participant') {
      try {
        final registeredEvents = await _eventService.getUserRegisteredEvents(widget.userId);
        setState(() {
          _registeredEvents = registeredEvents;
        });
      } catch (e) {
        _showError('Failed to load registered events: $e');
      }
    }
  }

  Future<void> _searchEvents(String keyword) async {
    if (keyword.isEmpty) {
      _loadEvents();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final searchResults = await _eventService.searchEvents(keyword);
      setState(() {
        _events = searchResults;
      });
    } catch (e) {
      _showError('Search failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerForEvent(String eventId) async {
    if (_userRole != 'student' || _userType != 'participant') {
      _showError('Only student participants can register for events');
      return;
    }

    try {
      await _eventService.registerForEvent(eventId, widget.userId);
      _showSuccess('Successfully registered for event!');
      _loadEvents();
      _loadRegisteredEvents();
    } catch (e) {
      _showError('Registration failed: $e');
    }
  }

  Future<void> _unregisterFromEvent(String eventId) async {
    try {
      await _eventService.unregisterFromEvent(eventId, widget.userId);
      _showSuccess('Successfully unregistered from event!');
      _loadEvents();
      _loadRegisteredEvents();
    } catch (e) {
      _showError('Unregistration failed: $e');
    }
  }

  Future<void> _addEvent() async {
    if (_userRole != 'organizer' && _userRole != 'admin') {
      _showError('Only organizers and admins can add events');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Event Title'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _venueController,
                decoration: InputDecoration(labelText: 'Venue'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _slotsController,
                decoration: InputDecoration(labelText: 'Available Slots'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_titleController.text.isEmpty) {
                _showError('Please enter event title');
                return;
              }

              try {
                final eventData = {
                  'title': _titleController.text,
                  'description': _descriptionController.text,
                  'venue': _venueController.text,
                  'slotsAvailable': int.tryParse(_slotsController.text) ?? 50,
                  'currentParticipants': 0,
                  'category': 'general',
                  'organizerId': widget.userId,
                  'dateTime': DateTime.now().add(Duration(days: 7)),
                  'tags': ['event', 'general'],
                  'popularity': 0,
                  'status': 'approved',
                };

                await _eventService.addEvent(eventData);
                _showSuccess('Event added successfully!');
                _clearEventForm();
                Navigator.pop(context);
                _loadEvents();
              } catch (e) {
                _showError('Failed to add event: $e');
              }
            },
            child: Text('Add Event'),
          ),
        ],
      ),
    );
  }

  Future<void> _editEvent(Map<String, dynamic> event) async {
    if (_userRole != 'organizer' && _userRole != 'admin') {
      _showError('Only organizers and admins can edit events');
      return;
    }

    _titleController.text = event['title'] ?? '';
    _descriptionController.text = event['description'] ?? '';
    _venueController.text = event['venue'] ?? '';
    _slotsController.text = (event['slotsAvailable'] ?? 0).toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Event Title'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _venueController,
                decoration: InputDecoration(labelText: 'Venue'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _slotsController,
                decoration: InputDecoration(labelText: 'Available Slots'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updates = {
                  'title': _titleController.text,
                  'description': _descriptionController.text,
                  'venue': _venueController.text,
                  'slotsAvailable': int.tryParse(_slotsController.text) ?? event['slotsAvailable'],
                };

                await _eventService.updateEvent(event['id'], updates);
                _showSuccess('Event updated successfully!');
                _clearEventForm();
                Navigator.pop(context);
                _loadEvents();
              } catch (e) {
                _showError('Failed to update event: $e');
              }
            },
            child: Text('Update Event'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    if (_userRole != 'admin') {
      _showError('Only admins can delete events');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event'),
        content: Text('Are you sure you want to delete this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _eventService.deleteEvent(eventId);
                _showSuccess('Event deleted successfully!');
                Navigator.pop(context);
                _loadEvents();
              } catch (e) {
                _showError('Failed to delete event: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _clearEventForm() {
    _titleController.clear();
    _descriptionController.clear();
    _venueController.clear();
    _slotsController.clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FusionFiesta Events'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
        bottom: _tabController == null ? null : TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All Events'),
            if (_userRole == 'student' && _userType == 'participant')
              Tab(text: 'My Events'),
            Tab(text: 'Profile'),
          ],
          onTap: (index) {
            // Handle My Events tab tap for student participants
            if (_userRole == 'student' && _userType == 'participant' && index == 1) {
              _loadRegisteredEvents();
            }
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Events Tab
          Column(
            children: [
              // Search and Filter Controls
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search events by tags...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadEvents();
                          },
                        ),
                      ),
                      onSubmitted: _searchEvents,
                    ),
                    SizedBox(height: 16),

                    // Filter and Sort Row
                    Row(
                      children: [
                        // Category Filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _currentFilter,
                            decoration: InputDecoration(
                              labelText: 'Filter',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(value: 'all', child: Text('All Events')),
                              DropdownMenuItem(value: 'academic', child: Text('Academic')),
                              DropdownMenuItem(value: 'sports', child: Text('Sports')),
                              DropdownMenuItem(value: 'cultural', child: Text('Cultural')),
                              DropdownMenuItem(value: 'technical', child: Text('Technical')),
                            ],
                            onChanged: (value) {
                              setState(() => _currentFilter = value!);
                              _loadEvents();
                            },
                          ),
                        ),
                        SizedBox(width: 16),

                        // Sort Options
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _currentSort,
                            decoration: InputDecoration(
                              labelText: 'Sort',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                              DropdownMenuItem(value: 'popular', child: Text('Popular')),
                              DropdownMenuItem(value: 'newest', child: Text('Newest')),
                            ],
                            onChanged: (value) {
                              setState(() => _currentSort = value!);
                              _loadEvents();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Events List
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _events.isEmpty
                    ? Center(child: Text('No events found'))
                    : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return _buildEventCard(event);
                  },
                ),
              ),
            ],
          ),

          // My Events Tab (for student participants)
          if (_userRole == 'student' && _userType == 'participant')
            _registeredEvents.isEmpty
                ? Center(child: Text('No registered events'))
                : ListView.builder(
              itemCount: _registeredEvents.length,
              itemBuilder: (context, index) {
                final event = _registeredEvents[index];
                return _buildEventCard(event, isRegistered: true);
              },
            ),

          // Profile Tab
          _buildProfileTab(),
        ],
      ),
      floatingActionButton: (_userRole == 'organizer' || _userRole == 'admin')
          ? FloatingActionButton(
        onPressed: _addEvent,
        child: Icon(Icons.add),
        tooltip: 'Add Event',
      )
          : null,
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, {bool isRegistered = false}) {
    final DateTime? eventDate = event['dateTime']?.toDate();

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event['title'] ?? 'Untitled Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_userRole == 'organizer' || _userRole == 'admin')
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Text('Edit'),
                        onTap: () => Future.delayed(
                          Duration.zero,
                              () => _editEvent(event),
                        ),
                      ),
                      if (_userRole == 'admin')
                        PopupMenuItem(
                          child: Text('Delete'),
                          onTap: () => Future.delayed(
                            Duration.zero,
                                () => _deleteEvent(event['id']),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(event['description'] ?? 'No description'),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(event['venue'] ?? 'TBA'),
                SizedBox(width: 16),
                Icon(Icons.people, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('${event['currentParticipants'] ?? 0}/${event['slotsAvailable'] ?? 0}'),
              ],
            ),
            if (eventDate != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('${eventDate.day}/${eventDate.month}/${eventDate.year}'),
                ],
              ),
            ],
            SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(event['category'] ?? 'General'),
                  backgroundColor: Colors.blue.shade100,
                ),
                SizedBox(width: 8),
                Icon(Icons.favorite, size: 16, color: Colors.red),
                Text(' ${event['popularity'] ?? 0}'),
              ],
            ),
            SizedBox(height: 12),

            // Action Buttons
            if (_userRole == 'student' && _userType == 'participant')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isRegistered)
                    ElevatedButton(
                      onPressed: () => _unregisterFromEvent(event['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Unregister'),
                    )
                  else
                    ElevatedButton(
                      onPressed: (event['slotsAvailable'] ?? 0) > 0
                          ? () => _registerForEvent(event['id'])
                          : null,
                      child: Text((event['slotsAvailable'] ?? 0) > 0 ? 'Register' : 'Full'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('User ID: ${widget.userId}'),
                  Text('Role: $_userRole'),
                  Text('Type: $_userType'),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Action Buttons
          if (_userRole == 'student' && _userType == 'visitor')
            ElevatedButton(
              onPressed: () {
                _showError('Upgrade to participant functionality would be implemented here');
              },
              child: Text('Upgrade to Participant'),
            ),

          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}