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


  // --- CUSTOM EMOTION PALETTE ---
  static const _loveColor = Color(0xFFFFC1CC);     // Soft Pink
  static const _angerColor = Color(0xFFFF4D4D);    // Intense Red
  static const _naughtyColor = Color(0xFFFF69B4);  // Hot Pink
  static const _winColor = Color(0xFFFFD700);      // Gold
  static const _sadColor = Color(0xFF6C7B95);      // Blue-Grey
  static const _laughColor = Color(0xFFFFFF4D);    // Bright Yellow



  // 1. FLASH CONTROLLER 
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  Color _flashColor = Colors.transparent;

  // 2. VIGNETTE CONTROLLER 
  late AnimationController _vignetteController;
  late Animation<double> _vignetteAnimation;

  // 3. PARTICLE CONTROLLER (Hearts & Anger)
  late AnimationController _particleController;
  final List<Widget> _activeParticles = [];

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

    // Setup Particles (Runs for 2s)
    _particleController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2)
    );
    
    _particleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Clear list only after animation finishes to prevent "glitch"
        if (mounted) {
          setState(() => _activeParticles.clear());
          _particleController.reset();
        }
      }
    });

    // LISTENER
// LISTENER
    _subscription = widget.effectStream.listen((effect) {
      // 1. LOVE (Soft Pink) – Warm, affectionate, romantic
if (effect == 'romance_pulse') {
  _triggerParticles(text: "🥰❤️");  // Smiling face with hearts + red heart
  _triggerFlash(_loveColor.withOpacity(0.2));
}

// 2. NAUGHTY / FLIRTY (Hot Pink/Magenta) – Sexy, playful, seductive
else if (effect == 'naughty_pulse') {
  _triggerParticles(text: "🥵🫦");  // Devilish smirk + kiss mark
  _triggerFlash(_naughtyColor.withOpacity(0.25));
}

// 3. ANGER / RAGE (Intense Red) – Aggressive, furious
else if (effect == 'anger_pulse') {
  _triggerParticles(text: "😡🖕");  // Cursing face + anger symbol
  _triggerFlash(_angerColor.withOpacity(0.4));
}

// 4. WIN / VICTORY (Gold) – Triumphant, successful
else if (effect == 'win_pulse') {
  _triggerParticles(text: "🏆✨");  // Trophy + sparkle
  _triggerFlash(_winColor.withOpacity(0.25));
}

// 5. SAD / HEARTBROKEN (Blue-Grey) – Melancholy, emotional
else if (effect == 'sad_pulse') {
  _triggerParticles(text: "💔😢");  // Broken heart + crying face
  _triggerFlash(_sadColor.withOpacity(0.3));
}

// 6. LAUGH / FUNNY (Bright Yellow) – Hilarious, joyful
else if (effect == 'laugh_pulse') {
  _triggerParticles(text: "😂🤣");  // Laughing tears + rolling on floor laughing
  _triggerFlash(_laughColor.withOpacity(0.2));
}
      else if (effect == 'shake') {
        _triggerFlash(Colors.redAccent.withOpacity(0.3)); 
      } 
      else if (effect == 'focus_vignette') {
        _triggerVignette();
      }
    });
  }

  // ... (Keep _triggerFlash and _triggerVignette as they were) ...
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

// --- UPDATED TRIGGER METHOD ---
  // Call this with an Icon OR Text. 
  void _triggerParticles({IconData? icon, String? text, Color? color}) {
    if (mounted) {
      _activeParticles.clear();
      final random = Random();
      
      for (int i = 0; i < 8; i++) {
        double size = 24 + random.nextInt(20).toDouble();
        
        // Determine what to render based on inputs
        Widget content;
        if (text != null) {
          // Render Text/Emoji
          content = Text(
            text, 
            style: TextStyle(fontSize: size) // No color needed for emojis usually
          );
        } else {
          // Render Icon (Default)
          content = Icon(
            icon ?? Icons.favorite, // Fallback
            color: color ?? Colors.pink, 
            size: size
          );
        }

        _activeParticles.add(
          Positioned(
            left: 50 + random.nextInt(250).toDouble(),
            bottom: 150,
            child: _FlyingParticle(
              controller: _particleController,
              delay: i * 0.1, 
              size: size,
              child: content, // <--- Pass the widget here
            ),
          )
        );
      }
      setState(() {}); 
      _particleController.forward(from: 0);
    }
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    _flashController.dispose();
    _vignetteController.dispose();
    _particleController.dispose();
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

          // 2. PARTICLE LAYER (Hearts/Fire)
          // We wrap this in a Stack to ensure Positioned widgets work
          Stack(
            clipBehavior: Clip.none, // Allow flying off-screen without error
            children: _activeParticles,
          ),

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


// --- GENERIC FLYING PARTICLE WIDGET (FIXED & ROBUST) ---
class _FlyingParticle extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;
  final Widget child; 

  const _FlyingParticle({
    required this.controller, 
    required this.delay, 
    required this.size,
    required this.child, 
  });

  @override
  Widget build(BuildContext context) {
    // SAFETY CHECK 1: Ensure delay is valid. 
    // If delay is >= 1.0, the animation effectively never starts or is instant.
    if (delay >= 1.0) return const SizedBox.shrink();

    // 1. DYNAMIC REMAINING TIME
    // Instead of assuming we have 0.4s left, we calculate exactly what's left.
    final double remainingTime = 1.0 - delay;

    // 2. FLY UP ANIMATION (Uses all remaining time)
    final Animation<double> flyUp = Tween<double>(begin: 0, end: 300).animate(
      CurvedAnimation(
        parent: controller,
        // Start at 'delay', fly until the end (1.0)
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
    );

    // 3. FADE OUT ANIMATION (Calculated relative to remaining time)
    // Old Crashy Logic: delay + 0.4
    // New Robust Logic: Start fading when 50% of the remaining life is done.
    final double fadeStart = delay + (remainingTime * 0.5);
    
    // Safety clamp: Ensure fadeStart is strictly less than 1.0
    // If floating point math makes it 1.0, nudge it back slightly.
    final double safeFadeStart = fadeStart >= 1.0 ? 0.99 : fadeStart;

    final Animation<double> fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(safeFadeStart, 1.0, curve: Curves.easeIn),
      ),
    );

    // 4. SCALE ANIMATION (Pop In)
    // Old Crashy Logic: delay + 0.2
    // New Robust Logic: Ensure end time never exceeds 1.0
    final double scaleEnd = (delay + 0.2).clamp(delay + 0.01, 1.0);

    final Animation<double> scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, scaleEnd, curve: Curves.elasticOut),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, childWidget) {
        // Optimization: Don't render invisible items
        if (controller.value < delay) return const SizedBox.shrink();

        return Transform.translate(
          offset: Offset(0, -flyUp.value), 
          child: Opacity(
            opacity: fade.value,
            child: Transform.scale(
              scale: scale.value,
              child: child, 
            ),
          ),
        );
      },
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

