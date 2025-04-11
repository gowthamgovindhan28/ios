import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('com.example.app/location');
  bool isGeofencingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    platform.setMethodCallHandler(_handleNativeData);
  }

Future<void> _handleNativeData(MethodCall call) async {
  final data = Map<String, dynamic>.from(call.arguments);
  print("Received: $data");

  if (call.method == "sendLocationUpdate") {
    await FirebaseFirestore.instance.collection("location_logs").add(data);
  } else if (call.method == "sendGeofenceUpdate") {
    await FirebaseFirestore.instance.collection("geofence_logs").add(data);
  } else if (call.method == "sendGeofenceEvent") {
    await FirebaseFirestore.instance.collection("geofence_events").add(data);
  }
}


  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isGeofencingEnabled = prefs.getBool("geofencing") ?? false;
    });
  }

  Future<void> _toggleGeofencing() async {
    final prefs = await SharedPreferences.getInstance();
    if (isGeofencingEnabled) {
      await platform.invokeMethod("stopGeofencing");
    } else {
      await platform.invokeMethod("startGeofencing", {
        "latitude": 12.9716,
        "longitude": 77.5946,
        "radius": 100.0,
      });
    }
    await prefs.setBool("geofencing", !isGeofencingEnabled);
    setState(() {
      isGeofencingEnabled = !isGeofencingEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Geofencing is ${isGeofencingEnabled ? "ON" : "OFF"}'),
              Switch(value: isGeofencingEnabled, onChanged: (_) => _toggleGeofencing())
            ],
          ),
        ),
      ),
    );
  }
}
