import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is authenticated
  bool get _isAuthenticated => _auth.currentUser != null;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get user role and type from user document
  Future<Map<String, dynamic>> _getUserData() async {
    if (!_isAuthenticated || _currentUserId == null) {
      throw Exception("User not authenticated");
    }

    try {
      final doc = await _db.collection("users").doc(_currentUserId).get();
      if (!doc.exists || doc.data() == null) {
        throw Exception("User profile not found");
      }
      return doc.data()!;
    } catch (e) {
      throw Exception("Failed to fetch user data: $e");
    }
  }

  /// Add new event with role validation
  Future<void> addEvent(Map<String, dynamic> eventData) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      // Validate user role
      final userData = await _getUserData();
      final role = userData['role'] as String?;
      final status = userData['status'] as String?;

      if (role != 'organizer' && role != 'admin') {
        throw Exception("Only organizers and admins can create events");
      }

      if ((role == 'organizer' || role == 'admin') && status != 'approved') {
        throw Exception("Staff account must be approved to create events");
      }

      // Add required fields and validation
      final eventDoc = {
        ...eventData,
        "organizerId": _currentUserId,
        "createdAt": FieldValue.serverTimestamp(),
        "popularity": eventData["popularity"] ?? 0,
        "status": eventData["status"] ?? "approved",
        "currentParticipants": eventData["currentParticipants"] ?? 0,
      };

      await _db.collection("events").add(eventDoc);
    } catch (e) {
      print("Error in addEvent: $e");
      rethrow;
    }
  }

  /// Fetch all events with error handling
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final snapshot = await _db
          .collection("events")
          .where("status", whereIn: ["approved", "live", "completed"])
          .orderBy("dateTime")
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          "id": doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error in getAllEvents: $e");
      if (e.toString().contains('permission-denied')) {
        throw Exception("Access denied. Please ensure you are signed in.");
      }
      rethrow;
    }
  }

  /// Fetch events by category
  Future<List<Map<String, dynamic>>> getEventsByCategory(String category) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final snapshot = await _db
          .collection("events")
          .where("category", isEqualTo: category)
          .where("status", whereIn: ["approved", "live", "completed"])
          .orderBy("dateTime")
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          "id": doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error in getEventsByCategory: $e");
      rethrow;
    }
  }

  /// Filter events by department
  Future<List<Map<String, dynamic>>> getEventsByDepartment(String department) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final snapshot = await _db
          .collection("events")
          .where("department", isEqualTo: department)
          .where("status", whereIn: ["approved", "live", "completed"])
          .orderBy("dateTime")
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          "id": doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error in getEventsByDepartment: $e");
      rethrow;
    }
  }

  /// Filter events by date range
  Future<List<Map<String, dynamic>>> getEventsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final snapshot = await _db
          .collection("events")
          .where("dateTime", isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where("dateTime", isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where("status", whereIn: ["approved", "live", "completed"])
          .orderBy("dateTime")
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          "id": doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error in getEventsByDateRange: $e");
      rethrow;
    }
  }

  /// Get events user is eligible for based on their profile
  Future<List<Map<String, dynamic>>> getEligibleEvents() async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final userData = await _getUserData();
      final userDepartment = userData['department'] as String?;
      final userRole = userData['role'] as String?;

      // Get all approved events
      final snapshot = await _db
          .collection("events")
          .where("status", whereIn: ["approved", "live"])
          .orderBy("dateTime")
          .get();

      final allEvents = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          "id": doc.id,
          ...data,
        };
      }).toList();

      // Filter events based on eligibility rules
      final eligibleEvents = allEvents.where((event) {
        // Basic eligibility: must be a student participant to register
        if (userRole != 'student') return false;

        // Check if event is open to all departments or user's department
        final eventDepartments = event['eligibleDepartments'] as List<dynamic>?;
        if (eventDepartments != null && eventDepartments.isNotEmpty) {
          if (!eventDepartments.contains('all') &&
              !eventDepartments.contains(userDepartment)) {
            return false;
          }
        }

        // Check if slots are available
        final slotsAvailable = event['slotsAvailable'] as int? ?? 0;
        if (slotsAvailable <= 0) return false;

        // Check if event date hasn't passed
        final eventDateTime = (event['dateTime'] as Timestamp?)?.toDate();
        if (eventDateTime != null && eventDateTime.isBefore(DateTime.now())) {
          return false;
        }

        return true;
      }).toList();

      return eligibleEvents;
    } catch (e) {
      print("Error in getEligibleEvents: $e");
      rethrow;
    }
  }

  /// Search events by keywords with auto-suggestions support
  Future<List<Map<String, dynamic>>> searchEvents(String keyword) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final searchTerm = keyword.toLowerCase().trim();
      if (searchTerm.isEmpty) return [];

      // Search by tags (existing functionality)
      final tagResults = await _searchByTags(searchTerm);

      // Search by title and description
      final textResults = await _searchByText(searchTerm);

      // Combine results and remove duplicates
      final allResults = <String, Map<String, dynamic>>{};

      for (final event in tagResults) {
        allResults[event['id'] as String] = event;
      }

      for (final event in textResults) {
        allResults[event['id'] as String] = event;
      }

      return allResults.values.toList();
    } catch (e) {
      print("Error in searchEvents: $e");
      rethrow;
    }
  }

  /// Search events by tags
  Future<List<Map<String, dynamic>>> _searchByTags(String keyword) async {
    final snapshot = await _db
        .collection("events")
        .where("tags", arrayContains: keyword)
        .where("status", whereIn: ["approved", "live", "completed"])
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return <String, dynamic>{
        "id": doc.id,
        ...data,
      };
    }).toList();
  }

  /// Search events by text content (title, description)
  Future<List<Map<String, dynamic>>> _searchByText(String keyword) async {
    // Since Firestore doesn't support full-text search, we'll get all events
    // and filter in memory (for production, consider using Algolia or similar)
    final snapshot = await _db
        .collection("events")
        .where("status", whereIn: ["approved", "live", "completed"])
        .get();

    final allEvents = snapshot.docs.map((doc) {
      final data = doc.data();
      return <String, dynamic>{
        "id": doc.id,
        ...data,
      };
    }).toList();

    return allEvents.where((event) {
      final title = (event['title'] as String?)?.toLowerCase() ?? '';
      final description = (event['description'] as String?)?.toLowerCase() ?? '';
      final category = (event['category'] as String?)?.toLowerCase() ?? '';
      final location = (event['location'] as String?)?.toLowerCase() ?? '';

      return title.contains(keyword) ||
          description.contains(keyword) ||
          category.contains(keyword) ||
          location.contains(keyword);
    }).toList();
  }

  /// Get search suggestions based on keywords
  Future<List<String>> getSearchSuggestions(String query) async {
    if (!_isAuthenticated) throw Exception("Authentication required");
    if (query.length < 2) return [];

    try {
      final searchTerm = query.toLowerCase().trim();

      // Get all events to extract suggestions
      final snapshot = await _db
          .collection("events")
          .where("status", whereIn: ["approved", "live", "completed"])
          .limit(100) // Limit for performance
          .get();

      final suggestions = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Extract suggestions from title
        final title = data['title'] as String? ?? '';
        if (title.toLowerCase().contains(searchTerm)) {
          suggestions.add(title);
        }

        // Extract suggestions from tags
        final tags = data['tags'] as List<dynamic>? ?? [];
        for (final tag in tags) {
          final tagStr = tag.toString().toLowerCase();
          if (tagStr.contains(searchTerm)) {
            suggestions.add(tag.toString());
          }
        }

        // Extract suggestions from category
        final category = data['category'] as String? ?? '';
        if (category.toLowerCase().contains(searchTerm)) {
          suggestions.add(category);
        }
      }

      return suggestions.take(10).toList(); // Return top 10 suggestions
    } catch (e) {
      print("Error in getSearchSuggestions: $e");
      return [];
    }
  }

  /// Sort events with better error handling
  Future<List<Map<String, dynamic>>> sortEvents(String sortBy) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      Query query = _db
          .collection("events")
          .where("status", whereIn: ["approved", "live", "completed"]);

      switch (sortBy) {
        case "newest":
          query = query.orderBy("createdAt", descending: true);
          break;
        case "popular":
          query = query.orderBy("popularity", descending: true);
          break;
        case "eligible":
        // For eligible events, we need to get all and filter
          return await getEligibleEvents();
        case "upcoming":
        default:
          query = query.orderBy("dateTime");
          break;
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          "id": doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error in sortEvents: $e");
      rethrow;
    }
  }

  /// Get event details with full information
  Future<Map<String, dynamic>?> getEventDetails(String eventId) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final doc = await _db.collection("events").doc(eventId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // Get organizer details
        final organizerId = data['organizerId'] as String?;
        Map<String, dynamic>? organizerData;

        if (organizerId != null) {
          final organizerDoc = await _db.collection("users").doc(organizerId).get();
          if (organizerDoc.exists) {
            organizerData = organizerDoc.data();
          }
        }

        return <String, dynamic>{
          "id": doc.id,
          ...data,
          "organizer": organizerData,
        };
      }
      return null;
    } catch (e) {
      print("Error in getEventDetails: $e");
      rethrow;
    }
  }

  /// Check if user can register for a specific event
  Future<Map<String, dynamic>> checkRegistrationEligibility(String eventId) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      final userData = await _getUserData();
      final eventData = await getEventDetails(eventId);

      if (eventData == null) {
        return {
          'canRegister': false,
          'reason': 'Event not found',
        };
      }

      // Check if user is student participant
      if (userData['role'] != 'student' || userData['userType'] != 'participant') {
        return {
          'canRegister': false,
          'reason': 'Only student participants can register for events',
        };
      }

      // Check if already registered
      final existingReg = await _db
          .collection("users")
          .doc(_currentUserId)
          .collection("registrations")
          .doc(eventId)
          .get();

      if (existingReg.exists) {
        return {
          'canRegister': false,
          'reason': 'Already registered for this event',
        };
      }

      // Check slots availability
      final slotsAvailable = eventData['slotsAvailable'] as int? ?? 0;
      if (slotsAvailable <= 0) {
        return {
          'canRegister': false,
          'reason': 'No slots available',
        };
      }

      // Check department eligibility
      final userDepartment = userData['department'] as String?;
      final eventDepartments = eventData['eligibleDepartments'] as List<dynamic>?;

      if (eventDepartments != null && eventDepartments.isNotEmpty) {
        if (!eventDepartments.contains('all') &&
            !eventDepartments.contains(userDepartment)) {
          return {
            'canRegister': false,
            'reason': 'Event not open to your department',
          };
        }
      }

      // Check if event date hasn't passed
      final eventDateTime = (eventData['dateTime'] as Timestamp?)?.toDate();
      if (eventDateTime != null && eventDateTime.isBefore(DateTime.now())) {
        return {
          'canRegister': false,
          'reason': 'Event registration has closed',
        };
      }

      return {
        'canRegister': true,
        'reason': 'Eligible to register',
        'slotsAvailable': slotsAvailable,
      };

    } catch (e) {
      print("Error in checkRegistrationEligibility: $e");
      return {
        'canRegister': false,
        'reason': 'Error checking eligibility: $e',
      };
    }
  }

  /// Multi-criteria filtering
  Future<List<Map<String, dynamic>>> filterEvents({
    String? category,
    String? department,
    DateTime? startDate,
    DateTime? endDate,
    int? minSlots,
    bool? eligibleOnly,
  }) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      // Start with base query
      Query query = _db
          .collection("events")
          .where("status", whereIn: ["approved", "live", "completed"]);

      // Apply filters
      if (category != null && category.isNotEmpty) {
        query = query.where("category", isEqualTo: category);
      }

      if (department != null && department.isNotEmpty) {
        query = query.where("department", isEqualTo: department);
      }

      if (startDate != null) {
        query = query.where("dateTime", isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where("dateTime", isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.orderBy("dateTime").get();

      var events = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          "id": doc.id,
          ...data,
        };
      }).toList();

      // Apply additional filters in memory
      if (minSlots != null) {
        events = events.where((event) {
          final slots = event['slotsAvailable'] as int? ?? 0;
          return slots >= minSlots;
        }).toList();
      }

      if (eligibleOnly == true) {
        final userData = await _getUserData();
        final userDepartment = userData['department'] as String?;
        final userRole = userData['role'] as String?;

        events = events.where((event) {
          if (userRole != 'student') return false;

          final eventDepartments = event['eligibleDepartments'] as List<dynamic>?;
          if (eventDepartments != null && eventDepartments.isNotEmpty) {
            if (!eventDepartments.contains('all') &&
                !eventDepartments.contains(userDepartment)) {
              return false;
            }
          }

          final slotsAvailable = event['slotsAvailable'] as int? ?? 0;
          return slotsAvailable > 0;
        }).toList();
      }

      return events;
    } catch (e) {
      print("Error in filterEvents: $e");
      rethrow;
    }
  }

  // Existing methods remain the same...

  /// Register for event with validation
  Future<void> registerForEvent(String eventId, String userId) async {
    if (!_isAuthenticated) throw Exception("Authentication required");
    if (_currentUserId != userId) throw Exception("Can only register for own account");

    try {
      // Check eligibility first
      final eligibility = await checkRegistrationEligibility(eventId);
      if (!eligibility['canRegister']) {
        throw Exception(eligibility['reason']);
      }

      final eventRef = _db.collection("events").doc(eventId);
      final userRef = _db.collection("users").doc(userId);

      await _db.runTransaction((transaction) async {
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) throw Exception("Event not found");

        final eventData = eventDoc.data()!;
        int slotsAvailable = eventData["slotsAvailable"] ?? 0;
        int currentParticipants = eventData["currentParticipants"] ?? 0;

        if (slotsAvailable <= 0) throw Exception("No slots available");

        // Update event
        transaction.update(eventRef, {
          "slotsAvailable": slotsAvailable - 1,
          "currentParticipants": currentParticipants + 1,
          "popularity": (eventData["popularity"] ?? 0) + 1,
        });

        // Add registration
        transaction.set(
          userRef.collection("registrations").doc(eventId),
          {
            "eventId": eventId,
            "registeredAt": FieldValue.serverTimestamp(),
          },
        );
      });
    } catch (e) {
      print("Error in registerForEvent: $e");
      rethrow;
    }
  }

  /// Unregister from event
  Future<void> unregisterFromEvent(String eventId, String userId) async {
    if (!_isAuthenticated) throw Exception("Authentication required");
    if (_currentUserId != userId) throw Exception("Can only unregister own account");

    try {
      final eventRef = _db.collection("events").doc(eventId);
      final userRef = _db.collection("users").doc(userId);

      await _db.runTransaction((transaction) async {
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) throw Exception("Event not found");

        final eventData = eventDoc.data()!;
        int currentParticipants = eventData["currentParticipants"] ?? 0;
        int slotsAvailable = eventData["slotsAvailable"] ?? 0;

        // Check if actually registered
        final registration = await userRef.collection("registrations").doc(eventId).get();
        if (!registration.exists) throw Exception("Not registered for this event");

        if (currentParticipants <= 0) throw Exception("No participants to remove");

        // Update event
        transaction.update(eventRef, {
          "slotsAvailable": slotsAvailable + 1,
          "currentParticipants": currentParticipants - 1,
          "popularity": math.max(0, (eventData["popularity"] ?? 0) - 1),
        });

        // Remove registration
        transaction.delete(userRef.collection("registrations").doc(eventId));
      });
    } catch (e) {
      print("Error in unregisterFromEvent: $e");
      rethrow;
    }
  }

  /// Get user's registered events
  Future<List<Map<String, dynamic>>> getUserRegisteredEvents(String userId) async {
    if (!_isAuthenticated) throw Exception("Authentication required");
    if (_currentUserId != userId) throw Exception("Can only view own registrations");

    try {
      final registrations = await _db
          .collection("users")
          .doc(userId)
          .collection("registrations")
          .get();

      List<Map<String, dynamic>> events = [];

      for (var registration in registrations.docs) {
        final eventId = registration.data()["eventId"] as String;
        final eventData = await getEventDetails(eventId);
        if (eventData != null) {
          events.add(eventData);
        }
      }

      return events;
    } catch (e) {
      print("Error in getUserRegisteredEvents: $e");
      rethrow;
    }
  }

  /// Update event with role validation
  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      // Check permissions
      final userData = await _getUserData();
      final eventDoc = await _db.collection("events").doc(eventId).get();

      if (!eventDoc.exists) throw Exception("Event not found");

      final eventData = eventDoc.data()!;
      final isOrganizer = eventData['organizerId'] == _currentUserId;
      final isAdmin = userData['role'] == 'admin' && userData['status'] == 'approved';

      if (!isOrganizer && !isAdmin) {
        throw Exception("Only event organizers or admins can update events");
      }

      await _db.collection("events").doc(eventId).update({
        ...updates,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error in updateEvent: $e");
      rethrow;
    }
  }

  /// Delete event with role validation
  Future<void> deleteEvent(String eventId) async {
    if (!_isAuthenticated) throw Exception("Authentication required");

    try {
      // Check permissions
      final userData = await _getUserData();
      final eventDoc = await _db.collection("events").doc(eventId).get();

      if (!eventDoc.exists) throw Exception("Event not found");

      final eventData = eventDoc.data()!;
      final isOrganizer = eventData['organizerId'] == _currentUserId;
      final isAdmin = userData['role'] == 'admin' && userData['status'] == 'approved';

      if (!isOrganizer && !isAdmin) {
        throw Exception("Only event organizers or admins can delete events");
      }

      await _db.collection("events").doc(eventId).delete();
    } catch (e) {
      print("Error in deleteEvent: $e");
      rethrow;
    }
  }
}