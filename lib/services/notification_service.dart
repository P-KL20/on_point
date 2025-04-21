import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
