import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_confirmation_screen.dart';
import 'screens/budget_input_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/budget_overview_screen.dart';
import 'screens/create_budget_screen.dart';
import 'screens/notification_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initializeLocalNotifications();

  runApp(MyApp());
}

Future<void> _initializeLocalNotifications() async {
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initSettings = InitializationSettings(
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

/// This is the main entry point of the application
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        RouteNames.login: (context) => LoginScreen(),
        RouteNames.signup: (context) => SignupScreen(),
        RouteNames.resetConfirmation: (context) => ResetConfirmationScreen(),
        RouteNames.budgetInput: (context) => const BudgetInputScreen(),
        RouteNames.transactions: (context) => TransactionHistoryScreen(),
        RouteNames.settings: (context) => const SettingsScreen(),
        RouteNames.budgetOverview: (context) => const BudgetOverviewScreen(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == RouteNames.home) {
          final user = settings.arguments as User;
          return MaterialPageRoute(
            builder: (context) => HomeScreen(user: user),
          );
        }

        if (settings.name == RouteNames.createBudget) {
          final targetMonth = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => const CreateBudgetScreen(),
            settings: RouteSettings(arguments: targetMonth),
          );
        }

        if (settings.name == RouteNames.notifications) {
          final history = settings.arguments as List<Map<String, dynamic>>;
          return MaterialPageRoute(
            builder:
                (context) => NotificationHistoryScreen(notifications: history),
          );
        }

        return null;
      },
    );
  }
}
