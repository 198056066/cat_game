import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../widgets/interactive_toy.dart';
import '../audio/audio_manager.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final List<ToyConfig> _toys = [];
  final Random _random = Random();
  final AudioManager _audioManager = AudioManager();
  Timer? _laserTimer;
  Timer? _exitLongPressTimer;
  Timer? _soundControlTimer;
  int _activePointers = 0;
  bool _twoFingerTapCandidate = false;
  bool _twoFingerGestureTriggered = false;
  Timer? _twoFingerTimer;

  double _soundVolume = 0.6;
  bool _showSoundControl = false;
  bool _showExitConfirm = false;

  Timer? _comboTimer;
  List<ToyType> _activeCombo = [];

  int _yarnTapCount = 0;
  Timer? _yarnSpinTimer;
  Timer? _yarnResetTimer;

  int _mouseTapCount = 0;
  Timer? _mouseResetTimer;
  Timer? _mouseHideTimer;

  int _birdTapCount = 0;
  Timer? _birdResetTimer;
  Timer? _birdHideTimer;

  int _laserTapCount = 0;
  Timer? _laserRespawnTimer;
  Timer? _laserResetTimer;
  Timer? _laserBurstTimer;
  bool _laserBurstActive = false;

  @override
  void initState() {
    super.initState();
    _toys.addAll([
      ToyConfig(
        type: ToyType.yarn,
        baseColor: const Color(0xFFFFD980),
        accentColor: const Color(0xFFFFFFFF),
        detailColor: const Color(0xFF8B6914),
        startPosition: const Offset(0.25, 0.4),
        movement: const Offset(0.18, 0.06),
        periodSeconds: 6.5,
      ),
      ToyConfig(
        type: ToyType.mouse,
        baseColor: const Color(0xFF8B6914),
        accentColor: const Color(0xFFFFFFFF),
        detailColor: const Color(0xFFFFA566),
        startPosition: const Offset(0.55, 0.5),
        movement: const Offset(0.14, -0.1),
        periodSeconds: 7.8,
      ),
      ToyConfig(
        type: ToyType.feather,
        baseColor: const Color(0xFFFFE0E9),
        accentColor: const Color(0xFFFFF8E6),
        detailColor: const Color(0xFFD9B38C),
        startPosition: const Offset(0.35, 0.6),
        movement: const Offset(-0.12, 0.12),
        periodSeconds: 8.6,
      ),
      ToyConfig(
        type: ToyType.laser,
        baseColor: const Color(0xFFFF9933),
        accentColor: const Color(0xFFFF7F33),
        detailColor: const Color(0xFFFF7F33),
        startPosition: const Offset(0.6, 0.32),
        movement: const Offset(0.1, 0.12),
        periodSeconds: 5.5,
      ),
    ]);
    _audioManager.initialize();
    _audioManager.setVolume(_soundVolume);
    _audioManager.warmUp();
    _rollNewCombo(immediate: true);
    _comboTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _rollNewCombo();
    });
    _laserTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _scheduleLaserIdle();
    });
  }

  @override
  void dispose() {
    _laserTimer?.cancel();
    _exitLongPressTimer?.cancel();
    _soundControlTimer?.cancel();
    _twoFingerTimer?.cancel();
    _comboTimer?.cancel();
    _yarnSpinTimer?.cancel();
    _yarnResetTimer?.cancel();
    _mouseResetTimer?.cancel();
    _mouseHideTimer?.cancel();
    _birdResetTimer?.cancel();
    _birdHideTimer?.cancel();
    _laserResetTimer?.cancel();
    _laserRespawnTimer?.cancel();
    _laserBurstTimer?.cancel();
    _audioManager.dispose();
    super.dispose();
  }

  void _rollNewCombo({bool immediate = false}) {
    final count = _random.nextBool() ? 2 : 3;
    final shuffled = ToyType.values.toList()..shuffle(_random);
    _activeCombo = shuffled.take(count).toList();
    for (final toy in _toys) {
      toy.visible = _activeCombo.contains(toy.type);
    }
    if (immediate) {
      setState(() {});
    } else {
      setState(() {});
    }
  }

  void _scheduleLaserIdle() {
    if (!_activeCombo.contains(ToyType.laser)) {
      return;
    }
    final laser = _toys.firstWhere((toy) => toy.type == ToyType.laser);
    if (_laserBurstActive) {
      return;
    }
    if (_random.nextDouble() < 0.35) {
      laser.visible = false;
      setState(() {});
      _laserRespawnTimer?.cancel();
      _laserRespawnTimer = Timer(const Duration(milliseconds: 500), () {
        laser.visible = true;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _startExitLongPress() {
    _exitLongPressTimer?.cancel();
    _exitLongPressTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showExitConfirm = true;
        });
      }
    });
  }

  void _cancelExitLongPress() {
    _exitLongPressTimer?.cancel();
  }

  void _dismissExitConfirm() {
    setState(() {
      _showExitConfirm = false;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_twoFingerGestureTriggered || _showExitConfirm) {
      return;
    }
    _activePointers += 1;
    if (_activePointers == 2) {
      _twoFingerTapCandidate = true;
      _twoFingerTimer?.cancel();
      _twoFingerTimer = Timer(const Duration(milliseconds: 220), () {
        _twoFingerTapCandidate = false;
      });
    } else if (_activePointers > 2) {
      _twoFingerTapCandidate = false;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_twoFingerGestureTriggered) {
      return;
    }
    if (_twoFingerTapCandidate && _activePointers == 2) {
      _triggerTwoFingerExit();
    }
    _activePointers = (_activePointers - 1).clamp(0, 2);
    if (_activePointers == 0) {
      _twoFingerTapCandidate = false;
      _twoFingerGestureTriggered = false;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers = 0;
    _twoFingerTapCandidate = false;
    _twoFingerGestureTriggered = false;
  }

  void _triggerTwoFingerExit() {
    _twoFingerGestureTriggered = true;
    setState(() {
      _showExitConfirm = true;
    });
  }

  void _handleToyTap(ToyType type) {
    _audioManager.playToySound(type);
    _revealSoundControl();
    switch (type) {
      case ToyType.yarn:
        _yarnTapCount += 1;
        _yarnResetTimer?.cancel();
        _yarnResetTimer = Timer(const Duration(seconds: 3), () => _yarnTapCount = 0);
        if (_yarnTapCount >= 3) {
          _yarnTapCount = 0;
          _yarnSpinTimer?.cancel();
          _yarnSpinTimer = Timer(const Duration(seconds: 2), () {});
        }
        break;
      case ToyType.mouse:
        _mouseTapCount += 1;
        _mouseResetTimer?.cancel();
        _mouseResetTimer = Timer(const Duration(seconds: 3), () => _mouseTapCount = 0);
        if (_mouseTapCount >= 2) {
          _mouseTapCount = 0;
          final mouse = _toys.firstWhere((toy) => toy.type == ToyType.mouse);
          mouse.visible = false;
          setState(() {});
          _mouseHideTimer?.cancel();
          _mouseHideTimer = Timer(const Duration(milliseconds: 900), () {
            mouse.visible = true;
            if (mounted) {
              setState(() {});
            }
          });
        }
        break;
      case ToyType.feather:
        _birdTapCount += 1;
        _birdResetTimer?.cancel();
        _birdResetTimer = Timer(const Duration(seconds: 4), () => _birdTapCount = 0);
        if (_birdTapCount >= 3) {
          _birdTapCount = 0;
          final bird = _toys.firstWhere((toy) => toy.type == ToyType.feather);
          bird.visible = false;
          setState(() {});
          _birdHideTimer?.cancel();
          _birdHideTimer = Timer(const Duration(seconds: 2), () {
            bird.visible = true;
            if (mounted) {
              setState(() {});
            }
          });
        }
        break;
      case ToyType.laser:
        _laserTapCount += 1;
        _laserResetTimer?.cancel();
        _laserResetTimer = Timer(const Duration(seconds: 3), () => _laserTapCount = 0);
        if (_laserTapCount >= 5) {
          _laserTapCount = 0;
          _laserBurstActive = true;
          _laserBurstTimer?.cancel();
          _laserBurstTimer = Timer(const Duration(seconds: 3), () {
            _laserBurstActive = false;
          });
        } else {
          final laser = _toys.firstWhere((toy) => toy.type == ToyType.laser);
          laser.visible = false;
          setState(() {});
          _laserRespawnTimer?.cancel();
          _laserRespawnTimer = Timer(const Duration(milliseconds: 500), () {
            laser.visible = true;
            if (mounted) {
              setState(() {});
            }
          });
        }
        break;
    }
  }

  void _revealSoundControl() {
    _soundControlTimer?.cancel();
    setState(() {
      _showSoundControl = true;
    });
    _soundControlTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showSoundControl = false;
        });
      }
    });
  }

  void _confirmExitLongPress() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _revealSoundControl(),
          onLongPressStart: (_) => _startExitLongPress(),
          onLongPressEnd: (_) => _cancelExitLongPress(),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFE6B3), Color(0xFFFFF8E6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              ..._buildToys(context),
              _buildSoundControl(context),
              if (_showExitConfirm) _buildExitOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundControl(BuildContext context) {
    if (!_showSoundControl) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 24,
      right: 24,
      bottom: 28,
      child: AnimatedOpacity(
        opacity: _showSoundControl ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E6).withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD9B38C), width: 1.5),
          ),
          child: Row(
            children: [
              const Text(
                '音量',
                style: TextStyle(
                  color: Color(0xFF7A4A21),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: const Color(0xFFFFA566),
                    inactiveTrackColor: const Color(0xFFFFE6B3),
                    thumbColor: const Color(0xFFFF9933),
                  ),
                  child: Slider(
                    value: _soundVolume,
                    onChanged: (value) {
                      setState(() {
                        _soundVolume = value;
                      });
                      _audioManager.setVolume(_soundVolume);
                      _revealSoundControl();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildToys(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortest = min(size.width, size.height);
    final diameter = shortest * 0.24;
    return _toys.where((toy) => toy.visible).map((toy) {
      return InteractiveToy(
        key: ValueKey(toy.type),
        config: toy,
        diameter: diameter,
        onTap: () => _handleToyTap(toy.type),
      );
    }).toList();
  }

  Widget _buildExitOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissExitConfirm,
        child: Container(
          color: const Color(0xFFFFE6B3).withOpacity(0.85),
          child: Center(
            child: _ExitConfirmButton(
              onConfirmed: _confirmExitLongPress,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitConfirmButton extends StatefulWidget {
  const _ExitConfirmButton({required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  State<_ExitConfirmButton> createState() => _ExitConfirmButtonState();
}

class _ExitConfirmButtonState extends State<_ExitConfirmButton> {
  Timer? _confirmTimer;
  bool _holding = false;

  void _startConfirmLongPress() {
    _confirmTimer?.cancel();
    _holding = true;
    _confirmTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _holding) {
        widget.onConfirmed();
      }
    });
  }

  void _cancelConfirmLongPress() {
    _confirmTimer?.cancel();
    _holding = false;
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startConfirmLongPress(),
      onLongPressEnd: (_) => _cancelConfirmLongPress(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: _holding ? const Color(0xFFFFD980) : const Color(0xFFFFF8E6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD9B38C), width: 2),
        ),
        child: const Text(
          '长按2秒退出',
          style: TextStyle(
            color: Color(0xFF7A4A21),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
