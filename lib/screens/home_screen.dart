// import 'dart:convert';

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:notifier/databases/shared_preferences.dart';
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


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String id = "home_screen";

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late NotificationService notificationService;
  String _previousContent = '';
  String _currentContent = '';

  // For Manual Checking
  Future<bool> checkInternet() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // No available network types
      Alert(
              context: context,
              title: "No Internet",
              desc: "Check Internet Connection")
          .show();
      return false;
    } else {
      // net is available
      return true;
    }
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

  void checkForContentChanges() {
    if (_currentContent != _previousContent) {
      // Send notification if content changed
      notificationService.showNotification(
        'Content Changed',
        'Content: $_currentContent',
      );

      // Update previous content to current content, also save in shared prefs
      _previousContent = _currentContent;
      _saveInPrefs(_currentContent);
    } else {
      // No content change, sending notification
      notificationService.showNotification(
        'No Content Change',
        'No changes in the content',
      );
    }
  }

  Future<void> checkChangesBTN() async {
    bool isConnected = await checkInternet();
    if (isConnected) {
      _currentContent = await fetchBodyContent();
      setState(() {
        _currentContent;
      });
      checkForContentChanges();
    }
  }

  void _saveInPrefs(String content) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('content', content);
  }

  void _getFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _previousContent = prefs.getString('content')!;
  }

// For Automatic Checking/ background services
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        notificationChannelId: 'my_foreground_service_channel',
        initialNotificationTitle: 'Service Running',
        initialNotificationContent: 'Checking for updates...',
        foregroundServiceNotificationId: 888,
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

    // Perform any iOS-specific background tasks here
    return true;
  }

  @pragma('vm:entry-point')
  void onStart(ServiceInstance service) async {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      bool isConnected = await checkInternetBackground(service);

      if (isConnected) {
        String newContent = await fetchBodyContent();

        if (newContent != _previousContent) {
          _previousContent = newContent;
          await saveContent(newContent);
          sendNotification(
              flutterLocalNotificationsPlugin,
              "Content Changed",
              "New content detected."
          );
        } else {
          print("No content change detected.");
        }
      }
    });
  }

  Future<bool> checkInternetBackground(ServiceInstance service) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
      sendNotification(
          flutterLocalNotificationsPlugin,
          "No Internet",
          "Internet is not available."
      );
      return false;
    } else {
      return true;
    }
  }

  void sendNotification(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
      String title,
      String content,
      ) {
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


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    notificationService = NotificationService();
    //   request notification permission
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    //   get previous content from shared prefs
    _getFromPrefs();
    // Initialize the background service for automatic checking
    initializeService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Text Change Notifier',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(
                height: 50.0,
              ),
              Text(
                'Monitoring text changes...',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 150.0,
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: ElevatedButton(
                  style: ButtonStyle(
                      padding: MaterialStateProperty.all<EdgeInsets>(
                          EdgeInsets.symmetric(vertical: 12.0))),
                  onPressed: () {
                    checkChangesBTN();
                  },
                  child: Text(
                    'Check',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                  ),
                ),
              ),
              SizedBox(
                height: 50.0,
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: ElevatedButton(
                  style: ButtonStyle(
                      padding: MaterialStateProperty.all<EdgeInsets>(
                          EdgeInsets.symmetric(vertical: 12.0))),
                  onPressed: () {
                    Navigator.pushNamed(context, WesbiteScreen.id);
                  },
                  child: Text(
                    'Go to Website',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                  ),
                ),
              ),
              SizedBox(
                height: 150.0,
              ),
              if (_currentContent != '')
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Current Content: $_currentContent',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18.0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}