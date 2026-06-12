import 'package:flutter/material.dart';

class ScanFramePainter extends CustomPainter {
  final Color color;

  ScanFramePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 30.0;
    const radius = 16.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );

    final path = Path();
    path.addRRect(rrect);
    canvas.drawPath(path, paint..strokeWidth = 1);

    paint.strokeWidth = 4;
    final corners = [
      [Offset.zero, const Offset(cornerLength, 0), const Offset(0, cornerLength)],
      [
        Offset(size.width, 0),
        Offset(size.width - cornerLength, 0),
        Offset(size.width, cornerLength),
      ],
      [
        Offset(0, size.height),
        Offset(cornerLength, size.height),
        Offset(0, size.height - cornerLength),
      ],
      [
        Offset(size.width, size.height),
        Offset(size.width - cornerLength, size.height),
        Offset(size.width, size.height - cornerLength),
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[1], corner[0], paint);
      canvas.drawLine(corner[2], corner[0], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
