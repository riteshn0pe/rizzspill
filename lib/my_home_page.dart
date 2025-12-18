import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    // Floating animation for that "modern platform" vibe
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Cyberpunk background
      body: Stack(
        children: [
          // Background Glow Decoration
          Positioned(
            top: -100,
            right: -50,
            child: _buildBackgroundGlow(Colors.pinkAccent.withOpacity(0.15)),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: _buildBackgroundGlow(Colors.greenAccent.withOpacity(0.1)),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  const Text(
                    "CHOOSE YOUR ARENA",
                    style: TextStyle(
                      color: Colors.grey,
                      letterSpacing: 3,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // THE FLOATING CATEGORIES
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildCategoryCard(
                          title: "VIRTUAL DATE",
                          subtitle: "Master the art of romance",
                          icon: FontAwesomeIcons.heart,
                          color: Colors.pinkAccent,
                          delay: 0,
                        ),
                        _buildCategoryCard(
                          title: "ELITE DEBATE",
                          subtitle: "Win with logic & pressure",
                          icon: FontAwesomeIcons.scaleBalanced,
                          color: Colors.blueAccent,
                          delay: 0.2,
                        ),
                        _buildCategoryCard(
                          title: "RANDOM VENT",
                          subtitle: "Talk to the void",
                          icon: FontAwesomeIcons.ghost,
                          color: Colors.greenAccent,
                          delay: 0.4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "WELCOME BACK,",
              style: TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontSize: 14),
            ),
            Text(
              "OPERATOR", // You can later pull user.displayName here
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        )
      ],
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double delay,
  }) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        // Subtle floating movement logic
        double offset = (delay * 10) + (_floatController.value * 10);
        return Transform.translate(
          offset: Offset(0, offset),
          child: GestureDetector(
            onTap: () {
              // For now, leads to the matching screen
              Navigator.pushNamed(context, '/matching');
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey[700], size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundGlow(Color color) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 50,
          )
        ],
      ),
    );
  }
}