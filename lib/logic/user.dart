import 'package:cloud_firestore/cloud_firestore.dart';
import 'permissions.dart';
import '../screens/user/home_screen.dart';
import '../components/users/event_card.dart';

class UserLogic {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> init(String uid) async {
    if (Permissions.hasPermission('student', 'getAllEvents')) {
      await Permissions.getAllEvents();
    }
  }

  static Future<List<Map<String, dynamic>>> browseEvents({
    String? category,
    String? department,
  }) async {
    if (Permissions.hasPermission('student', 'getAllEvents')) {
      return await Permissions.getAllEvents(category: category, department: department);
    }
    return [];
  }

  static Future<Map<String, List<Map<String, dynamic>>>> searchEvents(String query) async {
    if (Permissions.hasPermission('student', 'searchEvents')) {
      return await Permissions.searchEvents(query);
    }
    return {'suggestions': [], 'matches': []};
  }

  static Future<void> registerForEvent(String eventId) async {
    if (Permissions.hasPermission('student', 'registerForEvent')) {
      try {
        await Permissions.registerForEvent(eventId);
      } catch (e) {
        if (e.toString().contains('Complete your profile')) {
          // Handle in UI
        }
        rethrow;
      }
    }
  }

  static Future<void> unregisterFromEvent(String eventId) async {
    if (Permissions.hasPermission('student', 'unregisterFromEvent')) {
      final userData = await Permissions.getUserData();
      final uid = userData['uid'];
      if (uid.isEmpty) throw Exception('User not authenticated');
      await Permissions.unregisterFromEvent(eventId, uid);
    }
  }

  static Future<bool> isUserRegisteredForEvent(String eventId) async {
    if (Permissions.hasPermission('student', 'getUserRegisteredEvents')) {
      final userData = await Permissions.getUserData();
      final uid = userData['uid'];
      if (uid.isEmpty) return false;

      return await Permissions.isUserRegisteredForEvent(eventId, uid);
    }
    return false;
  }

  static Stream<bool> isUserRegisteredForEventStream(String eventId) async* {
    if (Permissions.hasPermission('student', 'getUserRegisteredEvents')) {
      final userData = await Permissions.getUserData();
      final uid = userData['uid'];
      if (uid.isEmpty) {
        yield false;
        return;
      }

      yield* _db
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(uid)
          .snapshots()
          .map((snapshot) => snapshot.exists);
    } else {
      yield false;
    }
  }

  static Future<Map<String, dynamic>?> getUserRegistrationForEvent(String eventId) async {
    if (Permissions.hasPermission('student', 'getUserRegisteredEvents')) {
      final userData = await Permissions.getUserData();
      final uid = userData['uid'];
      if (uid.isEmpty) return null;

      return await Permissions.getUserRegistrationForEvent(eventId, uid);
    }
    return null;
  }

  static Stream<List<Map<String, dynamic>>> getUserRegisteredEventsStream() async* {
    if (Permissions.hasPermission('student', 'getUserRegisteredEvents')) {
      final userData = await Permissions.getUserData();
      final uid = userData['uid'];
      if (uid.isEmpty) {
        yield [];
        return;
      }

      yield* _db.collectionGroup('registrations')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .asyncMap((snapshot) async {
        final results = <Map<String, dynamic>>[];
        for (var doc in snapshot.docs) {
          final eventId = doc.reference.parent.parent!.id;
          final eventData = (await _db.collection('events').doc(eventId).get()).data() ?? {};
          final registration = doc.data();
          final qrData = 'Event:$eventId|User:$uid|Time:${DateTime.now().toIso8601String()}';
          results.add({
            ...eventData,
            'id': eventId,
            'qrData': qrData,
            'registrationStatus': registration['status'] ?? 'pending',
            'registeredAt': registration['registeredAt'],
          });
        }
        return results;
      });
    } else {
      yield [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUserRegisteredEvents() async {
    if (Permissions.hasPermission('student', 'getUserRegisteredEvents')) {
      final userData = await Permissions.getUserData();
      final uid = userData['uid'];
      if (uid.isEmpty) throw Exception('User not authenticated');
      return await Permissions.getUserRegisteredEvents(uid);
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getEventDetails(String eventId) async {
    if (Permissions.hasPermission('student', 'getEventDetails')) {
      return await Permissions.getEventDetails(eventId);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getSortedEvents({
    required List<Map<String, dynamic>> events,
    String sortBy = 'newest',
    String? userDepartment,
  }) async {
    if (Permissions.hasPermission('student', 'getSortedEvents')) {
      return await Permissions.getSortedEvents(events: events, sortBy: sortBy, userDepartment: userDepartment);
    }
    return events;
  }

  static Future<void> upgradeIfNeeded(String department, String enrollmentNumber, String proofUrl) async {
    if (Permissions.hasPermission('student', 'upgradeToParticipant')) {
      await Permissions.upgradeToParticipant(
        department: department,
        enrollmentNumber: enrollmentNumber,
        collegeIdProofUrl: proofUrl,
      );
    }
  }
}