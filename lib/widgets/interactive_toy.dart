import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum ToyType { yarn, mouse, feather, laser }

enum MotionMode { drift, dart, peek, escape, pause }

class ToyConfig {
  ToyConfig({
    required this.type,
    required this.baseColor,
    required this.accentColor,
    required this.detailColor,
    required this.startPosition,
    required this.movement,
    required this.periodSeconds,
  });

  final ToyType type;
  final Color baseColor;
  final Color accentColor;
  final Color detailColor;
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
  final Random _random = Random();
  late final Ticker _ticker;
  Duration? _lastTick;

  Offset _position = Offset.zero;
  Offset _segmentStart = Offset.zero;
  Offset _segmentEnd = Offset.zero;
  double _segmentProgress = 0;
  double _segmentDuration = 1.0;
  MotionMode _mode = MotionMode.drift;

  int _dartSegmentsRemaining = 0;
  int _segmentsUntilPeek = 3;
  bool _peekReturning = false;
  double _pauseRemaining = 0;

  bool _tapped = false;
  double _shakeRemaining = 0;

  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _position = widget.config.startPosition;
    _segmentStart = _position;
    _segmentEnd = _position;
    _segmentProgress = 1.0;
    _segmentDuration = 1.0;
    _segmentsUntilPeek = _randomRange(2, 4);
    _ticker = createTicker(_tick)..start();
    _startNextSegment();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (_lastTick == null) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick!).inMilliseconds / 1000.0;
    _lastTick = elapsed;

    if (_pauseRemaining > 0) {
      _pauseRemaining = max(0, _pauseRemaining - dt);
      if (_pauseRemaining == 0) {
        _startNextSegment();
      }
      setState(() {});
      return;
    }

    if (_shakeRemaining > 0) {
      _shakeRemaining = max(0, _shakeRemaining - dt);
    }

    _segmentProgress += dt / _segmentDuration;
    if (_segmentProgress >= 1) {
      _position = _segmentEnd;
      _startNextSegment();
    } else {
      final eased = _ease(_segmentProgress);
      _position = Offset.lerp(_segmentStart, _segmentEnd, eased) ?? _segmentEnd;
    }

    setState(() {});
  }

  double _ease(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return clamped * clamped * (3 - 2 * clamped);
  }

  void _startNextSegment() {
    if (widget.config.type == ToyType.mouse) {
      _startMouseSegment();
      return;
    }
    _startDriftSegment();
  }

  void _startMouseSegment() {
    if (_mode == MotionMode.peek && !_peekReturning) {
      _peekReturning = true;
      _startSegment(_segmentEnd, _peekOutPosition(), 0.6, MotionMode.peek);
      return;
    }

    if (_mode == MotionMode.peek && _peekReturning) {
      _peekReturning = false;
      _segmentsUntilPeek = _randomRange(2, 4);
    }

    if (_mode == MotionMode.escape) {
      _mode = MotionMode.dart;
      _dartSegmentsRemaining = _randomRange(2, 4);
    }

    if (_segmentsUntilPeek <= 0) {
      _startPeek();
      return;
    }

    if (_dartSegmentsRemaining <= 0) {
      _dartSegmentsRemaining = _randomRange(2, 4);
      _segmentsUntilPeek -= 1;
    }

    _dartSegmentsRemaining -= 1;
    _startDartSegment();
  }

  void _startDriftSegment() {
    final delta = Offset(
      _randomRangeDouble(-0.05, 0.05),
      _randomRangeDouble(-0.045, 0.045),
    );
    final target = _clampPosition(_position + delta);
    _startSegment(_position, target, _randomRangeDouble(2.4, 4.4), MotionMode.drift);
  }

  void _startDartSegment() {
    final delta = Offset(
      _randomRangeDouble(-0.14, 0.14),
      _randomRangeDouble(-0.1, 0.1),
    );
    final target = _clampPosition(_position + delta);
    _startSegment(_position, target, _randomRangeDouble(0.45, 0.75), MotionMode.dart);
    if (_random.nextDouble() < 0.4) {
      _pauseRemaining = _randomRangeDouble(0.25, 0.6);
    }
  }

  void _startPeek() {
    _mode = MotionMode.peek;
    _peekReturning = false;
    final entry = _peekInPosition();
    _position = _peekStartPosition();
    _startSegment(_position, entry, _randomRangeDouble(0.5, 0.9), MotionMode.peek);
  }

  Offset _peekStartPosition() {
    final side = _random.nextInt(4);
    switch (side) {
      case 0:
        return Offset(-0.15, _randomRangeDouble(0.25, 0.7));
      case 1:
        return Offset(1.15, _randomRangeDouble(0.25, 0.7));
      case 2:
        return Offset(_randomRangeDouble(0.2, 0.8), -0.15);
      default:
        return Offset(_randomRangeDouble(0.2, 0.8), 1.15);
    }
  }

  Offset _peekInPosition() {
    return Offset(
      _position.dx.clamp(0.05, 0.95),
      _position.dy.clamp(0.05, 0.95),
    );
  }

  Offset _peekOutPosition() {
    return _peekStartPosition();
  }

  void _startEscape(Offset tapPosition) {
    _mode = MotionMode.escape;
    _shakeRemaining = 0.55;
    final direction = (_position - tapPosition);
    final norm = direction.distance == 0
        ? Offset(_randomRangeDouble(-1, 1), _randomRangeDouble(-1, 1))
        : direction / direction.distance;
    final target = _clampPosition(_position + norm * 0.55);
    _startSegment(_position, target, 0.32, MotionMode.escape);
  }

  Offset _clampPosition(Offset position) {
    final min = 0.06;
    final max = 0.94;
    return Offset(
      position.dx.clamp(min, max),
      position.dy.clamp(min, max),
    );
  }

  void _startSegment(Offset start, Offset end, double duration, MotionMode mode) {
    _segmentStart = start;
    _segmentEnd = end;
    _segmentDuration = max(0.2, duration);
    _segmentProgress = 0;
    _mode = mode;
  }

  int _randomRange(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  double _randomRangeDouble(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  Offset _shakeOffset() {
    if (_shakeRemaining <= 0) {
      return Offset.zero;
    }
    final strength = 0.02 * (_shakeRemaining / 0.4).clamp(0.2, 1.0);
    return Offset(
      _randomRangeDouble(-strength, strength),
      _randomRangeDouble(-strength, strength),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
        final position = _position + _shakeOffset();
        final left = position.dx * _lastSize.width;
        final top = position.dy * _lastSize.height;
        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: AnimatedOpacity(
                  opacity: _tapped ? 1.0 : 0.95,
                  duration: const Duration(milliseconds: 180),
                  child: GestureDetector(
                    onTapDown: (details) {
                      widget.onTap();
                      final local = details.localPosition;
                      final normalized = Offset(
                        (local.dx / widget.diameter).clamp(0.0, 1.0),
                        (local.dy / widget.diameter).clamp(0.0, 1.0),
                      );
                      _startEscape(position + normalized * 0.02);
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
                        detailColor: widget.config.detailColor,
                        type: widget.config.type,
                        bright: _tapped,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    required this.detailColor,
    required this.type,
    required this.bright,
  });

  final double diameter;
  final Color baseColor;
  final Color accentColor;
  final Color detailColor;
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
        detailColor: detailColor,
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
    required this.detailColor,
    required this.type,
    required this.bright,
  });

  final Color baseColor;
  final Color accentColor;
  final Color detailColor;
  final ToyType type;
  final bool bright;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = baseColor;
    final accent = Paint()..color = accentColor;
    final detail = Paint()..color = detailColor;
    final glow = Paint()
      ..color = bright ? accentColor.withOpacity(0.5) : accentColor.withOpacity(0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    switch (type) {
      case ToyType.yarn:
        _drawYarn(canvas, size, paint, accent, detail, glow);
        break;
      case ToyType.mouse:
        _drawMouse(canvas, size, paint, accent, detail, glow);
        break;
      case ToyType.feather:
        _drawBird(canvas, size, paint, accent, detail, glow);
        break;
      case ToyType.laser:
        _drawLaser(canvas, size, paint, accent, detail, glow);
        break;
    }
  }

  void _drawYarn(Canvas canvas, Size size, Paint paint, Paint accent, Paint detail, Paint glow) {
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final radius = size.width * 0.34;
    canvas.drawCircle(center, radius * 1.1, glow);
    canvas.drawCircle(center, radius, paint);

    final linePaint = Paint()
      ..color = detail.color.withOpacity(0.9)
      ..strokeWidth = size.width * 0.04
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final sweep = (i + 1) * 0.65;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (0.62 + i * 0.06)),
        0.3 + i * 0.55,
        sweep,
        false,
        linePaint,
      );
    }

    final knotPaint = Paint()..color = accent.color.withOpacity(0.95);
    final rimPaint = Paint()
      ..color = accent.color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, radius * 1.02, rimPaint);
    canvas.drawCircle(center.translate(radius * 0.55, radius * 0.55), size.width * 0.06, knotPaint);

    final threadPaint = Paint()
      ..color = detail.color.withOpacity(0.85)
      ..strokeWidth = size.width * 0.03
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final threadPath = Path()
      ..moveTo(center.dx + radius * 0.62, center.dy + radius * 0.6)
      ..quadraticBezierTo(
        center.dx + radius * 0.95,
        center.dy + radius * 0.8,
        center.dx + radius * 0.5,
        center.dy + radius * 1.05,
      );
    canvas.drawPath(threadPath, threadPaint);

    final highlight = Paint()
      ..color = accent.color.withOpacity(0.85)
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(-radius * 0.15, -radius * 0.1), radius: radius * 0.6),
      4.4,
      0.6,
      false,
      highlight,
    );
  }

  void _drawMouse(Canvas canvas, Size size, Paint paint, Paint accent, Paint detail, Paint glow) {
    final bodyCenter = Offset(size.width * 0.5, size.height * 0.58);
    final bodyRect = Rect.fromCenter(
      center: bodyCenter,
      width: size.width * 0.62,
      height: size.height * 0.42,
    );
    canvas.drawOval(bodyRect.inflate(size.width * 0.05), glow);
    canvas.drawOval(bodyRect, paint);

    final headCenter = Offset(size.width * 0.5, size.height * 0.42);
    canvas.drawCircle(headCenter, size.width * 0.18, paint);

    final earPaint = Paint()..color = accent.color.withOpacity(0.85);
    canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.3), size.width * 0.11, earPaint);
    canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.3), size.width * 0.11, earPaint);

    final earTip = Paint()..color = detail.color.withOpacity(0.85);
    canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.28), size.width * 0.04, earTip);
    canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.28), size.width * 0.04, earTip);

    final bellyPaint = Paint()..color = accent.color.withOpacity(0.95);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.6),
        width: size.width * 0.34,
        height: size.height * 0.22,
      ),
      bellyPaint,
    );

    final pawPaint = Paint()..color = accent.color.withOpacity(0.9);
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.7), size.width * 0.05, pawPaint);
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.7), size.width * 0.05, pawPaint);

    final snout = Paint()..color = accent.color.withOpacity(0.95);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.48),
        width: size.width * 0.18,
        height: size.width * 0.12,
      ),
      snout,
    );

    final nosePaint = Paint()..color = detail.color.withOpacity(0.9);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.49), size.width * 0.03, nosePaint);

    final eyePaint = Paint()..color = const Color(0xFF5A3A22);
    canvas.drawCircle(Offset(size.width * 0.44, size.height * 0.42), size.width * 0.04, eyePaint);
    canvas.drawCircle(Offset(size.width * 0.56, size.height * 0.42), size.width * 0.04, eyePaint);

    final whisker = Paint()
      ..color = detail.color.withOpacity(0.8)
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.5),
      Offset(size.width * 0.18, size.height * 0.5),
      whisker,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.5),
      Offset(size.width * 0.82, size.height * 0.5),
      whisker,
    );

    final tailPath = Path()
      ..moveTo(size.width * 0.75, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.78,
        size.width * 0.78,
        size.height * 0.92,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = detail.color.withOpacity(0.95)
        ..strokeWidth = size.width * 0.05
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBird(Canvas canvas, Size size, Paint paint, Paint accent, Paint detail, Paint glow) {
    final bodyCenter = Offset(size.width * 0.5, size.height * 0.58);
    final bodyRect = Rect.fromCenter(
      center: bodyCenter,
      width: size.width * 0.62,
      height: size.height * 0.44,
    );
    canvas.drawOval(bodyRect.inflate(size.width * 0.05), glow);
    canvas.drawOval(bodyRect, paint);

    final headCenter = Offset(size.width * 0.68, size.height * 0.44);
    canvas.drawCircle(headCenter, size.width * 0.17, paint);

    final beakPath = Path()
      ..moveTo(size.width * 0.82, size.height * 0.46)
      ..lineTo(size.width * 0.96, size.height * 0.52)
      ..lineTo(size.width * 0.82, size.height * 0.56)
      ..close();
    canvas.drawPath(beakPath, detail);

    final eyePaint = Paint()..color = const Color(0xFF5A3A22);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.44), size.width * 0.035, eyePaint);

    final wingPath = Path()
      ..moveTo(size.width * 0.34, size.height * 0.52)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.62,
        size.width * 0.28,
        size.height * 0.78,
      )
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.7,
        size.width * 0.54,
        size.height * 0.6,
      )
      ..close();
    canvas.drawPath(wingPath, accent..color = accent.color.withOpacity(0.85));

    final tailPath = Path()
      ..moveTo(size.width * 0.24, size.height * 0.64)
      ..lineTo(size.width * 0.08, size.height * 0.72)
      ..lineTo(size.width * 0.24, size.height * 0.78)
      ..close();
    canvas.drawPath(tailPath, accent..color = accent.color.withOpacity(0.7));
  }

  void _drawLaser(Canvas canvas, Size size, Paint paint, Paint accent, Paint detail, Paint glow) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final ringPaint = Paint()
      ..color = accent.color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, size.width * 0.28, glow);
    canvas.drawCircle(center, size.width * 0.22, ringPaint);
    canvas.drawCircle(center, size.width * 0.16, paint);
    canvas.drawCircle(center, size.width * 0.06, detail);
  }

  @override
  bool shouldRepaint(covariant _ToyPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.detailColor != detailColor ||
        oldDelegate.type != type ||
        oldDelegate.bright != bright;
  }
}
