import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

/// Branded teardrop pin (blue gradient, white core, soft ground shadow).
class LocationPinMarker {
  LocationPinMarker._();

  static const double _logicalWidth = 46;
  static const double _logicalHeight = 62;
  static const double _scale = 3;

  static gmaps.BitmapDescriptor? _cache;

  static Future<gmaps.BitmapDescriptor?> create() async {
    if (_cache != null) return _cache;
    try {
      final w = _logicalWidth * _scale;
      final h = _logicalHeight * _scale;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(_scale);

      const cx = _logicalWidth / 2;
      const headR = 17.0;
      const headCy = 22.0;
      const tipY = _logicalHeight - 7;

      // Ground shadow under the tip.
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(cx, tipY + 1), width: 18, height: 6),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );

      // Teardrop body.
      final body = Path()
        ..moveTo(cx, tipY)
        ..cubicTo(cx - 5, tipY - 8, cx - headR, headCy + 8, cx - headR, headCy)
        ..arcToPoint(
          const Offset(cx + headR, headCy),
          radius: const Radius.circular(headR),
          clockwise: true,
        )
        ..cubicTo(cx + headR, headCy + 8, cx + 5, tipY - 8, cx, tipY)
        ..close();

      canvas.drawShadow(body, const Color(0x662563EB), 3, true);
      canvas.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(cx, 0),
            const Offset(cx, tipY),
            const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
      );
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white,
      );

      // White core with a small brand dot.
      canvas.drawCircle(const Offset(cx, headCy), 9.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        const Offset(cx, headCy),
        4.6,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(cx, headCy - 5),
            const Offset(cx, headCy + 5),
            const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
      );

      final image = await recorder.endRecording().toImage(w.round(), h.round());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      _cache = gmaps.BitmapDescriptor.bytes(
        data.buffer.asUint8List(),
        width: _logicalWidth,
        height: _logicalHeight,
      );
      return _cache;
    } catch (_) {
      return null;
    }
  }
}
