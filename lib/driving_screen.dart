import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

class DrivingScreen extends StatefulWidget {
  const DrivingScreen({Key? key}) : super(key: key);

  @override
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen> {
  double speed = 0;
  double accelValue = 0;
  double gyroValue = 0;

  bool isTripRunning = false;
  bool harshBraking = false;
  bool overSpeeding = false;

  final double speedLimit = 60.0;

  StreamSubscription<Position>? positionStream;
  StreamSubscription? accelStream;
  StreamSubscription? gyroStream;

  @override
  void dispose() {
    positionStream?.cancel();
    accelStream?.cancel();
    gyroStream?.cancel();
    super.dispose();
  }

  Future<void> startTrip() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    setState(() {
      isTripRunning = true;
    });

    positionStream = Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((Position position) {
      double currentSpeed = position.speed * 3.6;

      setState(() {
        speed = currentSpeed;
        overSpeeding = currentSpeed > speedLimit;
      });
    });

    accelStream = accelerometerEvents.listen((event) {
      double total =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      setState(() {
        accelValue = total;
        harshBraking = total > 20;
      });
    });

    gyroStream = gyroscopeEvents.listen((event) {
      double total =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      setState(() {
        gyroValue = total;
      });
    });
  }

  void stopTrip() async {
    positionStream?.cancel();
    accelStream?.cancel();
    gyroStream?.cancel();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance.collection("trips").add({
        "userId": user.uid,
        "speed": speed,
        "harshBraking": harshBraking,
        "overSpeeding": overSpeeding,
        "timestamp": FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      isTripRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SteerMate Trip")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${speed.toStringAsFixed(1)} km/h",
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Text("Accelerometer: ${accelValue.toStringAsFixed(2)}"),
            Text("Gyroscope: ${gyroValue.toStringAsFixed(2)}"),
            const SizedBox(height: 20),
            Text(
              "Harsh Braking: ${harshBraking ? "YES" : "NO"}",
              style: TextStyle(
                color: harshBraking ? Colors.red : Colors.green,
              ),
            ),
            Text(
              "Overspeeding: ${overSpeeding ? "YES" : "NO"}",
              style: TextStyle(
                color: overSpeeding ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: isTripRunning ? stopTrip : startTrip,
              child: Text(isTripRunning ? "Stop Trip" : "Start Trip"),
            ),
          ],
        ),
      ),
    );
  }
}