import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'dart:async';
import 'dart:math';

import 'trip_summary_screen.dart';
import 'checkered_background.dart';

class DrivingScreen extends StatefulWidget {
  const DrivingScreen({super.key});

  @override
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen> {

  double speed = 0;
  double speedLimit = 40;

  int harshBrakeCount = 0;
  int overspeedCount = 0;

  bool harshBraking = false;
  bool overSpeeding = false;

  double tripScore = 100;

  bool tripRunning = false;

  StreamSubscription<Position>? positionStream;
  StreamSubscription? accelStream;

  final FlutterTts tts = FlutterTts();

  bool harshLock = false;
  bool overspeedLock = false;

  Future<void> startTrip() async {

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return;
    }

    setState(() {
      tripRunning = true;
    });

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((Position position) {

      double currentSpeed = position.speed * 3.6;

      setState(() {
        speed = currentSpeed;
      });

      if (speed > speedLimit) {

        if (!overspeedLock) {
          overspeedCount++;
          overspeedLock = true;
          tts.speak("Slow down. Overspeeding detected");
        }

        setState(() {
          overSpeeding = true;
        });

      } else {

        overspeedLock = false;

        setState(() {
          overSpeeding = false;
        });

      }

    });

    accelStream = accelerometerEvents.listen((event) {

      double magnitude = sqrt(
        event.x * event.x +
        event.y * event.y +
        event.z * event.z,
      );

      if (magnitude < 7) {

        if (!harshLock) {
          harshBrakeCount++;
          harshLock = true;
          tts.speak("Harsh braking detected");
        }

        setState(() {
          harshBraking = true;
        });

      } else {

        harshLock = false;

        setState(() {
          harshBraking = false;
        });

      }

    });

  }

  Future<void> stopTrip() async {

    positionStream?.cancel();
    accelStream?.cancel();

    setState(() {
      tripRunning = false;
    });

    tripScore = 100 - (harshBrakeCount * 2) - (overspeedCount * 2);

    if (tripScore < 0) {
      tripScore = 0;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {

      await FirebaseFirestore.instance.collection("trips").add({
        "userId": user.uid,
        "harshBraking": harshBrakeCount,
        "overspeed": overspeedCount,
        "score": tripScore,
        "speedLimit": speedLimit,
        "timestamp": FieldValue.serverTimestamp(),
      });

    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripSummaryScreen(
          score: tripScore,
          harshBrake: harshBrakeCount,
          overspeed: overspeedCount,
          speedLimit: speedLimit,
        ),
      ),
    );

  }

  Widget buildSpeedometer() {

    return Container(
      width: 220,
      height: 220,

      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        border: Border.all(
          color: overSpeeding ? Colors.red : Colors.green,
          width: 6,
        ),
      ),

      child: Center(
        child: Text(
          speed.toStringAsFixed(0),
          style: const TextStyle(
            fontSize: 70,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

  }

  Widget buildStatCard(String title, int value, Color color) {

    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        children: [

          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 10),

          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("SteerMate Driving Monitor"),
      ),

      body: CheckeredBackground(

        child: SafeArea(

          child: SingleChildScrollView(

            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(

                children: [

                  const SizedBox(height: 20),

                  buildSpeedometer(),

                  const SizedBox(height: 10),

                  const Text(
                    "km/h",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Text(
                    "Speed Limit : ${speedLimit.toInt()} km/h",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Slider(
                    min: 20,
                    max: 120,
                    divisions: 20,
                    value: speedLimit,
                    label: speedLimit.toInt().toString(),
                    onChanged: (value) {

                      setState(() {
                        speedLimit = value;
                      });

                    },
                  ),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                    children: [

                      buildStatCard(
                        "Harsh Brakes",
                        harshBrakeCount,
                        Colors.orange,
                      ),

                      buildStatCard(
                        "Overspeed",
                        overspeedCount,
                        Colors.red,
                      ),

                    ],
                  ),

                  const SizedBox(height: 40),

                  tripRunning
                      ? ElevatedButton(
                          onPressed: stopTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            "Stop Trip",
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: startTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            "Start Trip",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),

                  const SizedBox(height: 40),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}