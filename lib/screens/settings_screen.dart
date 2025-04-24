import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes.dart';
import '../utils/dialog_helper.dart';

/// A screen for user settings, including logout and account deletion.
/// It displays the user's profile information and provides options
/// to log out or delete the account.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _confirmLogout(BuildContext context) {
    DialogHelper.showConfirmation(
      context: context,
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      onConfirmed: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.login,
          (route) => false,
        );
      },
    );
  }

  /// Shows a confirmation dialog for account deletion.
  void _confirmDeleteAccount(BuildContext context) {
    DialogHelper.showConfirmation(
      context: context,
      title: 'Delete Account',
      message:
          'This will permanently delete your account and all your data. Are you sure?',
      confirmText: 'Delete',
      onConfirmed: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final uid = user.uid;

        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .delete();

          await user.delete();

          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.login,
            (_) => false,
          );
        } catch (e) {
          DialogHelper.showError(
            context,
            "Account deletion failed. Please re-authenticate and try again.",
          );
        }
      },
    );
  }

  /// Builds the settings screen UI.
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Info
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    user?.displayName != null && user!.displayName!.isNotEmpty
                        ? user.displayName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'No Name',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      user?.email ?? 'No Email',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout
          _buildTile(
            icon: Icons.logout,
            label: 'Log Out',
            iconColor: Colors.redAccent,
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 16),

          // Delete Account
          _buildTile(
            icon: Icons.delete_forever,
            label: 'Delete Account',
            iconColor: Colors.red,
            onTap: () => _confirmDeleteAccount(context),
          ),
          const SizedBox(height: 24),

          // Placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'More personalization settings will be added soon.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for consistency
  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.black,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
