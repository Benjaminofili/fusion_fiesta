import 'permissions.dart';
import '../screens/organizer/dashboard.dart';
import '../components/organizers/registration_list.dart';

class OrganizerLogic {
  static Future<void> init() async {
    if (Permissions.hasPermission('organizer', 'getAllEvents')) await Permissions.getAllEvents();
    if (Permissions.hasPermission('organizer', 'getEventRegistrations')) await Permissions.getEventRegistrations('eventId'); // Example
  }

  static Future<List<Map<String, dynamic>>> getEventRegistrations(String eventId) async {
    if (Permissions.hasPermission('organizer', 'getEventRegistrations')) return await Permissions.getEventRegistrations(eventId);
    return [];
  }

  static Future<void> approveRegistration(String eventId, String userId) async {
    if (Permissions.hasPermission('organizer', 'approveRegistration')) await Permissions.approveRegistration(eventId, userId);
  }

  static Future<void> rejectRegistration(String eventId, String userId) async {
    if (Permissions.hasPermission('organizer', 'rejectRegistration')) await Permissions.rejectRegistration(eventId, userId);
  }

  static Future<void> sendMessage(String eventId, String userId, String message) async {
    if (Permissions.hasPermission('organizer', 'sendMessage')) await Permissions.sendMessage(eventId, userId, message);
  }

// Existing add/update/delete methods
}