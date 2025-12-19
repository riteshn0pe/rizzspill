import 'dart:async';
import 'package:flutter/material.dart';

class VisualFxOverlay extends StatefulWidget {
  final Stream<String> effectStream;

  const VisualFxOverlay({
    super.key, 
    required this.effectStream
  });

  @override
  State<VisualFxOverlay> createState() => _VisualFxOverlayState();
}

class _VisualFxOverlayState extends State<VisualFxOverlay> with TickerProviderStateMixin {
  // 1. FLASH CONTROLLER (For Pink/Red Pulses)
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  Color _flashColor = Colors.transparent;

  // 2. VIGNETTE CONTROLLER (For Focus/Intimacy)
  late AnimationController _vignetteController;
  late Animation<double> _vignetteAnimation;

  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    // Setup Flash (Fast pulse)
    _flashController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 3500)
    );
    _flashAnimation = CurvedAnimation(
      parent: _flashController, 
      curve: Curves.easeInOutQuad
    );

    // Setup Vignette (Slow darken)
    _vignetteController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 3)
    );
    _vignetteAnimation = CurvedAnimation(
      parent: _vignetteController, 
      curve: Curves.easeInOut
    );

    // Listen to the ActionQueueManager stream
    _subscription = widget.effectStream.listen((effect) {
      if (effect == 'romance_pulse') {
        _triggerFlash(Colors.pinkAccent.withOpacity(0.2));
      } 
      else if (effect == 'shake') {
        // Red flash accompanies the screen shake
        _triggerFlash(Colors.redAccent.withOpacity(0.3)); 
      } 
      else if (effect == 'focus_vignette') {
        _triggerVignette();
      }
    });
  }

  void _triggerFlash(Color color) {
    if (mounted) {
      setState(() => _flashColor = color);
      _flashController.forward(from: 0).then((_) => _flashController.reverse());
    }
  }

  void _triggerVignette() {
    if (mounted) {
      // Fade in, hold for 2 seconds, then fade out
      _vignetteController.forward(from: 0).then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _vignetteController.reverse();
        });
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _flashController.dispose();
    _vignetteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer ensures clicks pass through to the ChatBubble below
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: FLASH OVERLAY (Solid Color Pulse)
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Container(
                color: _flashColor.withOpacity(_flashAnimation.value * _flashColor.opacity),
              );
            },
          ),

          // LAYER 2: VIGNETTE OVERLAY (Radial Gradient)
          AnimatedBuilder(
            animation: _vignetteAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _vignetteAnimation.value,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.2, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}