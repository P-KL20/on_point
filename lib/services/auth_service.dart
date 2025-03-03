import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

      // Store additional user details (Username and Email) in Firestore
      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "username": username,
        "email": email,
      });

      return userCredential.user;
    } catch (e) {
      print("Sign Up Error: $e");
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
          print("No user found with that username.");
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
      print("Login Error: $e");
      return null;
    }
  }

  // Logout Method
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
