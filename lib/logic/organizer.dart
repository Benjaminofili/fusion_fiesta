import 'permissions.dart';
import '../screens/organizer/dashboard.dart';
// import '../components/organizer/event_form.dart';

class OrganizerLogic {
  static Future<void> init() async {
    if (Permissions.hasPermission('organizer', 'getAllEvents')) {
      await Permissions.getAllEvents(); // Load own events
    }
  }

  static Future<void> addEvent(Map<String, dynamic> eventData) async {
    if (Permissions.hasPermission('organizer', 'addEvent')) {
      await Permissions.addEvent(eventData); // From merged
    }
  }

// Similar for update/delete
}