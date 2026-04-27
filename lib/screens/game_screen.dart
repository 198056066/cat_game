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
  bool _showExitConfirm = false;
  double _soundVolume = 0.6;
  bool _showSoundControl = false;
  Timer? _soundControlTimer;
  int _activePointers = 0;
  bool _twoFingerTapCandidate = false;
  bool _twoFingerGestureTriggered = false;
  Timer? _twoFingerTimer;

  @override
  void initState() {
    super.initState();
    _toys.addAll([
      ToyConfig(
        type: ToyType.yarn,
        baseColor: const Color(0xFFF2A24B),
        accentColor: Colors.white,
        startPosition: const Offset(0.2, 0.35),
        movement: const Offset(0.22, 0.08),
        periodSeconds: 6.5,
      ),
      ToyConfig(
        type: ToyType.mouse,
        baseColor: const Color(0xFFB8702D),
        accentColor: const Color(0xFFFFE6BF),
        startPosition: const Offset(0.55, 0.55),
        movement: const Offset(0.18, -0.12),
        periodSeconds: 7.8,
      ),
      ToyConfig(
        type: ToyType.feather,
        baseColor: const Color(0xFFFAD98A),
        accentColor: const Color(0xFFD38A45),
        startPosition: const Offset(0.35, 0.68),
        movement: const Offset(-0.14, 0.16),
        periodSeconds: 8.6,
      ),
      ToyConfig(
        type: ToyType.laser,
        baseColor: const Color(0xFFFFD38A),
        accentColor: const Color(0xFF7B3E18),
        startPosition: const Offset(0.65, 0.25),
        movement: const Offset(0.12, 0.14),
        periodSeconds: 5.5,
      ),
    ]);
    _laserTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      final laser = _toys.firstWhere((toy) => toy.type == ToyType.laser);
      setState(() {
        laser.visible = _random.nextBool();
      });
    });
    _audioManager.initialize();
    _audioManager.setVolume(_soundVolume);
    _audioManager.warmUp();
  }

  @override
  void dispose() {
    _laserTimer?.cancel();
    _exitLongPressTimer?.cancel();
    _soundControlTimer?.cancel();
    _twoFingerTimer?.cancel();
    _audioManager.dispose();
    super.dispose();
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
                      colors: [Color(0xFFFFF1D6), Color(0xFFF8E3B6)],
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
            color: const Color(0xFFF7E2BA).withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD2A46A), width: 1.5),
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
                    activeTrackColor: const Color(0xFFE5A85A),
                    inactiveTrackColor: const Color(0xFFE7D1A7),
                    thumbColor: const Color(0xFFE08A3C),
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
    final diameter = shortest * 0.16;
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
          color: const Color(0xFFF4D9B3).withOpacity(0.85),
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
          color: _holding ? const Color(0xFFF0C989) : const Color(0xFFF7E2BA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD29C5A), width: 2),
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
