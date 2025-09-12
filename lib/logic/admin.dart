import 'permissions.dart';

class AdminLogic {
  static Future<void> init() async {
    if (Permissions.hasPermission('admin', 'getPendingStaffApprovals')) {
      await Permissions.getPendingStaffApprovals();
      // Load admin dashboard
    }
    if (Permissions.hasPermission('admin', 'getAllEvents')) {
      await Permissions.getAllEvents(); // Load events for management
    }
  }

  static Future<void> handleApproval(String uid) async {
    if (Permissions.hasPermission('admin', 'approveStaff')) {
      await Permissions.approveStaff(uid);
    }
  }

  // Add more admin-specific selectors (e.g., updateEvent, deleteEvent)
  static Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    if (Permissions.hasPermission('admin', 'updateEvent')) {
      await Permissions.updateEvent(eventId, updates);
    }
  }

  static Future<void> deleteEvent(String eventId) async {
    if (Permissions.hasPermission('admin', 'deleteEvent')) {
      await Permissions.deleteEvent(eventId);
    }
  }

  // New method to get pending approvals
  static Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    if (Permissions.hasPermission('admin', 'getPendingStaffApprovals')) {
      return await Permissions.getPendingStaffApprovals();
    }
    return [];
  }
}