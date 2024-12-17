import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsHelper {
  // create instance of fcm
  final _firebaseMessaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> showNotification(RemoteMessage message) async {
    if (message != null) {
      // Extract details from the message
      String title = message.notification?.title ?? 'No Title';
      String body = message.notification?.body ?? 'No Body';

      // Create a notification
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        channelDescription: 'Your channel description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      // Show notification
      await flutterLocalNotificationsPlugin.show(
        0, // notification ID
        title,
        body,
        platformChannelSpecifics,
        payload: message.data.toString(),
      );
    }
  }

  Future<String?> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "hedieaty-7c4d5",
      "private_key_id": "bad919ac6ac31beb882c05e3eae8370cd03516d7",
      "private_key":
      "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCp1A9qJkyKLqSx\nmmuKHN+tA3/CVF4k8e4JTinDjhYSJASdb6ibUgnqux29VQMRECiTk4xczKKxX6aA\ncZFFuKypcHswrTxB+FMkT7M7OdA2LbzwmNW/reotXHmSy/+EQy5kiiyba4YKPnSX\naeKkd4lI1TRQS+RqhCHTP74qM2+mF7/YT1O1ZiMJERhGNNyZojgylCzpV7TdUjxb\nMWqc1p1kUjpOkBbVIosQHYBW4zg3hBZJJeNyqFUcxmAvQQ6AZw8Oegp/ZasGs46s\nw9EUGjG23bUQEiQwlnk1uOSgyKGx4XnQ8yodVZtYlYLkjZfqn5jSbn1TSmBXH72f\nwqriLHTnAgMBAAECggEAAfl/PGK5nRmxvIbpHS/8wcw6ng3REmjltaH9BlMOmqNk\nklgMA9JOXzZRwDPO11HyxtR+W03dzmYoT3ICmGbvSwENzaEWBEZY4SE0Gkovy5F4\nkuuUAKiLAoACwdwxWl5VmcGphx0W7+OOA3ytr+/b3sbr1ssrGrnykrw4/9CdSbcU\nGwpNtsEVcoo/tSFL/7Edqqg9+iymeXwkF5InxdSsff7xAGvevhdhpNYJ3zzQ1yyT\nAPj1TN6AewKyTIf2qp0JhccuFrmD8I13gqylHWxPngZSPrbMkuJD7QEhwBwK/GH4\nMKlieQLVvaRkwJ00jZREHAelwUsJsM8vDjo0QqOmUQKBgQDlWns19BzB6iF4hxoj\nWrzZVbV53hlapytJSEAxdCNCrbuFl5V6NVOKhblaxxHJVXm5ARB6ABg3FdeK2AOD\ngMt9zG2ux+dlCdIBja8cUMiZE3nNMJ4vfh/tnHWiZ5knLW5YkYF3lPwl9L8IPzvW\njlmX2oy2wJ81ZBOdBs+fKpvAVQKBgQC9jykyOqKtLHn0ndfTHkT/huU0lXKLN0oI\nAAumA5hehQ6kzYf+vKjKttgmehXxPPIdmhH175sWIL4D9mV0oaOVsAGnAN12V8oD\nVMgtr1qnTr/eHkMlLnxSDyok6fgDcfyuI13UqtmKuyRJ7eaHT+deQ+PdGiEYL+Xf\nnpLMRgqsSwKBgCvrhcixNIiV008HYCQBDkT4OsZZl7VaadmgslpGCTKNnmlYu9Ep\nQRQ3w2T01h0d9y9MWuFh/0EdN6do8lNOaKlwalicA12/4a1WeoALoD5gEmUOuFwT\n5P1VhtlQyW1NL+JaCtbhet+x3JsxsL3HiLShr2yXumU5AuCBG2U5fZX5AoGAPM9Q\nR+zHgwZhmTeJpRBw0ghUPyoyNLbn6Oka04cTuj61E+lbVzzuaRl+/djscRc8FIL4\ngAz9k3uteVfx9Bhmgf6UiR6d7Pj8tVTdYsp+Km343yiWIbdn6msy+eSUy4YlqTdv\nQmoMn5Spb44CBiZ78qGU17kqJLg45iPYs+9EPUECgYAemRaV/D1iApyedwcaqBH1\nzY+9S5SjaS2SS2ab2NqRvyKjCdqKYuas9KPEgNsn1E8iUgMcHc/6IXYrIrJG+QED\nr7SUlb3wTJM2fOMKjtrjFQUyYjldTCj7NI5R/atcI5EPneTLelEZVy5tsVpNZapC\n2hZZYanWMEtup7mDS+G6Aw==\n-----END PRIVATE KEY-----\n",
      "client_email":
      "firebase-adminsdk-5frfl@hedieaty-7c4d5.iam.gserviceaccount.com",
      "client_id": "110251347283002666009",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
      "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
      "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-5frfl%40hedieaty-7c4d5.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    List<String> scopes = [
      "https://www.googleapis.com/auth/userinfo.email",
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/firebase.messaging"
    ];

    try {
      http.Client client = await auth.clientViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson), scopes);

      auth.AccessCredentials credentials =
      await auth.obtainAccessCredentialsViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client);

      client.close();
      print(
          "Access Token: ${credentials.accessToken.data}"); // Print Access Token
      return credentials.accessToken.data;
    } catch (e) {
      print("Error getting access token: $e");
      return null;
    }
  }

  Future<void> sendNotifications({
    required String fcmToken,
    required String title,
    required String body,
    required String userId,
    String? type,
  }) async {
//      try {
    final String? serverKeyAuthorization = await getAccessToken();

    const String endpointFirebaseCloudMessaging =
        "https://fcm.googleapis.com/v1/projects/hedieaty-7c4d5/messages:send";

    final Map<String, dynamic> message = {
      "message": {
        "token": fcmToken,
        "notification": {"title": title, "body": body},
        "android": {
          "notification": {
            "notification_priority": "PRIORITY_MAX",
            "sound": "default"
          }
        },
        "apns": {
          "payload": {
            "aps": {"content_available": true}
          }
        },
        "data": {
          "type": type,
          "id": userId,
          "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }
      }
    };
    final http.Response response = await http.post(
      Uri.parse(endpointFirebaseCloudMessaging),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $serverKeyAuthorization',
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print("Notification sent successfully.");
    }
  }
}

