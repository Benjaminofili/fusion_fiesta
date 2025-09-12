import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'dart:convert'; // For base64 hash
import 'dart:math' as math;
import 'package:qr_flutter/qr_flutter.dart'; // Add to pubspec.yaml

class Permissions {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Permission map (updated for registration features)
  static final Map<String, List<String>> rolePermissions = {
    'student': ['signup', 'login', 'resetPassword', 'upgradeToParticipant', 'getCurrentUserProfile', 'getAllEvents', 'searchEvents', 'getSortedEvents', 'getEventDetails', 'registerForEvent', 'unregisterFromEvent', 'getUserRegisteredEvents'],
    'organizer': ['signup', 'login', 'resetPassword', 'getCurrentUserProfile', 'addEvent', 'updateEvent', 'deleteEvent', 'getAllEvents', 'searchEvents', 'getSortedEvents', 'getEventDetails', 'getEventRegistrations', 'approveRegistration', 'rejectRegistration', 'sendMessage'],
    'admin': ['signup', 'login', 'resetPassword', 'approveStaff', 'getPendingStaffApprovals', 'getCurrentUserProfile', 'addEvent', 'updateEvent', 'deleteEvent', 'getAllEvents', 'searchEvents', 'getSortedEvents', 'getEventDetails', 'getEventRegistrations', 'approveRegistration', 'rejectRegistration', 'sendMessage'],
  };

  static bool hasPermission(String role, String feature) {
    return rolePermissions[role]?.contains(feature) ?? false;
  }

