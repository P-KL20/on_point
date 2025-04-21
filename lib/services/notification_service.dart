import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// This is a service class for managing notifications in a Flutter app.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// This class handles adding, fetching, and cleaning up notifications.
// It uses Firebase Firestore to store notifications and Firebase Auth to get the current user's ID.
// It also uses the flutter_local_notifications package to show local notifications.
// The class provides methods to add notifications for overspending and budget warnings,
// fetch unread notification counts, get notification history, and clean up old notifications.
// It also includes a method to show local notifications.
// The notifications are categorized by type (budget_exceeded, budget_warning) and can be filtered by category and monthKey.
// The notifications are stored in a sub-collection under the user's document in Firestore.
// The class ensures that duplicate notifications are not added by checking for existing notifications with the same category and monthKey.
// The notifications are marked as read when they are fetched, and old notifications can be cleaned up based on a specified number of days.

class NotificationService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> addOverspentNotification({
    required String category,
    required double spent,
    required double limit,
    required String monthKey,
  }) async {
    final uid = _auth.currentUser!.uid;
    final notifRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications');

    final existing =
        await notifRef
            .where('category', isEqualTo: category)
            .where('monthKey', isEqualTo: monthKey)
            .where('type', isEqualTo: 'budget_exceeded')
            .get();

    if (existing.docs.isEmpty) {
      final body =
          'You’ve spent \$${spent.toStringAsFixed(2)} on $category, over your \$${limit.toStringAsFixed(2)} limit!';

      await notifRef.add({
        'title': 'Budget Exceeded - $category',
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'budget_exceeded',
        'category': category,
        'monthKey': monthKey,
        'read': false,
      });

      await _showLocalNotification(
        title: 'Budget Exceeded - $category',
        body: body,
      );
    }
  }

  /// Adds a budget warning notification if the user has spent 80% of their budget.
  Future<void> addBudgetWarningNotification({
    required String category,
    required double spent,
    required double limit,
    required String monthKey,
  }) async {
    final uid = _auth.currentUser!.uid;
    final notifRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications');

    final existing =
        await notifRef
            .where('category', isEqualTo: category)
            .where('monthKey', isEqualTo: monthKey)
            .where('type', isEqualTo: 'budget_warning')
            .get();

    if (existing.docs.isEmpty) {
      final body =
          'You’ve spent 80% of your \$${limit.toStringAsFixed(2)} budget for $category.';

      await notifRef.add({
        'title': 'Warning: 80% used - $category',
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'budget_warning',
        'category': category,
        'monthKey': monthKey,
        'read': false,
      });

      await _showLocalNotification(
        title: 'Warning: 80% used - $category',
        body: body,
      );
    }
  }

  /// Shows a local notification with the given title and body.
  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails platformDetails = NotificationDetails(
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(0, title, body, platformDetails);
  }

  /// Fetches the count of unread notifications for the current user.
  Future<int> getUnreadNotificationCount() async {
    final uid = _auth.currentUser!.uid;
    final snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .get();

    return snapshot.size;
  }

  /// Fetches the notification history for the current user.
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    final uid = _auth.currentUser!.uid;
    final notifRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications');

    final snapshot =
        await notifRef.orderBy('timestamp', descending: true).get();

    for (var doc in snapshot.docs) {
      if ((doc.data()['read'] ?? false) == false) {
        await doc.reference.update({'read': true});
      }
    }

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Cleans up old notifications older than the specified number of days.
  Future<void> cleanupOldNotifications({int days = 60}) async {
    final uid = _auth.currentUser!.uid;
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('timestamp', isLessThan: cutoff.toIso8601String())
            .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Fetches the count of unread notifications for the current user.
  Future<int> fetchUnreadCount() async {
    final uid = _auth.currentUser!.uid;
    final snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .get();
    return snapshot.size;
  }
}