//
// Future<void> backgroundMessageHandler(RemoteMessage message) async {
//   // Initialize the local notifications plugin in background
//   await NotificationsHelper.showNotification(message);
// }
// static Future<void> showNotification(RemoteMessage message) async {
//   const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//     'default_channel_id',
//     'default_channel_id',
//     'Default Channel',
//     channelDescription: 'Default channel for notifications',
//     importance: Importance.max,
//     priority: Priority.high,
//     showWhen: false,
//   );
//   const NotificationDetails notificationDetails =
//   NotificationDetails(android: androidDetails);
//
//   await flutterLocalNotificationsPlugin.show(
//     0,
//     message.notification?.title,
//     message.notification?.body,
//     notificationDetails,
//   );
// }

// static Future<void> init() async {
//   const AndroidInitializationSettings androidInitializationSettings =
//   AndroidInitializationSettings('app_icon');
//
//   final InitializationSettings initializationSettings =
//   InitializationSettings(android: androidInitializationSettings);
//
//   await flutterLocalNotificationsPlugin.initialize(initializationSettings);
// }


// // initialize notifications for this app or device
// Future<void> initNotifications() async {
//   await _firebaseMessaging.requestPermission();
//   // get device token
//   String? deviceToken = await _firebaseMessaging.getToken();
//   print(
//       "===================Device FirebaseMessaging Token====================");
//   print(deviceToken);
//   print(
//       "===================Device FirebaseMessaging Token====================");
// }

// // handle notifications when received
// void handleMessages(RemoteMessage? message) {
//   if (message != null) {
//     print('receiveeeeeeeeeeeeed');
//     // navigatorKey.currentState?.pushNamed(NotificationsScreen.routeName, arguments: message);
//     Fluttertoast.showToast(
//         msg: 'on Background Message notification',
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.CENTER,
//         timeInSecForIosWeb: 1,
//         backgroundColor: Colors.blue,
//         textColor: Colors.white,
//         fontSize: 16.0
//     );
//   }
// }

// // handel notifications in case app is terminated
// void handleBackgroundNotifications() async {
//   FirebaseMessaging.instance.getInitialMessage().then((handleMessages));
//   FirebaseMessaging.onMessageOpenedApp.listen(handleMessages);
// }

// Map<String, dynamic> getBody({
//   required String fcmToken,
//   required String title,
//   required String body,
//   required String userId,
//   String? type,
// }) {
//   return {
//     "message": {
//       "token": fcmToken,
//       "notification": {"title": title, "body": body},
//       "android": {
//         "notification": {
//           "notification_priority": "PRIORITY_MAX",
//           "sound": "default"
//         }
//       },
//       "apns": {
//         "payload": {
//           "aps": {"content_available": true}
//         }
//       },
//       "data": {
//         "type": type,
//         "id": userId,
//         "click_action": "FLUTTER_NOTIFICATION_CLICK"
//       }
//     }
//   };
// }

