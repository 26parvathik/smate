import 'package:flutter/material.dart';
import '../services/tflite_service.dart';

/// CustomPainter that draws bounding boxes and class labels over the camera preview.
class DetectionOverlay extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;  // original image dimensions
  final Size widgetSize; // display widget dimensions

  DetectionOverlay({
    required this.detections,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    for (final det in detections) {
      final Color color = _colorForClass(det.classIndex);

      // Bounding box
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final rect = Rect.fromLTRB(
        det.x1 * scaleX,
        det.y1 * scaleY,
        det.x2 * scaleX,
        det.y2 * scaleY,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );

      // Label background
      final labelText = '${det.label}  ${(det.confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bgRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 6,
        textPainter.width + 8,
        textPainter.height + 6,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: 0.85),
      );

      textPainter.paint(canvas, Offset(bgRect.left + 4, bgRect.top + 3));
    }
  }

  Color _colorForClass(int index) {
    switch (index) {
      case 0:  return Colors.greenAccent;        // Green Light
      case 1:  return Colors.redAccent;           // Red Light
      case 14: return Colors.red;                 // Stop
      default: return Colors.lightBlueAccent;     // Speed Limit signs
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlay oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
