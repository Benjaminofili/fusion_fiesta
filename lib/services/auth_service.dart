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
    required String role, // "visitor" | "participant" | "staff"
    String? department,
    String? enrollmentNumber,
    String? profileImageUrl,
    String? collegeIdProofUrl,
  }) async {
    try {
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
          "department": department ?? "",
          "enrollmentNumber": enrollmentNumber ?? "",
          "profileImageUrl": profileImageUrl ?? "",
          "collegeIdProofUrl": collegeIdProofUrl ?? "",
          "status": role == "staff" ? "pending" : "approved",
          "createdAt": FieldValue.serverTimestamp(),
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
      return result.user;
    } catch (e) {
      print("Error in loginWithEmail: $e");
      rethrow;
    }
  }

  /// Google Sign-In
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
          await docRef.set({
            "uid": user.uid,
            "email": user.email ?? "",
            "name": user.displayName ?? "",
            "role": "visitor",
            "department": "",
            "enrollmentNumber": "",
            "profileImageUrl": user.photoURL ?? "",
            "collegeIdProofUrl": "",
            "status": "approved",
            "createdAt": FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      print("Error in loginWithGoogle: $e");
      rethrow;
    }
  }

  /// Forgot Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Upgrade Student to Participant
  Future<void> upgradeToParticipant({
    required String uid,
    required String department,
    required String enrollmentNumber,
    required String collegeIdProofUrl,
  }) async {
    await _db.collection("users").doc(uid).update({
      "role": "participant",
      "department": department,
      "enrollmentNumber": enrollmentNumber,
      "collegeIdProofUrl": collegeIdProofUrl,
    });
  }

  /// Approve Staff (Admin action)
  Future<void> approveStaff(String uid) async {
    await _db.collection("users").doc(uid).update({"status": "approved"});
  }

  /// Check if Staff is Approved
  Future<bool> isApprovedStaff(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    return doc.exists &&
        doc["role"] == "staff" &&
        doc["status"] == "approved";
  }

  /// Get Current User Profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection("users").doc(user.uid).get();
    return doc.data();
  }

  /// Logout
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
