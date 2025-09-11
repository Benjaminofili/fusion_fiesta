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

  // New: Selector for sorted events (SRS 1.6.3)
  static Future<List<Map<String, dynamic>>> getSortedEvents({
    String sortBy = 'newest',
    String? userDepartment,
  }) async {
    if (Permissions.hasPermission('student', 'getSortedEvents')) {
      return await Permissions.getSortedEvents(sortBy: sortBy, userDepartment: userDepartment);
    }
    return [];
  }

  // Add more student-specific selectors (e.g., upgrade if visitor)
  static Future<void> upgradeIfNeeded(String uid, String department, String enrollment, String proofUrl) async {
    if (Permissions.hasPermission('student', 'upgradeToParticipant')) {
      await Permissions.upgradeToParticipant(uid: uid, department: department, enrollmentNumber: enrollment, collegeIdProofUrl: proofUrl);
    }
  }

// Call in UI: UserLogic.browseEvents() → ListView with event_card.dart
}