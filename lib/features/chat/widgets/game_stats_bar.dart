import 'package:flutter/material.dart';

class GameStatsBar extends StatelessWidget {
  // Values from 0.0 to 1.0
  final double vibe; 
  final double trust;
  final double tension;
  final int turnCount; // "TURN 1/20" from your video

  const GameStatsBar({
    super.key,
    required this.vibe,
    required this.trust,
    required this.tension,
    this.turnCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9), // Dark overlay
        border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TURN COUNTER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TURN $turnCount/20",
                style: const TextStyle(
                  color: Colors.greenAccent, 
                  fontFamily: 'Courier', // Terminal font vibe
                  fontWeight: FontWeight.bold,
                  fontSize: 12
                ),
              ),
              const Text("LOCATION: COFFEE SHOP", style: TextStyle(color: Colors.cyan, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),

          // STAT BARS
          _buildStatRow("VIBE", vibe, Colors.cyanAccent),
          const SizedBox(height: 4),
          _buildStatRow("TRUST", trust, Colors.amberAccent),
          const SizedBox(height: 4),
          _buildStatRow("TENSION", tension, const Color(0xFFFF3366)), // Neon Pink/Red
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0), // Safety clamp
              backgroundColor: Colors.grey[900],
              color: color,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "${(value * 100).toInt()}", // Raw number like "45"
          style: TextStyle(color: color, fontSize: 10, fontFamily: 'Courier', fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}