//}
//     Dio dio = Dio();
//     dio.options.headers['Content-Type'] = 'application/json';
//     dio.options.headers['Authorization'] = 'Bearer $serverKeyAuthorization';

//     var response = await dio.post(
//       urlEndPoint,
//       data: getBody(
//         userId: userId,
//         fcmToken: fcmToken,
//         title: title,
//         body: body,
//         type: type ?? "message",
//       ),
//     );

//     // Print response status code and body for debugging
//     print('Response Status Code: ${response.statusCode}');
//     print('Response Data: ${response.data}');
//   } catch (e) {
//     print("Error sending notification: $e");
//   }
// }


// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:googleapis_auth/auth_io.dart' as auth;
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:fluttertoast/fluttertoast.dart';
//
// class NotificationsHelper {
//   // creat instance of fbm
//   final _firebaseMessaging = FirebaseMessaging.instance;
//
//
//   // initialize notifications for this app or device
//   Future<void> initNotifications() async {
//     await _firebaseMessaging.requestPermission();
//     // get device token
//     String? deviceToken = await _firebaseMessaging.getToken();
//     // DeviceToken = deviceToken;
//     print(
//         "===================Device FirebaseMessaging Token====================");
//     print(deviceToken);
//     print(
//         "===================Device FirebaseMessaging Token====================");
//   }
//
//   // handle notifications when received
//   void handleMessages(RemoteMessage? message) {
//     if (message != null) {
//       // navigatorKey.currentState?.pushNamed(NotificationsScreen.routeName, arguments: message);
//       Fluttertoast.showToast(
//           msg: 'on Background Message notification',
//           toastLength: Toast.LENGTH_SHORT,
//           gravity: ToastGravity.CENTER,
//           timeInSecForIosWeb: 1,
//           backgroundColor: Colors.blue,
//           textColor: Colors.white,
//           fontSize: 16.0
//       );
//     }
// }
//
//   // handel notifications in case app is terminated
//   void handleBackgroundNotifications() async {
//     FirebaseMessaging.instance.getInitialMessage().then((handleMessages));
//     FirebaseMessaging.onMessageOpenedApp.listen(handleMessages);
//   }
//
//   Future<String?> getAccessToken() async {
//     final serviceAccountJson = {
//       "type": "service_account",
//       "project_id": "hedieaty-7c4d5",
//       "private_key_id": "bad919ac6ac31beb882c05e3eae8370cd03516d7",
//       "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCp1A9qJkyKLqSx\nmmuKHN+tA3/CVF4k8e4JTinDjhYSJASdb6ibUgnqux29VQMRECiTk4xczKKxX6aA\ncZFFuKypcHswrTxB+FMkT7M7OdA2LbzwmNW/reotXHmSy/+EQy5kiiyba4YKPnSX\naeKkd4lI1TRQS+RqhCHTP74qM2+mF7/YT1O1ZiMJERhGNNyZojgylCzpV7TdUjxb\nMWqc1p1kUjpOkBbVIosQHYBW4zg3hBZJJeNyqFUcxmAvQQ6AZw8Oegp/ZasGs46s\nw9EUGjG23bUQEiQwlnk1uOSgyKGx4XnQ8yodVZtYlYLkjZfqn5jSbn1TSmBXH72f\nwqriLHTnAgMBAAECggEAAfl/PGK5nRmxvIbpHS/8wcw6ng3REmjltaH9BlMOmqNk\nklgMA9JOXzZRwDPO11HyxtR+W03dzmYoT3ICmGbvSwENzaEWBEZY4SE0Gkovy5F4\nkuuUAKiLAoACwdwxWl5VmcGphx0W7+OOA3ytr+/b3sbr1ssrGrnykrw4/9CdSbcU\nGwpNtsEVcoo/tSFL/7Edqqg9+iymeXwkF5InxdSsff7xAGvevhdhpNYJ3zzQ1yyT\nAPj1TN6AewKyTIf2qp0JhccuFrmD8I13gqylHWxPngZSPrbMkuJD7QEhwBwK/GH4\nMKlieQLVvaRkwJ00jZREHAelwUsJsM8vDjo0QqOmUQKBgQDlWns19BzB6iF4hxoj\nWrzZVbV53hlapytJSEAxdCNCrbuFl5V6NVOKhblaxxHJVXm5ARB6ABg3FdeK2AOD\ngMt9zG2ux+dlCdIBja8cUMiZE3nNMJ4vfh/tnHWiZ5knLW5YkYF3lPwl9L8IPzvW\njlmX2oy2wJ81ZBOdBs+fKpvAVQKBgQC9jykyOqKtLHn0ndfTHkT/huU0lXKLN0oI\nAAumA5hehQ6kzYf+vKjKttgmehXxPPIdmhH175sWIL4D9mV0oaOVsAGnAN12V8oD\nVMgtr1qnTr/eHkMlLnxSDyok6fgDcfyuI13UqtmKuyRJ7eaHT+deQ+PdGiEYL+Xf\nnpLMRgqsSwKBgCvrhcixNIiV008HYCQBDkT4OsZZl7VaadmgslpGCTKNnmlYu9Ep\nQRQ3w2T01h0d9y9MWuFh/0EdN6do8lNOaKlwalicA12/4a1WeoALoD5gEmUOuFwT\n5P1VhtlQyW1NL+JaCtbhet+x3JsxsL3HiLShr2yXumU5AuCBG2U5fZX5AoGAPM9Q\nR+zHgwZhmTeJpRBw0ghUPyoyNLbn6Oka04cTuj61E+lbVzzuaRl+/djscRc8FIL4\ngAz9k3uteVfx9Bhmgf6UiR6d7Pj8tVTdYsp+Km343yiWIbdn6msy+eSUy4YlqTdv\nQmoMn5Spb44CBiZ78qGU17kqJLg45iPYs+9EPUECgYAemRaV/D1iApyedwcaqBH1\nzY+9S5SjaS2SS2ab2NqRvyKjCdqKYuas9KPEgNsn1E8iUgMcHc/6IXYrIrJG+QED\nr7SUlb3wTJM2fOMKjtrjFQUyYjldTCj7NI5R/atcI5EPneTLelEZVy5tsVpNZapC\n2hZZYanWMEtup7mDS+G6Aw==\n-----END PRIVATE KEY-----\n",
//       "client_email": "firebase-adminsdk-5frfl@hedieaty-7c4d5.iam.gserviceaccount.com",
//       "client_id": "110251347283002666009",
//       "auth_uri": "https://accounts.google.com/o/oauth2/auth",
//       "token_uri": "https://oauth2.googleapis.com/token",
//       "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
//       "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-5frfl%40hedieaty-7c4d5.iam.gserviceaccount.com",
//       "universe_domain": "googleapis.com"
//     };
//
//
//     List<String> scopes = [
//       "https://www.googleapis.com/auth/userinfo.email",
//       "https://www.googleapis.com/auth/firebase.database",
//       "https://www.googleapis.com/auth/firebase.messaging"
//     ];
//
//     try {
//       http.Client client = await auth.clientViaServiceAccount(
//           auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
//           scopes);
//
//       auth.AccessCredentials credentials =
//       await auth.obtainAccessCredentialsViaServiceAccount(
//           auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
//           scopes,
//           client);
//
//       client.close();
//       print(
//           "Access Token: ${credentials.accessToken
//               .data}"); // Print Access Token
//       return credentials.accessToken.data;
//     } catch (e) {
//       print("Error getting access token: $e");
//       return null;
//     }
//   }
//
//   Map<String, dynamic> getBody({
//     required String fcmToken,
//     required String title,
//     required String body,
//     required String userId,
//     String? type,
//   }) {
//     return {
//       "message": {
//         "token": fcmToken,
//         "notification": {"title": title, "body": body},
//         "android": {
//           "notification": {
//             "notification_priority": "PRIORITY_MAX",
//             "sound": "default"
//           }
//         },
//         "apns": {
//           "payload": {
//             "aps": {"content_available": true}
//           }
//         },
//         "data": {
//           "type": type,
//           "id": userId,
//           "click_action": "FLUTTER_NOTIFICATION_CLICK"
//         }
//       }
//     };
//   }
//
//   Future<void> sendNotifications({
//     required String fcmToken,
//     required String title,
//     required String body,
//     required String userId,
//     String? type,
//   })async {
//     try {
//       var serverKeyAuthorization = await getAccessToken();
//
//       // change your project id
//       const String urlEndPoint = "https://fcm.googleapis.com/v1/projects/hedieaty-7c4d5/messages:send";
//
//
//       Dio dio = Dio();
//       dio.options.headers['Content-Type'] = 'application/json';
//       dio.options.headers['Authorization'] = 'Bearer $serverKeyAuthorization';
//
//       var response = await dio.post(
//         urlEndPoint,
//         data: getBody(
//           userId: userId,
//           fcmToken: fcmToken,
//           title: title,
//           body: body,
//           type: type ?? "message",
//         ),
//       );
//
//       // Print response status code and body for debugging
//       print('Response Status Code: ${response.statusCode}');
//       print('Response Data: ${response.data}');
//     } catch (e) {
//       print("Error sending notification: $e");
//     }
//   }
// }
//