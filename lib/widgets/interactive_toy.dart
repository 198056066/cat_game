import 'dart:math';

import 'package:flutter/material.dart';

enum ToyType { yarn, mouse, feather, laser }

class ToyConfig {
  ToyConfig({
    required this.type,
    required this.baseColor,
    required this.accentColor,
    required this.startPosition,
    required this.movement,
    required this.periodSeconds,
  });

  final ToyType type;
  final Color baseColor;
  final Color accentColor;
  final Offset startPosition;
  final Offset movement;
  final double periodSeconds;
  bool visible = true;
}

class InteractiveToy extends StatefulWidget {
  const InteractiveToy({
    super.key,
    required this.config,
    required this.diameter,
    required this.onTap,
  });

  final ToyConfig config;
  final double diameter;
  final VoidCallback onTap;

  @override
  State<InteractiveToy> createState() => _InteractiveToyState();
}

class _InteractiveToyState extends State<InteractiveToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _motion;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.config.periodSeconds * 1000).round()),
    )..repeat(reverse: true);
    _motion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final dx = widget.config.startPosition.dx +
            widget.config.movement.dx * (_motion.value - 0.5);
        final dy = widget.config.startPosition.dy +
            widget.config.movement.dy * sin(_motion.value * pi);
        final size = MediaQuery.of(context).size;
        final padding = widget.diameter * 0.2;
        final left = (dx * size.width).clamp(
          padding,
          size.width - widget.diameter - padding,
        );
        final top = (dy * size.height).clamp(
          padding,
          size.height - widget.diameter - padding,
        );
        return Positioned(
          left: left,
          top: top,
          child: AnimatedOpacity(
            opacity: _tapped ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: () {
                widget.onTap();
                setState(() {
                  _tapped = true;
                });
                Future.delayed(const Duration(milliseconds: 220), () {
                  if (mounted) {
                    setState(() {
                      _tapped = false;
                    });
                  }
                });
              },
              child: AnimatedScale(
                scale: _tapped ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _ToyVisual(
                  diameter: widget.diameter,
                  baseColor: widget.config.baseColor,
                  accentColor: widget.config.accentColor,
                  type: widget.config.type,
                  bright: _tapped,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToyVisual extends StatelessWidget {
  const _ToyVisual({
    required this.diameter,
    required this.baseColor,
    required this.accentColor,
    required this.type,
    required this.bright,
  });

  final double diameter;
  final Color baseColor;
  final Color accentColor;
  final ToyType type;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final effectiveBase = bright ? baseColor.withOpacity(0.9) : baseColor;
    return CustomPaint(
      size: Size(diameter, diameter),
      painter: _ToyPainter(
        baseColor: effectiveBase,
        accentColor: accentColor,
        type: type,
        bright: bright,
      ),
    );
  }
}

class _ToyPainter extends CustomPainter {
  _ToyPainter({
    required this.baseColor,
    required this.accentColor,
    required this.type,
    required this.bright,
  });

  final Color baseColor;
  final Color accentColor;
  final ToyType type;
  final bool bright;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = baseColor;
    final accent = Paint()..color = accentColor;
    final glow = Paint()
      ..color = bright ? accentColor.withOpacity(0.45) : accentColor.withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    switch (type) {
      case ToyType.yarn:
        _drawYarn(canvas, size, paint, accent, glow);
        break;
      case ToyType.mouse:
        _drawMouse(canvas, size, paint, accent, glow);
        break;
      case ToyType.feather:
        _drawFeather(canvas, size, paint, accent, glow);
        break;
      case ToyType.laser:
        _drawLaser(canvas, size, paint, accent, glow);
        break;
    }
  }

  void _drawYarn(Canvas canvas, Size size, Paint paint, Paint accent, Paint glow) {
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final radius = size.width * 0.32;
    canvas.drawCircle(center, radius * 1.05, glow);
    canvas.drawCircle(center, radius, paint);
    final linePaint = Paint()
      ..color = accent.color.withOpacity(0.8)
      ..strokeWidth = size.width * 0.03
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final sweep = (i + 1) * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (0.75 + i * 0.05)),
        0.2 + i * 0.6,
        sweep,
        false,
        linePaint,
      );
    }
    canvas.drawCircle(center.translate(radius * 0.6, radius * 0.6), size.width * 0.05, accent);
  }

  void _drawMouse(Canvas canvas, Size size, Paint paint, Paint accent, Paint glow) {
    final bodyRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.55),
      width: size.width * 0.6,
      height: size.height * 0.4,
    );
    canvas.drawOval(bodyRect.inflate(size.width * 0.05), glow);
    canvas.drawOval(bodyRect, paint);
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.35), size.width * 0.09, accent);
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.35), size.width * 0.09, accent);
    final tailPath = Path()
      ..moveTo(size.width * 0.75, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.65,
        size.width * 0.85,
        size.height * 0.85,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = accent.color.withOpacity(0.9)
        ..strokeWidth = size.width * 0.04
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawFeather(Canvas canvas, Size size, Paint paint, Paint accent, Paint glow) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.2,
        size.width * 0.75,
        size.height * 0.3,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.8,
        size.width * 0.25,
        size.height * 0.85,
      );
    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
    final spine = Paint()
      ..color = accent.color.withOpacity(0.8)
      ..strokeWidth = size.width * 0.03
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.8),
      Offset(size.width * 0.7, size.height * 0.35),
      spine,
    );
  }

  void _drawLaser(Canvas canvas, Size size, Paint paint, Paint accent, Paint glow) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(center, size.width * 0.25, glow);
    canvas.drawCircle(center, size.width * 0.18, paint);
    canvas.drawCircle(center, size.width * 0.06, accent);
  }

  @override
  bool shouldRepaint(covariant _ToyPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.type != type ||
        oldDelegate.bright != bright;
  }
}