  // Local storage methods (name, email, phone, password hashed, role, userType, etc.)
  static Future<void> saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', data['uid'] ?? '');
    await prefs.setString('email', data['email'] ?? '');
    await prefs.setString('name', data['name'] ?? '');
    await prefs.setString('phone', data['phone'] ?? '');
    await prefs.setString('role', data['role'] ?? 'student');
    await prefs.setString('userType', data['userType'] ?? 'visitor');
    await prefs.setString('department', data['department'] ?? '');
    await prefs.setString('enrollmentNumber', data['enrollmentNumber'] ?? '');
    await prefs.setString('collegeIdProofUrl', data['collegeIdProofUrl'] ?? '');
    await prefs.setString('password', base64Encode(utf8.encode(data['password'] ?? ''))); // Hash
    await prefs.setBool('approved', data['approved'] ?? true);
  }

  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? hashedPass = prefs.getString('password');
    return {
      'uid': prefs.getString('uid') ?? '',
      'email': prefs.getString('email') ?? '',
      'name': prefs.getString('name') ?? '',
      'phone': prefs.getString('phone') ?? '',
      'role': prefs.getString('role') ?? 'student',
      'userType': prefs.getString('userType') ?? 'visitor',
      'department': prefs.getString('department') ?? '',
      'enrollmentNumber': prefs.getString('enrollmentNumber') ?? '',
      'collegeIdProofUrl': prefs.getString('collegeIdProofUrl') ?? '',
      'password': hashedPass != null ? utf8.decode(base64Decode(hashedPass)) : '',
      'approved': prefs.getBool('approved') ?? true,
    };
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role') ?? 'student';
  }

  static Future<String> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userType') ?? 'visitor';
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Signup (SRS: role selection, additional participant details, staff email)
  static Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role, // 'student', 'organizer', 'admin'
    String userType = 'visitor', // For student only
    String? department,
    String? enrollmentNumber,
    String? collegeIdProofUrl,
    String? profileImageUrl,
  }) async {
    if (role == 'student' && !['visitor', 'participant'].contains(userType)) {
      throw Exception('Invalid student type');
    }
    if (role != 'student') userType = '';
    if ((role == 'organizer' || role == 'admin') && !email.endsWith('.edu')) {
      throw Exception('Staff must use .edu email');
    }
    if (role == 'student' && userType == 'participant') {
      if ((department?.isEmpty ?? true) || (enrollmentNumber?.isEmpty ?? true) || (collegeIdProofUrl?.isEmpty ?? true)) {
        throw Exception('Participant details required');
      }
    }

    UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    User? user = result.user;

    if (user != null) {
      final userDoc = {
        'uid': user.uid,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'userType': userType,
        'department': department ?? '',
        'enrollmentNumber': enrollmentNumber ?? '',
        'collegeIdProofUrl': collegeIdProofUrl ?? '',
        'profileImageUrl': profileImageUrl ?? '',
        'approved': (role == 'organizer' || role == 'admin') ? false : true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('users').doc(user.uid).set(userDoc);
      await saveUserData({...userDoc, 'password': password});
    }
    return user;
  }

  // Login (SRS: secure email/password, check approval for staff)
  static Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    User? user = result.user;

    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        if ((data['role'] == 'organizer' || data['role'] == 'admin') && !data['approved']) {
          throw Exception('Pending approval');
        }
        await _db.collection('users').doc(user.uid).update({'lastLoginAt': FieldValue.serverTimestamp()});
        await saveUserData({...data, 'uid': user.uid, 'password': password});
      }
    }
    return user;
  }

  // Google login (defaults to student visitor)
  static Future<User?> loginWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

    UserCredential result = await _auth.signInWithCredential(credential);
    User? user = result.user;

    if (user != null) {
      final docRef = _db.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? '',
          'phone': '',
          'role': 'student',
          'userType': 'visitor',
          'department': '',
          'enrollmentNumber': '',
          'collegeIdProofUrl': '',
          'profileImageUrl': user.photoURL ?? '',
          'approved': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({'lastLoginAt': FieldValue.serverTimestamp()});
      }
      final updatedDoc = await docRef.get();
      await saveUserData(updatedDoc.data() ?? {});
    }
    return user;
  }

  // Upgrade to participant (SRS: add details for event registration)
  static Future<void> upgradeToParticipant({
    required String department,
    required String enrollmentNumber,
    required String collegeIdProofUrl,
  }) async {
    if (department.isEmpty || enrollmentNumber.isEmpty || collegeIdProofUrl.isEmpty) {
      throw Exception('Invalid upgrade: All fields are required');
    }
    final userId = FirebaseAuth.instance.currentUser!.uid;
    if (userId.isEmpty) throw Exception('User not authenticated');
    final db = FirebaseFirestore.instance;
    await db.collection('users').doc(userId).update({
      'department': department,
      'enrollmentNumber': enrollmentNumber,
      'collegeIdProofUrl': collegeIdProofUrl,
      'userType': 'participant',
      'approved': false, // Pending approval
    });
    debugPrint('Upgrade successful for $userId');
  }

  // Forgot password (SRS: reset via secure token/email)
  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Approval for staff (SRS: admin approves)
  static Future<void> approveStaff(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists || (userDoc.data()!['role'] != 'organizer' && userDoc.data()!['role'] != 'admin')) throw Exception('Invalid');

    await _db.collection('users').doc(uid).update({'approved': true, 'approvedAt': FieldValue.serverTimestamp()});
  }

  static Future<List<Map<String, dynamic>>> getPendingStaffApprovals() async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) {
      throw Exception('Authentication required');
    }
    try {
      final snapshot = await _db.collection('users')
          .where('approved', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'userId': doc.id,
      }).toList();
    } catch (e) {
      debugPrint('Error in getPendingStaffApprovals: $e');
      rethrow;
    }
  }

  // Profile fetch
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.exists ? {'uid': user.uid, ...doc.data()!} : null;
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    await clearUserData();
  }

  // **************** //
  // **** EVENTS *****//
  // **************** //
  // Event Browsing and Filtering (merged from event_service.dart)
  static Future<List<Map<String, dynamic>>> getAllEvents({
    String? category, // technical, cultural, sports
    DateTime? startDate,
    DateTime? endDate,
    String? department,
    int? minPopularity,
  }) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');

    try {
      Query<Map<String, dynamic>> query = _db.collection('events')
          .where('status', whereIn: ['approved', 'live', 'completed'])
          .orderBy('dateTime');

      if (category != null) query = query.where('category', isEqualTo: category);
      if (department != null) query = query.where('department', isEqualTo: department);
      if (minPopularity != null) query = query.where('popularity', isGreaterThanOrEqualTo: minPopularity);
      if (startDate != null) query = query.where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      if (endDate != null) query = query.where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => <String, dynamic>{
        'id': doc.id,
        ...doc.data(),
        // Summary for cards: title, image (assume 'imageUrl'), dateTime, location, slotsAvailable
      }).toList();
    } catch (e) {
      debugPrint('Error in getAllEvents: $e');
      if (e.toString().contains('permission-denied')) throw Exception('Access denied. Please sign in.');
      rethrow;
    }
  }

  // Search with autosuggestions (top 5 suggestions, full matches)
  static Future<Map<String, List<Map<String, dynamic>>>> searchEvents(String query) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');

    try {
      final snapshot = await _db.collection('events')
          .where('status', whereIn: ['approved', 'live', 'completed'])
          .get();

      List<Map<String, dynamic>> allEvents = snapshot.docs.map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()}).toList();

      List<Map<String, dynamic>> suggestions = [];
      List<Map<String, dynamic>> matches = [];

      final searchTerm = query.toLowerCase();
      for (var event in allEvents) {
        final title = (event['title'] as String?)?.toLowerCase() ?? '';
        final tags = (event['tags'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toList() ?? <String>[];
        if (title.contains(searchTerm) || tags.any((tag) => tag.contains(searchTerm))) {
          if (suggestions.length < 5) suggestions.add(event);
          matches.add(event);
        }
      }

      return {'suggestions': suggestions, 'matches': matches};
    } catch (e) {
      debugPrint('Error in searchEvents: $e');
      rethrow;
    }
  }

  // Sort events (newest, popular, eligible)
  static Future<List<Map<String, dynamic>>> getSortedEvents({
    required List<Map<String, dynamic>> events,
    String sortBy = 'newest',
    String? userDepartment,
  }) async {
    List<Map<String, dynamic>> sortedEvents = List.from(events); // Create a copy to avoid mutating input
    switch (sortBy) {
      case 'newest':
        sortedEvents.sort((a, b) {
          final aTime = (a['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bTime = (b['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bTime.compareTo(aTime); // Newest first
        });
        break;
      case 'popularity':
        sortedEvents.sort((a, b) {
          final aPop = (a['popularity'] as int?) ?? 0;
          final bPop = (b['popularity'] as int?) ?? 0;
          return bPop.compareTo(aPop); // Most popular first
        });
        break;
      case 'eligible':
        if (userDepartment != null && userDepartment.isNotEmpty) {
          sortedEvents.sort((a, b) {
            final aEligible = (a['department'] == userDepartment || a['department'] == null || a['department'].isEmpty);
            final bEligible = (b['department'] == userDepartment || b['department'] == null || b['department'].isEmpty);
            if (aEligible == bEligible) return 0;
            return aEligible ? -1 : 1; // Eligible first
          });
        }
        break;
      default:
        debugPrint('Unknown sortBy: $sortBy');
    }
    return sortedEvents;
  }

  // Event details for detail page (desc, organizer contact, rules, registration if slots > 0)
  static Future<Map<String, dynamic>?> getEventDetails(String eventId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');

    try {
      final doc = await _db.collection('events').doc(eventId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return <String, dynamic>{
        'id': doc.id,
        ...data,
        'slotsAvailable': data['slotsAvailable'] ?? 0,
        'registrationOpen': (data['status'] == 'approved' || data['status'] == 'live') && (data['slotsAvailable'] ?? 0) > 0,
        // Assume fields: description, organizerContact (email/phone), rules
      };
    } catch (e) {
      debugPrint('Error in getEventDetails: $e');
      rethrow;
    }
  }

// Fixed registerForEvent method for permissions.dart
  static Future<void> registerForEvent(String eventId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) {
      throw Exception('Authentication required');
    }

    try {
      final userData = await getUserData();
      if (userData['role'] != 'student' || userData['userType'] != 'participant') {
        throw Exception('Only verified participants can register');
      }
      if (userData['department'].isEmpty ||
          userData['enrollmentNumber'].isEmpty ||
          userData['collegeIdProofUrl'].isEmpty) {
        throw Exception('Complete your profile (department, enrollment, ID proof) to register');
      }

      final userId = _auth.currentUser!.uid;

      // Check if already registered BEFORE starting transaction
      final existingRegistration = await _db
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(userId)
          .get();

      if (existingRegistration.exists) {
        throw Exception('Already registered for this event');
      }

      // Use a transaction to ensure atomicity
      await _db.runTransaction((transaction) async {
        final eventRef = _db.collection('events').doc(eventId);
        final registrationRef = eventRef.collection('registrations').doc(userId);

        // Double-check within transaction (in case of concurrent registrations)
        final existingReg = await transaction.get(registrationRef);
        if (existingReg.exists) {
          throw Exception('Already registered for this event');
        }

        // Get event data
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) {
          throw Exception('Event not found');
        }

        final eventData = eventDoc.data()!;

        // Check registration eligibility
        if (eventData['status'] != 'approved' && eventData['status'] != 'live') {
          throw Exception('Registration is not open for this event');
        }

        final slotsAvailable = (eventData['slotsAvailable'] as int?) ?? 0;
        if (slotsAvailable <= 0) {
          throw Exception('No slots available');
        }

        // Check if registration deadline has passed
        final deadline = eventData['deadline'] as Timestamp?;
        if (deadline != null && DateTime.now().isAfter(deadline.toDate())) {
          throw Exception('Registration deadline has passed');
        }

        // Create the registration document
        transaction.set(registrationRef, {
          'userId': userId,
          'eventId': eventId,
          'registeredAt': FieldValue.serverTimestamp(),
          'status': 'approved', // Auto-approve for now, or set to 'pending' if manual approval needed
          'userEmail': userData['email'],
          'userName': userData['name'],
          'userDepartment': userData['department'],
          'userEnrollmentNumber': userData['enrollmentNumber'],
        });

        // Update event counters
        transaction.update(eventRef, {
          'slotsAvailable': slotsAvailable - 1,
          'currentParticipants': (eventData['currentParticipants'] as int? ?? 0) + 1,
          'popularity': (eventData['popularity'] as int? ?? 0) + 1,
        });
      });

      debugPrint('Registration successful for ${userData['email']}');

    } catch (e) {
      debugPrint('Error in registerForEvent: $e');
      rethrow;
    }
  }

  static Future<void> unregisterFromEvent(String eventId, String userId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) {
      throw Exception('Authentication required');
    }

    try {
      final userData = await getUserData();
      if (userData['role'] != 'student' || userData['userType'] != 'participant') {
        throw Exception('Only verified participants can unregister');
      }

      // Check if registered BEFORE starting transaction
      final existingRegistration = await _db
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(userId)
          .get();

      if (!existingRegistration.exists) {
        throw Exception('Not registered for this event');
      }

      // Use a transaction to ensure atomicity
      await _db.runTransaction((transaction) async {
        final eventRef = _db.collection('events').doc(eventId);
        final registrationRef = eventRef.collection('registrations').doc(userId);

        // Double-check within transaction
        final existingReg = await transaction.get(registrationRef);
        if (!existingReg.exists) {
          throw Exception('Not registered for this event');
        }

        // Get event data
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) {
          throw Exception('Event not found');
        }

        final eventData = eventDoc.data()!;

        // Check unregistration eligibility (mirror registration checks)
        if (eventData['status'] != 'approved' && eventData['status'] != 'live') {
          throw Exception('Event is not in a valid state for unregistration');
        }

        final slotsAvailable = (eventData['slotsAvailable'] as int?) ?? 0;
        final currentParticipants = (eventData['currentParticipants'] as int?) ?? 0;

        // Check if unregistration deadline has passed (opposite of registration deadline)
        final deadline = eventData['deadline'] as Timestamp?;
        if (deadline != null && DateTime.now().isAfter(deadline.toDate())) {
          throw Exception('Unregistration deadline has passed');
        }

        // Delete the registration document
        transaction.delete(registrationRef);

        // Update event counters (opposite of registration)
        transaction.update(eventRef, {
          'slotsAvailable': slotsAvailable + 1,
          'currentParticipants': currentParticipants - 1,
          'popularity': (eventData['popularity'] as int? ?? 0) - 1,
        });
      });

      debugPrint('Unregistration successful for ${userData['email']}');

    } catch (e) {
      debugPrint('Error in unregisterFromEvent: $e');
      rethrow;
    }
  }
  // Add new event with role validation
  static Future<void> addEvent(Map<String, dynamic> eventData) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');

    try {
      final userData = await _getUserData();
      final role = userData['role'] as String?;
      final status = userData['status'] as String?;

      if (role != 'organizer' && role != 'admin') {
        throw Exception('Only organizers and admins can create events');
      }

      if ((role == 'organizer' || role == 'admin') && status != 'approved') {
        throw Exception('Staff account must be approved to create events');
      }

      final eventDoc = {
        ...eventData,
        'organizerId': _auth.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'popularity': eventData['popularity'] ?? 0,
        'status': eventData['status'] ?? 'approved',
        'currentParticipants': eventData['currentParticipants'] ?? 0,
      };

      await _db.collection('events').add(eventDoc);
    } catch (e) {
      debugPrint('Error in addEvent: $e');
      rethrow;
    }
  }

  // Update event with role validation
  static Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');

    try {
      final userData = await _getUserData();
      final eventDoc = await _db.collection('events').doc(eventId).get();

      if (!eventDoc.exists) throw Exception('Event not found');

      final eventData = eventDoc.data()!;
      final isOrganizer = eventData['organizerId'] == _auth.currentUser!.uid;
      final isAdmin = userData['role'] == 'admin' && userData['status'] == 'approved';

      if (!isOrganizer && !isAdmin) {
        throw Exception('Only event organizers or admins can update events');
      }

      await _db.collection('events').doc(eventId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in updateEvent: $e');
      rethrow;
    }
  }

  // Delete event with role validation
  static Future<void> deleteEvent(String eventId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');

    try {
      final userData = await _getUserData();
      final eventDoc = await _db.collection('events').doc(eventId).get();

      if (!eventDoc.exists) throw Exception('Event not found');

      final eventData = eventDoc.data()!;
      final isOrganizer = eventData['organizerId'] == _auth.currentUser!.uid;
      final isAdmin = userData['role'] == 'admin' && userData['status'] == 'approved';

      if (!isOrganizer && !isAdmin) {
        throw Exception('Only event organizers or admins can delete events');
      }

      await _db.collection('events').doc(eventId).delete();
    } catch (e) {
      debugPrint('Error in deleteEvent: $e');
      rethrow;
    }
  }

  // Helper: Get user data (merged from event_service)
  static Future<Map<String, dynamic>> _getUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) throw Exception('User profile not found');
    return doc.data()!;
  }

  // *********************** //
  // ***** REGISTRATIONS ****//
  // *********************** //
  // New: Get registrations for an event (for organizers)
  static Future<List<Map<String, dynamic>>> getEventRegistrations(String eventId) async {
    try {
      final registrations = await _db.collection('events').doc(eventId).collection('registrations').get();
      return registrations.docs.map((doc) => {
        'userId': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('Error in getEventRegistrations: $e');
      rethrow;
    }
  }

  // New: Approve a registration
  static Future<void> approveRegistration(String eventId, String userId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');
    try {
      await _db.collection('events').doc(eventId).collection('registrations').doc(userId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in approveRegistration: $e');
      rethrow;
    }
  }

  // New: Reject a registration
  static Future<void> rejectRegistration(String eventId, String userId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');
    try {
      await _db.collection('events').doc(eventId).collection('registrations').doc(userId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in rejectRegistration: $e');
      rethrow;
    }
  }

  // New: Send internal message to participant
  static Future<void> sendMessage(String eventId, String userId, String message) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) throw Exception('Authentication required');
    try {
      await _db.collection('events').doc(eventId).collection('messages').add({
        'to': userId,
        'from': _auth.currentUser!.uid,
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      rethrow;
    }
  }


  // Enhanced getUserRegisteredEvents (include QR code data)
  static Future<List<Map<String, dynamic>>> getUserRegisteredEvents(String userId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) {
      throw Exception('Authentication required');
    }
    if (_auth.currentUser!.uid != userId) {
      throw Exception('Can only view own registrations');
    }

    try {
      // Use the collection group query
      final registrations = await _db
          .collectionGroup('registrations')
          .where('userId', isEqualTo: userId)
          .get();

      if (registrations.docs.isEmpty) {
        return [];
      }

      // Get unique event IDs
      final eventIds = registrations.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toSet()
          .toList();

      // Fetch event details
      final List<Map<String, dynamic>> results = [];

      for (String eventId in eventIds) {
        try {
          final eventDoc = await _db.collection('events').doc(eventId).get();
          if (eventDoc.exists) {
            final eventData = eventDoc.data()!;
            final registration = registrations.docs
                .firstWhere((doc) => doc.reference.parent.parent!.id == eventId);

            final qrData = 'Event:$eventId|User:$userId|Time:${DateTime.now().toIso8601String()}';

            results.add({
              ...eventData,
              'id': eventId,
              'qrData': qrData,
              'registrationStatus': registration.data()['status'] ?? 'pending',
              'registeredAt': registration.data()['registeredAt'],
            });
          }
        } catch (e) {
          debugPrint('Error fetching event $eventId: $e');
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error in getUserRegisteredEvents: $e');
      rethrow;
    }
  }

  static Future<bool> isUserRegisteredForEvent(String eventId, String userId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) {
      throw Exception('Authentication required');
    }

    try {
      final registrationDoc = await _db
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(userId)
          .get();

      return registrationDoc.exists;
    } catch (e) {
      debugPrint('Error checking registration status: $e');
      return false;
    }
  }

// Also add this method to get detailed registration info
  static Future<Map<String, dynamic>?> getUserRegistrationForEvent(String eventId, String userId) async {
    if (_auth.currentUser == null || _auth.currentUser!.uid.isEmpty) {
      throw Exception('Authentication required');
    }

    try {
      final registrationDoc = await _db
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(userId)
          .get();

      if (registrationDoc.exists) {
        return {
          'id': registrationDoc.id,
          ...registrationDoc.data()!,
          'qrData': 'Event:$eventId|User:$userId|Time:${DateTime.now().toIso8601String()}',
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting registration info: $e');
      return null;
    }
  }


// More features (events, etc.) added later as per SRS
}