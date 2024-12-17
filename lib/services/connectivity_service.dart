import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Connectivity subscription
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late Timer _internetCheckTimer;

  // A boolean to track the connection status
  bool isConnected = false;

  // A StreamController to broadcast the connectivity status
  final _connectionStatusController = StreamController<bool>.broadcast();

  // Get the stream that can be listened to
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Method to listen to connectivity changes
  void listenToConnectivityChanges() {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // Check if the list of results contains an internet connection
      bool hasInternet = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);

      if (hasInternet) {
        // Check for an actual internet connection
        bool internetAvailable = await _checkInternetConnection();
        isConnected = internetAvailable;
      } else {
        // No internet
        isConnected = false;
      }

      // Add the new connectivity status to the stream
      _connectionStatusController.add(isConnected);
    });

    // Start a periodic check every 5 seconds to ensure internet is available
    _internetCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      bool internetAvailable = await _checkInternetConnection();
      isConnected = internetAvailable;

      // Add the new connectivity status to the stream
      _connectionStatusController.add(isConnected);
    });
  }

  // Perform a simple HTTP request to check if internet is accessible
  Future<bool> _checkInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(Duration(seconds: 5));
      return response.statusCode ==
          200; // If the response is 200, internet is available
    } catch (e) {
      return false; // If an error occurs (e.g., no internet), return false
    }
  }

  // Dispose method to clean up subscriptions when no longer needed
  void dispose() {
    _connectivitySubscription.cancel();
    _internetCheckTimer.cancel();
    _connectionStatusController.close();
  }
}
