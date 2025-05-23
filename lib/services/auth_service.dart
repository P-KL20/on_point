import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';

/// The AuthService class is responsible for managing user authentication
/// functionalities, including signing up, logging in, logging out,
/// and resetting passwords.
/// It uses Firebase Authentication for user management and Firestore
/// for storing additional user details.
/// It provides methods to sign up with email and password, log in
/// with either email or username, log out, and reset passwords.
/// It also handles errors and logs them using the LoggerService.
/// The class is designed to be reusable and can be easily integrated
/// into any Flutter application that requires user authentication.

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up Method (Stores Username in Firestore)
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Set displayName in Firebase Auth profile
      await userCredential.user!.updateDisplayName(username);
      await userCredential.user!.reload();

      // Store additional user details (Username and Email) in Firestore
      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "username": username,
        "email": email,
      });

      return userCredential.user;
    } catch (e) {
      LoggerService.error("Sign Up Error: $e");
      return null;
    }
  }

  // Login Method (Supports both Email and Username)
  Future<User?> loginWithEmailOrUsername(String input, String password) async {
    try {
      String email = input;

      // Check if the input is a username, fetch corresponding email
      if (!input.contains("@")) {
        QuerySnapshot query =
            await _firestore
                .collection("users")
                .where("username", isEqualTo: input)
                .limit(1)
                .get();

        if (query.docs.isNotEmpty) {
          email = query.docs.first["email"];
        } else {
          LoggerService.error("No user found with that username.");
          return null;
        }
      }

      // Authenticate using the retrieved email
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } catch (e) {
      LoggerService.error("Login Error: $e");
      return null;
    }
  }

  // Logout Method
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password Reset Method
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      LoggerService.error("Reset Password Error: $e");
      return false;
    }
  }
}
