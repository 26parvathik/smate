import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'trip_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double speed = 0;
  bool isTripRunning = false;

  StreamSubscription<Position>? positionStream;
  StreamSubscription? accelStream;
  final FlutterTts tts = FlutterTts();

  @override
  void dispose() {
    positionStream?.cancel();
    accelStream?.cancel();
    super.dispose();
  }

  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  Future<void> startTrip() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    setState(() {
      isTripRunning = true;
      speed = 0;
    });

    speak("Trip started. Drive safely.");

    positionStream = Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((Position position) {
      double currentSpeed = position.speed * 3.6;
      setState(() => speed = currentSpeed);
      if (currentSpeed > 60) speak("Slow down! Over speed!");
    });

    accelStream = accelerometerEvents.listen((event) {
      double totalAcc =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (totalAcc > 20) speak("Harsh braking detected!");
    });
  }

  void stopTrip() {
    positionStream?.cancel();
    accelStream?.cancel();
    speak("Trip ended.");
    setState(() => isTripRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SteerMate - Driving"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Current Speed",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text("${speed.toStringAsFixed(1)} km/h",
                style: const TextStyle(fontSize: 50, color: Colors.blue)),
            const SizedBox(height: 50),
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