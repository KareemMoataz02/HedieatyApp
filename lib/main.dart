import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login.dart';
import 'screens/home_page.dart';
import 'services/database_helper.dart';
import 'package:hedieaty/services/connectivity_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import './services/notifications.dart';
import 'package:fluttertoast/fluttertoast.dart'; // For displaying toasts

// Global instance of Flutter Local Notifications Plugin
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    // Add iOS initialization settings if required
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // Handle notification tapped
      if (response.payload != null) {
        print('Notification tapped with payload: ${response.payload}');
      }
    },
  );
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'your_channel_id', // The ID of the channel
  'your_channel_name', // The name of the channel
  description: 'Your channel description', // The description of the channel
  importance: Importance.max, // Importance level
);

void setupNotifications() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> backgroundMessageHandler(RemoteMessage message) async {
  // Initialize notifications in the background
  await NotificationsHelper.showNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initNotifications(); // Initialize notifications when the app starts
  setupNotifications();

  // Initialize the ConnectivityService before running the app
  final connectivityService = ConnectivityService();
  connectivityService.listenToConnectivityChanges(); // Start listening to connectivity changes
  FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);

  runApp(HedieatyApp(connectivityService));
}

class HedieatyApp extends StatelessWidget {
  final ConnectivityService connectivityService;

  HedieatyApp(this.connectivityService);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedieaty',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AppState(connectivityService: connectivityService),
    );
  }
}

class AppState extends StatefulWidget {
  final ConnectivityService connectivityService;

  AppState({required this.connectivityService});

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<AppState> {
  bool isLoggedIn = false;
  String? email;
  late StreamSubscription<bool> _connectivitySubscription;

  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    clearDatabase();
    checkLoginStatus();
    synchronizeDatabases();

    // Listen to connectivity changes globally
    _connectivitySubscription = widget.connectivityService.connectionStatusStream.listen((isConnected) {
      // Handle connectivity status changes globally
      if (isConnected) {
        print("Connected to the internet. Synchronizing databases...");
        synchronizeDatabases();
      } else {
        print("Disconnected from the internet.");
      }
    });

    // Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground notification received: ${message.notification?.title}");
      // Show notification locally when app is in foreground
      NotificationsHelper.showNotification(message);
      // Show in-app toast for notifications
      _showInAppToast(message);
    });
  }

  Future<void> clearDatabase() async {
    await dbHelper.clearDatabase(); // Assuming you have this method in your DatabaseHelper
  }

  // Check the login status from SharedPreferences
  Future<void> checkLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool loginStatus = prefs.getBool('isLoggedIn') ?? false;
      String? userEmail = prefs.getString('email');

      setState(() {
        isLoggedIn = loginStatus;
        email = userEmail;
      });
    } catch (e) {
      debugPrint("Error reading SharedPreferences: $e");
      setState(() {
        isLoggedIn = false;
        email = null;
      });
    }
  }

  // Synchronize data with Firebase
  Future<void> synchronizeDatabases() async {
    await dbHelper.synchronizeDatabases(); // Sync with local database and Firebase
  }

  // Display a toast for in-app notifications
  void _showInAppToast(RemoteMessage message) {
    Fluttertoast.showToast(
      msg: "${message.notification?.title ?? 'Notification'}: ${message.notification?.body ?? 'No content'}",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.deepPurple,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoggedIn && email != null
        ? HomePage(email: email!) // Go to HomePage if logged in
        : LoginPage(); // Go to LoginPage if not logged in
  }

  @override
  void dispose() {
    // Cancel connectivity subscription to prevent memory leaks
    _connectivitySubscription.cancel();
    super.dispose();
  }
}

//
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'login.dart';
// import 'home_page.dart';
// import 'database_helper.dart';
// import 'connectivityManager.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(HedieatyApp());
// }
//
// class HedieatyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Hedieaty',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: AppState(),
//     );
//   }
// }
//
// class AppState extends StatefulWidget {
//   @override
//   _AppState createState() => _AppState();
// }
//
// class _AppState extends State<AppState> {
//   bool isLoggedIn = false;
//   String? email;
//   bool isConnected = false;
//   final dbHelper = DatabaseHelper();
//   late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
//
//   @override
//   void initState() {
//     super.initState();
//     ConnectionStatusSingleton connectionStatus = ConnectionStatusSingleton.getInstance();
//     connectionStatus.initialize();
//     //clearDatabase();
//     // Check login status and connectivity when app starts
//     checkLoginStatus();
//     // listenToConnectivityChanges();
//   }
//
//   Future<void> clearDatabase() async {
//     await dbHelper.clearDatabase();  // Assuming you have this method in your DatabaseHelper
//   }
//
//   // Check the login status from SharedPreferences
//   Future<void> checkLoginStatus() async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       bool loginStatus = prefs.getBool('isLoggedIn') ?? false;
//       String? userEmail = prefs.getString('email');
//
//       setState(() {
//         isLoggedIn = loginStatus;
//         email = userEmail;
//       });
//     } catch (e) {
//       debugPrint("Error reading SharedPreferences: $e");
//       setState(() {
//         isLoggedIn = false;
//         email = null;
//       });
//     }
//   }
//
// // Listen for connectivity changes
//   void listenToConnectivityChanges() {
//     _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
//       // Check if the list of results contains an internet connection
//       bool hasInternet = results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile);
//
//       // If there is a change to a connected state and it was previously not connected
//       if (hasInternet && !isConnected) {
//         print("Connectivity restored. Synchronizing databases...");
//         synchronizeDatabases();
//         checkLoginStatus();
//       }
//
//       // Update the connectivity status
//       setState(() {
//         isConnected = hasInternet;
//       });
//     });
//   }
//
//   // Synchronize data with Firebase
//   Future<void> synchronizeDatabases() async {
//     await dbHelper.synchronizeDatabases();  // Sync with local database and Firebase
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return isLoggedIn && email != null
//         ? HomePage(email: email!) // Go to HomePage if logged in
//         : LoginPage(); // Go to LoginPage if not logged in
//   }

  // @override
  // void dispose() {
  //   // Cancel connectivity subscription to prevent memory leaks
  //   _connectivitySubscription.cancel();
  //   super.dispose();
  // }
//}
