import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'login.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(HedieatyApp());
}

class HedieatyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedieaty',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AppState(),
    );
  }
}

class AppState extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = useState(false);  // Hook to track login state
    final email = useState<String?>(null);  // Hook to track email

    Future<void> checkLoginStatus(ValueNotifier<bool> isLoggedIn, ValueNotifier<String?> email) async {
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool loginStatus = prefs.getBool('isLoggedIn') ?? false;
        String? userEmail = prefs.getString('email');

        isLoggedIn.value = loginStatus;
        email.value = userEmail;
      } catch (e) {
        debugPrint("Error reading SharedPreferences: $e");
        isLoggedIn.value = false;
        email.value = null;
      }
    }

    useEffect(() {
      checkLoginStatus(isLoggedIn, email);  // Call function to check login status
      return null;
    }, []);

    return isLoggedIn.value && email.value != null
        ? HomePage(email: email.value!) // Go to HomePage if logged in
        : LoginPage(); // Go to LoginPage if not logged in
  }
}
