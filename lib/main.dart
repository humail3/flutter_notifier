import 'dart:async';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/website_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notifier/screens/website_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:http/http.dart' as http;

import 'package:html/dom.dart' as htmlDom;

// import 'package:html/dom_parsing.dart';
// import 'package:html/html_escape.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_services.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:battery_optimization/battery_optimization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the background service
  await initializeService();

  runApp(MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    bool isConnected = await checkInternetBackground(service);

    if (isConnected) {
      String newContent = await fetchBodyContent();

      // Retrieve previous content from shared preferences
      String? previousContent = await getSavedContent();

      if (newContent != previousContent) {
        await saveContent(newContent);
        sendNotification(service, "Content Changed", "New content: $newContent");
      } else {
        print("No content change detected.");
      }
    }
  });
}

Future<http.Response> fetchContent() {
  return http.get(Uri.parse('https://api.notrufnoe.at/c9/status.php'));
}


Future<String> fetchBodyContent() async {
//   Fetch Content from website
  http.Response response = await fetchContent();
  if (response.statusCode == 200) {
    // Parse the HTML document
    var document = htmlParser.parse(response.body);
    // Extract the <body> tag
    htmlDom.Element? bodyElement = document.body;
    // Return the content of the <body> tag as a string
    String body = bodyElement?.innerHtml ?? '';
    // Clean up the string to remove extra newlines and spaces
    body = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    print("body is: $body");
    return body;
  } else {
    return '';
  }
}


Future<bool> checkInternetBackground(ServiceInstance service) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    sendNotification(service, "No Internet", "Internet is not available.");
    return false;
  } else {
    return true;
  }
}

void sendNotification(ServiceInstance service, String title, String content) {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  flutterLocalNotificationsPlugin.show(
    888, // Notification ID
    title,
    content,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'my_foreground',
        'MY FOREGROUND SERVICE',
        icon: 'ic_bg_service_small',
        ongoing: true,
      ),
    ),
  );
}

Future<void> saveContent(String content) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('content', content);
}

Future<String?> getSavedContent() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('content');
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: HomeScreen.id,
      routes: {
        HomeScreen.id: (context) => HomeScreen(),
        WesbiteScreen.id: (context) => WesbiteScreen(),
      },
    );
  }
}
