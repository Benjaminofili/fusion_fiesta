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
  // Create test accounts
  await Permissions.createTestAccount('testadmin@fusionfiesta.com', 'Admin123!', 'admin');
  await Permissions.createTestAccount('testorganizer@fusionfiesta.com', 'Org123!', 'organizer');
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
              return UsersHomeScreen(userType: userType);
            case 'admin':
              AdminLogic.init();
              return AdminDashboard();
            case 'organizer':
              OrganizerLogic.init();
              return OrganizerDashboard();
            default:
              return const AuthScreen();
          }
        }
        return const AuthScreen();
      },
    );
  }
}