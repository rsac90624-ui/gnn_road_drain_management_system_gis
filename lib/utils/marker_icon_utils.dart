import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> createDotIcon({
  double radius = 18,
  Color fillColor = Colors.green,
  Color borderColor = Colors.white,
  double borderWidth = 2,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  final fillPaint = Paint()
    ..color = fillColor
    ..style = PaintingStyle.fill;

  final borderPaint = Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = borderWidth;

  final center = Offset(radius, radius);

  // Border
  canvas.drawCircle(center, radius, borderPaint);

  // Inner fill
  canvas.drawCircle(
    center,
    radius - borderWidth,
    fillPaint,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (radius * 2).toInt(),
    (radius * 2).toInt(),
  );

  final byteData = await image.toByteData(
    format: ImageByteFormat.png,
  );

  return BitmapDescriptor.fromBytes(
    byteData!.buffer.asUint8List(),
  );
}
