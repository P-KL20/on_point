import 'package:flutter/material.dart';

/// This is a utility class for showing styled dialogs and snackbars in a Flutter app.
/// It provides methods to show error and success dialogs, confirmation dialogs,
/// and passive snackbars. The dialogs are styled with rounded corners and custom colors.
/// The class also includes a method to show an edit comment dialog with a text field.
class DialogHelper {
  /// Shows a styled error dialog with red accent
  static void showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 8),
                Text("Error"),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  /// Shows a styled success dialog with green checkmark
  static void showSuccess(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.green),
                SizedBox(width: 8),
                Text("Success"),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  /// Shows a confirmation dialog with optional callbacks
  static void showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirmed,
    VoidCallback? onCancel,
    String confirmText = "Yes",
    String cancelText = "Cancel",
  }) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (onCancel != null) onCancel();
                },
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirmed();
                },
                child: Text(confirmText),
              ),
            ],
          ),
    );
  }

  /// Shows a passive snackbar notification (e.g., "Transaction saved")
  static void showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Edit Comment Dialog
  static void showEditComment({
    required BuildContext context,
    required String initialComment,
    required void Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialComment);

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Edit Comment'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  onSave(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
