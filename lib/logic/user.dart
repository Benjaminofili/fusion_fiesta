import 'package:cloud_firestore/cloud_firestore.dart';

import 'permissions.dart';
import '../screens/user/home_screen.dart';
import '../components/users/event_card.dart'; // For summary cards

class UserLogic {
  static Future<void> init(String uid) async {
    if (Permissions.hasPermission('student', 'getAllEvents')) {
      await Permissions.getAllEvents(); // Load for home_screen
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
      await Permissions.registerForEvent(eventId);
      // Navigate to success in home_screen
    }
  }

  // Selector for event details (SRS 1.6.3)
  static Future<Map<String, dynamic>?> getEventDetails(String eventId) async {
    if (Permissions.hasPermission('student', 'getEventDetails')) {
      return await Permissions.getEventDetails(eventId);
    }
    return null;
  }

  // New: Selector for sorted events (takes filtered events to apply sort without overriding)
  static Future<List<Map<String, dynamic>>> getSortedEvents({
    required List<Map<String, dynamic>> events, // Pass filtered events
    String sortBy = 'newest',
    String? userDepartment,
  }) async {
    if (Permissions.hasPermission('student', 'getSortedEvents')) {
      // Fetch user data for eligibility
      final userData = await Permissions.getUserData();
      final isStudent = userData['role'] == 'student';
      final isParticipant = isStudent && userData['userType'] == 'participant';

      return events.map((event) {
        bool isEligible = true;
        if (isParticipant && event['department'] != null && event['department'] != userDepartment) {
          isEligible = false;
        }
        return {...event, '_isEligible': isEligible};
      }).toList()
        ..sort((a, b) {
          switch (sortBy) {
            case 'newest':
              final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
              final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
              return bDate.compareTo(aDate);
            case 'popularity':
              return (b['popularity'] as int?)?.compareTo(a['popularity'] as int? ?? 0) ?? 0;
            case 'eligible':
              return (b['_isEligible'] ? 1 : 0).compareTo(a['_isEligible'] ? 1 : 0);
            default:
              return 0;
          }
        });
    }
    return events; // Fallback to input
  }

  // Add more student-specific selectors (e.g., upgrade if visitor)
  static Future<void> upgradeIfNeeded(String uid, String department, String enrollment, String proofUrl) async {
    if (Permissions.hasPermission('student', 'upgradeToParticipant')) {
      await Permissions.upgradeToParticipant(uid: uid, department: department, enrollmentNumber: enrollment, collegeIdProofUrl: proofUrl);
    }
  }

// Call in UI: UserLogic.browseEvents() → ListView with event_card.dart
}