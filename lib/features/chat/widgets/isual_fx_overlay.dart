import 'dart:async';
import 'dart:math';
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
  // 1. FLASH CONTROLLER (Red/Green/Pink Solid)
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  Color _flashColor = Colors.transparent;

  // 2. VIGNETTE CONTROLLER (Darken)
  late AnimationController _vignetteController;
  late Animation<double> _vignetteAnimation;

  // 3. HEARTS CONTROLLER (Flying Icons)
  late AnimationController _heartsController;
  final List<Widget> _activeHearts = [];

  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    // Setup Flash
    _flashController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500)
    );
    _flashAnimation = CurvedAnimation(parent: _flashController, curve: Curves.easeInOut);

    // Setup Vignette
    _vignetteController = AnimationController(
      vsync: this, duration: const Duration(seconds: 3)
    );
    _vignetteAnimation = CurvedAnimation(parent: _vignetteController, curve: Curves.easeIn);

    // Setup Hearts (Runs for 2s)
    _heartsController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2)
    );
    
    _heartsController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _activeHearts.clear());
        _heartsController.reset();
      }
    });

    // LISTENER
    _subscription = widget.effectStream.listen((effect) {
      if (effect == 'romance_hearts') {
        _triggerHearts();
        _triggerFlash(Colors.pinkAccent.withOpacity(0.15));
      } 
      else if (effect == 'anger_pulse') {
        _triggerFlash(Colors.red.withOpacity(0.4));
      } 
      else if (effect == 'win_glow') {
        _triggerFlash(Colors.greenAccent.withOpacity(0.2));
      }
      else if (effect == 'shake') {
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
      _vignetteController.forward(from: 0).then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _vignetteController.reverse();
        });
      });
    }
  }

  void _triggerHearts() {
    if (mounted) {
      // Generate 5-8 random hearts
      _activeHearts.clear();
      final random = Random();
      for (int i = 0; i < 8; i++) {
        _activeHearts.add(
          Positioned(
            left: 50 + random.nextInt(300).toDouble(), // Random X
            bottom: 100, // Start near chat input
            child: _FlyingHeart(
              controller: _heartsController,
              delay: i * 0.1, // Staggered start
              size: 20 + random.nextInt(20).toDouble(),
            ),
          )
        );
      }
      setState(() {}); // Rebuild to show hearts
      _heartsController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _flashController.dispose();
    _vignetteController.dispose();
    _heartsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FLASH LAYER
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Container(
                color: _flashColor.withOpacity(_flashAnimation.value * _flashColor.opacity),
              );
            },
          ),

          // 2. HEARTS LAYER (Only visible when active)
          ..._activeHearts,

          // 3. VIGNETTE LAYER
          AnimatedBuilder(
            animation: _vignetteAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _vignetteAnimation.value,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.3, 1.0],
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

// Helper Widget for a single flying heart
class _FlyingHeart extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;

  const _FlyingHeart({required this.controller, required this.delay, required this.size});

  @override
  Widget build(BuildContext context) {
    // Each heart animates from 0 to 1 based on controller + delay
    final Animation<double> flyUp = Tween<double>(begin: 0, end: 400).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
    );

    final Animation<double> fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay + 0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Don't draw if animation hasn't started for this particle
        if (controller.value < delay) return const SizedBox.shrink();

        return Transform.translate(
          offset: Offset(0, -flyUp.value), // Move Up
          child: Opacity(
            opacity: fade.value,
            child: Icon(Icons.favorite, color: Colors.pinkAccent, size: size),
          ),
        );
      },
    );
  }
}
// import 'dart:async';
// import 'package:flutter/material.dart';

// class VisualFxOverlay extends StatefulWidget {
//   final Stream<String> effectStream;

//   const VisualFxOverlay({
//     super.key, 
//     required this.effectStream
//   });

//   @override
//   State<VisualFxOverlay> createState() => _VisualFxOverlayState();
// }

// class _VisualFxOverlayState extends State<VisualFxOverlay> with TickerProviderStateMixin {
//   // 1. FLASH CONTROLLER (For Pink/Red Pulses)
//   late AnimationController _flashController;
//   late Animation<double> _flashAnimation;
//   Color _flashColor = Colors.transparent;

//   // 2. VIGNETTE CONTROLLER (For Focus/Intimacy)
//   late AnimationController _vignetteController;
//   late Animation<double> _vignetteAnimation;

//   StreamSubscription? _subscription;

//   @override
//   void initState() {
//     super.initState();

//     // Setup Flash (Fast pulse)
//     _flashController = AnimationController(
//       vsync: this, 
//       duration: const Duration(milliseconds: 3500)
//     );
//     _flashAnimation = CurvedAnimation(
//       parent: _flashController, 
//       curve: Curves.easeInOutQuad
//     );

//     // Setup Vignette (Slow darken)
//     _vignetteController = AnimationController(
//       vsync: this, 
//       duration: const Duration(seconds: 3)
//     );
//     _vignetteAnimation = CurvedAnimation(
//       parent: _vignetteController, 
//       curve: Curves.easeInOut
//     );

//     // Listen to the ActionQueueManager stream
//     _subscription = widget.effectStream.listen((effect) {
//       if (effect == 'romance_pulse') {
//         _triggerFlash(Colors.pinkAccent.withOpacity(0.2));
//       } 
//       else if (effect == 'shake') {
//         // Red flash accompanies the screen shake
//         _triggerFlash(Colors.redAccent.withOpacity(0.3)); 
//       } 
//       else if (effect == 'focus_vignette') {
//         _triggerVignette();
//       }
//     });
//   }

//   void _triggerFlash(Color color) {
//     if (mounted) {
//       setState(() => _flashColor = color);
//       _flashController.forward(from: 0).then((_) => _flashController.reverse());
//     }
//   }

//   void _triggerVignette() {
//     if (mounted) {
//       // Fade in, hold for 2 seconds, then fade out
//       _vignetteController.forward(from: 0).then((_) {
//         Future.delayed(const Duration(seconds: 2), () {
//           if (mounted) _vignetteController.reverse();
//         });
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _subscription?.cancel();
//     _flashController.dispose();
//     _vignetteController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // IgnorePointer ensures clicks pass through to the ChatBubble below
//     return IgnorePointer(
//       child: Stack(
//         fit: StackFit.expand,
//         children: [
//           // LAYER 1: FLASH OVERLAY (Solid Color Pulse)
//           AnimatedBuilder(
//             animation: _flashAnimation,
//             builder: (context, child) {
//               return Container(
//                 color: _flashColor.withOpacity(_flashAnimation.value * _flashColor.opacity),
//               );
//             },
//           ),

//           // LAYER 2: VIGNETTE OVERLAY (Radial Gradient)
//           AnimatedBuilder(
//             animation: _vignetteAnimation,
//             builder: (context, child) {
//               return Opacity(
//                 opacity: _vignetteAnimation.value,
//                 child: Container(
//                   decoration: const BoxDecoration(
//                     gradient: RadialGradient(
//                       center: Alignment.center,
//                       radius: 0.8,
//                       colors: [Colors.transparent, Colors.black],
//                       stops: [0.2, 1.0],
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }