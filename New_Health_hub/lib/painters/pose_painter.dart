import 'package:flutter/material.dart';

class PosePainter extends CustomPainter {
  final List<List<double>> keypoints;

  PosePainter(this.keypoints);

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.fill;

    // Draw each keypoint
    for (var kp in keypoints) {
      final y = kp[0] * size.height;
      final x = kp[1] * size.width;

      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    // Optional: draw skeleton lines later
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
