import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Represents a single detected object.
class Detection {
  final double x1, y1, x2, y2;
  final int classIndex;
  final double confidence;

  Detection(this.x1, this.y1, this.x2, this.y2, this.classIndex, this.confidence);

  String get label => TfliteService.classLabels[classIndex];
}

/// Service that loads the YOLOv8n TFLite model and runs inference.
class TfliteService {
  static const String modelPath = 'assets/models/best_float32.tflite';

  static const List<String> classLabels = [
    'Green Light',
    'Red Light',
    'Speed Limit 10',
    'Speed Limit 100',
    'Speed Limit 110',
    'Speed Limit 120',
    'Speed Limit 20',
    'Speed Limit 30',
    'Speed Limit 40',
    'Speed Limit 50',
    'Speed Limit 60',
    'Speed Limit 70',
    'Speed Limit 80',
    'Speed Limit 90',
    'Stop',
  ];

  /// Maps class label → speed value (km/h) for auto speed-limit.
  static const Map<int, double> speedLimitMap = {
    2: 10,   // Speed Limit 10
    3: 100,  // Speed Limit 100
    4: 110,  // Speed Limit 110
    5: 120,  // Speed Limit 120
    6: 20,   // Speed Limit 20
    7: 30,   // Speed Limit 30
    8: 40,   // Speed Limit 40
    9: 50,   // Speed Limit 50
    10: 60,  // Speed Limit 60
    11: 70,  // Speed Limit 70
    12: 80,  // Speed Limit 80
    13: 90,  // Speed Limit 90
  };

  static const int inputSize = 640;
  static const double confThreshold = 0.5;
  static const double iouThreshold = 0.5;
  static const int numClasses = 15;

  Interpreter? _interpreter;
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// Load the model from assets.
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  /// Preprocess an [img.Image] to a float32 input tensor [1, 640, 640, 3].
  Float32List preprocessImage(img.Image image) {
    // Resize to 640x640 (direct resize)
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    final input = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        // img package uses RGB order by default — normalize to [0, 1]
        input[pixelIndex++] = pixel.r / 255.0;
        input[pixelIndex++] = pixel.g / 255.0;
        input[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return input;
  }

  /// Run inference and return detections scaled to [origWidth] x [origHeight].
  List<Detection> detect(img.Image image) {
    if (!_isLoaded || _interpreter == null) return [];

    final origWidth = image.width;
    final origHeight = image.height;

    // 1. Preprocess
    final inputData = preprocessImage(image);
    final inputTensor = inputData.reshape([1, inputSize, inputSize, 3]);

    // 2. Allocate output: [1, 19, 8400]
    final outputBuffer = List.generate(
      1,
      (_) => List.generate(19, (_) => List.filled(8400, 0.0)),
    );

    // 3. Run
    _interpreter!.run(inputTensor, outputBuffer);

    // 4. Post-process
    final rawOutput = outputBuffer[0]; // shape [19][8400]

    List<Detection> detections = [];

    for (int i = 0; i < 8400; i++) {
      // Find best class
      int bestClass = 0;
      double bestScore = rawOutput[4][i];

      for (int c = 1; c < numClasses; c++) {
        double score = rawOutput[4 + c][i];
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestScore < confThreshold) continue;

      // Extract box (cx, cy, w, h) in 640-space
      double cx = rawOutput[0][i];
      double cy = rawOutput[1][i];
      double w = rawOutput[2][i];
      double h = rawOutput[3][i];

      // Convert to corner format
      double x1 = cx - w / 2;
      double y1 = cy - h / 2;
      double x2 = cx + w / 2;
      double y2 = cy + h / 2;

      // Scale back to original image size
      double scaleX = origWidth / inputSize;
      double scaleY = origHeight / inputSize;

      detections.add(Detection(
        x1 * scaleX,
        y1 * scaleY,
        x2 * scaleX,
        y2 * scaleY,
        bestClass,
        bestScore,
      ));
    }

    // 5. Apply NMS
    return _nms(detections, iouThreshold);
  }

  /// Non-Maximum Suppression — keep highest confidence, discard overlapping.
  List<Detection> _nms(List<Detection> detections, double iouThresh) {
    // Sort by confidence descending
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<Detection> result = [];

    while (detections.isNotEmpty) {
      final best = detections.removeAt(0);
      result.add(best);

      detections.removeWhere((d) => _iou(best, d) > iouThresh);
    }

    return result;
  }

  /// Compute Intersection over Union between two detections.
  double _iou(Detection a, Detection b) {
    double x1 = max(a.x1, b.x1);
    double y1 = max(a.y1, b.y1);
    double x2 = min(a.x2, b.x2);
    double y2 = min(a.y2, b.y2);

    double interArea = max(0, x2 - x1) * max(0, y2 - y1);
    double aArea = (a.x2 - a.x1) * (a.y2 - a.y1);
    double bArea = (b.x2 - b.x1) * (b.y2 - b.y1);
    double unionArea = aArea + bArea - interArea;

    return unionArea > 0 ? interArea / unionArea : 0;
  }

  /// Release resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
