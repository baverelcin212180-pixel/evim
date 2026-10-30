import 'package:flutter/material.dart';

import '../theme.dart';

/// Evim özel logosu: degrade yuvarlak karo üzerinde, kapısı oyulmuş beyaz ev.
class EvimLogo extends StatelessWidget {
  final double size;
  final bool shadow;
  const EvimLogo(this.size, {super.key, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    final t = appTheme();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [t.accent, t.accent2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.27),
        boxShadow: shadow ? [BoxShadow(color: t.accent.withValues(alpha: 0.35), blurRadius: size * 0.2, offset: Offset(0, size * 0.09))] : null,
      ),
      child: CustomPaint(painter: _HousePainter(t.on)),
    );
  }
}

class _HousePainter extends CustomPainter {
  final Color c;
  _HousePainter(this.c);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.saveLayer(Offset.zero & s, Paint());
    final white = Paint()
      ..color = c
      ..isAntiAlias = true;
    // çatı (üçgen, yumuşak)
    final roof = Path()
      ..moveTo(w * 0.5, h * 0.24)
      ..lineTo(w * 0.82, h * 0.50)
      ..lineTo(w * 0.18, h * 0.50)
      ..close();
    canvas.drawPath(roof, white);
    // gövde
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.27, h * 0.46, w * 0.46, h * 0.31), Radius.circular(w * 0.05)),
      white,
    );
    // kapı oyuğu (degradeyi gösterir)
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.43, h * 0.55, w * 0.14, h * 0.22), Radius.circular(w * 0.04)),
      clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HousePainter old) => old.c != c;
}
