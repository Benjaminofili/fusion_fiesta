import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'logic/permissions.dart';
import 'screens/auth_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/admin/dashboard.dart';
import 'screens/organizer/dashboard.dart';
import 'logic/user.dart';
import 'logic/admin.dart';
import 'logic/organizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Add test events
  // final db = FirebaseFirestore.instance;
  // final testEvents = [
  //   {
  //     'title': 'Tech Symposium 2025',
  //     'description': 'A day of tech talks and workshops',
  //     'dateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
  //     'organizerId': 'g7x6PychDhOMmmcCTkYZrRBVNNo1',
  //     'registrationOpen': true,
  //     'slotsAvailable': 100,
  //     'location': 'Main Auditorium',
  //     'imageUrl': 'https://via.placeholder.com/150',
  //   },
  //   {
  //     'title': 'Cultural Fest 2025',
  //     'description': 'Celebrate culture with music and dance',
  //     'dateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
  //     'organizerId': 'g7x6PychDhOMmmcCTkYZrRBVNNo1',
  //     'registrationOpen': true,
  //     'slotsAvailable': 75,
  //     'location': 'Open Ground',
  //     'imageUrl': 'https://via.placeholder.com/150',
  //   },
  // ];
  // for (var event in testEvents) {
  //   await db.collection('events').add(event);
  // }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FusionFiesta',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: Permissions.getUserData(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!['uid'].isNotEmpty) {
          final data = snapshot.data!;
          final role = data['role'];
          final userType = data['userType'];
          final approved = data['approved'];
          if ((role == 'organizer' || role == 'admin') && !approved) return const AuthScreen();
          switch (role) {
            case 'student':
              UserLogic.init(data['uid']);
              return UsersHomeScreen(userType: userType, uid: data['uid']);
            case 'admin':
              AdminLogic.init();
              return AdminDashboard();
            case 'organizer':
              OrganizerLogic.init();
              return OrganizerDashboard(eventId: 'eventId');
            default:
              return const AuthScreen();
          }
        }
        return const AuthScreen();
      },
    );
  }
}