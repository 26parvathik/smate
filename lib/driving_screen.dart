import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'dart:async';
import 'dart:math';

import 'trip_summary_screen.dart';
import 'checkered_background.dart';
import 'services/tflite_service.dart';

class DrivingScreen extends StatefulWidget {
  const DrivingScreen({super.key});

  @override
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen> {

  // ── Driving telemetry ──
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

  // ── Camera + Detection ──
  CameraController? _cameraController;
  bool _cameraReady = false;

  final TfliteService _tfliteService = TfliteService();
  bool _isProcessing = false;
  String _detectedSign = '';

  @override
  void initState() {
    super.initState();
    _initCameraAndModel();
  }

  Future<void> _initCameraAndModel() async {
    // Load TFLite model
    try {
      await _tfliteService.loadModel();
    } catch (e) {
      debugPrint('Failed to load TFLite model: $e');
    }

    // Initialize camera
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Prefer back camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _cameraReady = true;
      });

      // Start processing camera frames
      _cameraController!.startImageStream(_onCameraFrame);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // Throttle detection to run max twice per second
  DateTime _lastDetectionTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Called for every camera frame. Runs detection if not already processing and throttling allows.
  void _onCameraFrame(CameraImage cameraImage) {
    if (_isProcessing || !_tfliteService.isLoaded) return;
    
    final now = DateTime.now();
    if (now.difference(_lastDetectionTime).inMilliseconds < 500) return;

    _isProcessing = true;

    // Convert CameraImage (YUV420) to img.Image (RGB)
    final image = _convertCameraImage(cameraImage);
    if (image == null) {
      _isProcessing = false;
      return;
    }

    final detections = _tfliteService.detect(image);

    if (!mounted) {
      _isProcessing = false;
      return;
    }

    setState(() {
      if (detections.isNotEmpty) {
        final best = detections.first;
        _detectedSign = best.label;

        // Auto-update speed limit if a speed-limit sign is detected
        if (TfliteService.speedLimitMap.containsKey(best.classIndex)) {
          speedLimit = TfliteService.speedLimitMap[best.classIndex]!;
        }
      } else {
        _detectedSign = '';
      }
    });

    _lastDetectionTime = DateTime.now();
    _isProcessing = false;
  }

  /// Convert YUV420 camera image to [img.Image] in RGB.
  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      final image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * yPlane.bytesPerRow + x;
          final int uvIndex =
              (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uPlane.bytesPerPixel!;

          final int yVal = yPlane.bytes[yIndex];
          final int uVal = uPlane.bytes[uvIndex];
          final int vVal = vPlane.bytes[uvIndex];

          // YUV to RGB conversion
          int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
          int g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
              .round()
              .clamp(0, 255);
          int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

          image.setPixelRgb(x, y, r, g, b);
        }
      }

      return image;
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  // ── Trip logic (unchanged) ──

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

    accelStream = accelerometerEventStream().listen((event) {
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

  @override
  void dispose() {
    positionStream?.cancel();
    accelStream?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _tfliteService.dispose();
    super.dispose();
  }

  // ── UI ──

  Widget buildCameraPreview() {
    if (!_cameraReady || _cameraController == null) {
      return const SizedBox(height: 50); // Minimal space while initializing
    }

    // Instead of rendering the heavy camera feed, just show the detection result
    if (_detectedSign.isNotEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.greenAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, color: Colors.greenAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              "Detected: $_detectedSign",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    // Show a subtle scanning indicator when active but nothing detected
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt, color: Colors.white54, size: 20),
          SizedBox(width: 8),
          Text(
            "Scanning for signs...",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
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
          Text(title, style: const TextStyle(fontSize: 16)),
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
      appBar: AppBar(title: const Text("SteerMate Driving Monitor")),
      body: CheckeredBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [

                  // Camera + detection preview
                  buildCameraPreview(),

                  const SizedBox(height: 20),

                  buildSpeedometer(),

                  const SizedBox(height: 10),

                  const Text(
                    "km/h",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 40),

                  Text(
                    "Speed Limit : ${speedLimit.toInt()} km/h",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  Slider(
                    min: 10,
                    max: 120,
                    divisions: 22,
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
                      buildStatCard("Harsh Brakes", harshBrakeCount, Colors.orange),
                      buildStatCard("Overspeed", overspeedCount, Colors.red),
                    ],
                  ),

                  const SizedBox(height: 40),

                  tripRunning
                      ? ElevatedButton(
                          onPressed: stopTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16,
                            ),
                          ),
                          child: const Text("Stop Trip", style: TextStyle(fontSize: 18)),
                        )
                      : ElevatedButton(
                          onPressed: startTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16,
                            ),
                          ),
                          child: const Text("Start Trip", style: TextStyle(fontSize: 18)),
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