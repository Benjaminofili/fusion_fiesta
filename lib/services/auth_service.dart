import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sign up with Email & Password
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String role, // "student" | "organizer" | "admin"
    String userType = "visitor", // "visitor" | "participant" (only for students)
    String? department,
    String? enrollmentNumber,
    String? profileImageUrl,
    String? collegeIdProofUrl,
  }) async {
    try {
      // Validate role and user type combinations
      if (role == "student" && !["visitor", "participant"].contains(userType)) {
        throw Exception("Students must be either 'visitor' or 'participant'");
      }

      if ((role == "organizer" || role == "admin") && userType != "visitor") {
        userType = "visitor"; // Staff roles don't use userType
      }

      // Staff (organizer/admin) must use institutional email
      if ((role == "organizer" || role == "admin") && !email.endsWith(".edu")) {
        throw Exception("Staff members must use institutional email (ending with .edu).");
      }

      // Student participants must provide additional details
      if (role == "student" && userType == "participant") {
        if (department == null || department.isEmpty) {
          throw Exception("Student participants must provide department");
        }
        if (enrollmentNumber == null || enrollmentNumber.isEmpty) {
          throw Exception("Student participants must provide enrollment number");
        }
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        final userDoc = {
          "uid": user.uid,
          "email": email,
          "name": name,
          "role": role,
          "userType": userType,
          "department": department ?? "",
          "enrollmentNumber": enrollmentNumber ?? "",
          "profileImageUrl": profileImageUrl ?? "",
          "collegeIdProofUrl": collegeIdProofUrl ?? "",
          "status": (role == "organizer" || role == "admin") ? "pending" : "approved",
          "createdAt": FieldValue.serverTimestamp(),
          "lastLoginAt": FieldValue.serverTimestamp(),
        };

        await _db.collection("users").doc(user.uid).set(userDoc);
      }

      return user;
    } catch (e) {
      print("Error in signUpWithEmail: $e");
      rethrow;
    }
  }

  /// Login with Email & Password
  Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        final doc = await _db.collection("users").doc(user.uid).get();
        final data = doc.data();

        if (data != null) {
          // Check if staff account is approved
          if ((data["role"] == "organizer" || data["role"] == "admin") &&
              data["status"] != "approved") {
            throw Exception("Staff account is pending approval from system admin.");
          }

          // Update last login time
          await _db.collection("users").doc(user.uid).update({
            "lastLoginAt": FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      print("Error in loginWithEmail: $e");
      rethrow;
    }
  }

  /// Google Sign-In (defaults to Student Visitor)
  Future<User?> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        final docRef = _db.collection("users").doc(user.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          // New Google user - create as Student Visitor
          await docRef.set({
            "uid": user.uid,
            "email": user.email ?? "",
            "name": user.displayName ?? "",
            "role": "student",
            "userType": "visitor",
            "department": "",
            "enrollmentNumber": "",
            "profileImageUrl": user.photoURL ?? "",
            "collegeIdProofUrl": "",
            "status": "approved",
            "createdAt": FieldValue.serverTimestamp(),
            "lastLoginAt": FieldValue.serverTimestamp(),
          });
        } else {
          // Update last login time
          await docRef.update({
            "lastLoginAt": FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      print("Error in loginWithGoogle: $e");
      rethrow;
    }
  }

  /// Upgrade Student Visitor to Participant
  Future<void> upgradeToParticipant({
    required String uid,
    required String department,
    required String enrollmentNumber,
    required String collegeIdProofUrl,
  }) async {
    try {
      final userDoc = await _db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        throw Exception("User not found");
      }

      final userData = userDoc.data()!;
      if (userData["role"] != "student") {
        throw Exception("Only students can upgrade to participant");
      }

      if (userData["userType"] == "participant") {
        throw Exception("User is already a participant");
      }

      await _db.collection("users").doc(uid).update({
        "userType": "participant",
        "department": department,
        "enrollmentNumber": enrollmentNumber,
        "collegeIdProofUrl": collegeIdProofUrl,
        "upgradedAt": FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print("Error in upgradeToParticipant: $e");
      rethrow;
    }
  }

  /// Approve Staff (Admin action)
  Future<void> approveStaff(String uid) async {
    try {
      final userDoc = await _db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        throw Exception("User not found");
      }

      final userData = userDoc.data()!;
      if (userData["role"] != "organizer" && userData["role"] != "admin") {
        throw Exception("Only staff members can be approved");
      }

      await _db.collection("users").doc(uid).update({
        "status": "approved",
        "approvedAt": FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print("Error in approveStaff: $e");
      rethrow;
    }
  }

  /// Get Pending Staff Approvals (Admin only)
  Future<List<Map<String, dynamic>>> getPendingStaffApprovals() async {
    try {
      final snapshot = await _db
          .collection("users")
          .where("status", isEqualTo: "pending")
          .where("role", whereIn: ["organizer", "admin"])
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          "uid": doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print("Error in getPendingStaffApprovals: $e");
      rethrow;
    }
  }

  /// Check if Staff is Approved
  Future<bool> isApprovedStaff(String uid) async {
    try {
      final doc = await _db.collection("users").doc(uid).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return (data["role"] == "organizer" || data["role"] == "admin") &&
          data["status"] == "approved";
    } catch (e) {
      print("Error in isApprovedStaff: $e");
      return false;
    }
  }

  /// Get Current User Profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _db.collection("users").doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return <String, dynamic>{
          "uid": user.uid,
          ...data,
        };
      }
      return null;
    } catch (e) {
      print("Error in getCurrentUserProfile: $e");
      return null;
    }
  }

  /// Forgot Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Error in resetPassword: $e");
      rethrow;
    }
  }

  /// Check User Role and Type
  Future<Map<String, String>> getUserRoleAndType() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {"role": "guest", "userType": "visitor"};

      final doc = await _db.collection("users").doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          "role": data["role"] ?? "student",
          "userType": data["userType"] ?? "visitor",
        };
      }
      return {"role": "student", "userType": "visitor"};
    } catch (e) {
      print("Error in getUserRoleAndType: $e");
      return {"role": "student", "userType": "visitor"};
    }
  }

  /// Logout
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      print("Error in signOut: $e");
      rethrow;
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}