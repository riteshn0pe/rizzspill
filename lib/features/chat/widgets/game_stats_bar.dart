// game_stats_bar.dart
import 'package:flutter/material.dart';

class _StatDefinition {
  final String label;
  final Color color;
  final String jsonKey; 
  const _StatDefinition({required this.label, required this.color, required this.jsonKey});
}

class GameStatsBar extends StatelessWidget {
  final String roomType; 
  final Map<String, dynamic> currentStats; // <--- The missing parameter
  final int turnCount;

  const GameStatsBar({
    super.key,
    required this.roomType,
    required this.currentStats,
    this.turnCount = 1,
  });

  // CONFIGURATION REGISTRY
  static final Map<String, List<_StatDefinition>> _roomConfigs = {
    'dating': [
      const _StatDefinition(label: "CHEMISTRY", color: Color(0xFFFF69B4), jsonKey: "chemistry"),
      const _StatDefinition(label: "TRUST", color: Colors.amberAccent, jsonKey: "trust"),
      const _StatDefinition(label: "TENSION", color: Color(0xFF6A0DAD), jsonKey: "tension"),
    ],
    'debate': [
      const _StatDefinition(label: "YOUR EDGE", color: Colors.redAccent, jsonKey: "your_edge"),
      const _StatDefinition(label: "THEIR EDGE", color: Colors.lightBlueAccent, jsonKey: "their_edge"),
    ],
    'confession': [
      const _StatDefinition(label: "VULNERABILITY", color: Colors.tealAccent, jsonKey: "vulnerability"),
      const _StatDefinition(label: "CONNECTION", color: Color(0xFFD8BFD8), jsonKey: "connection"),
      const _StatDefinition(label: "RECIPROCITY", color: Color(0xFFFFBF00), jsonKey: "reciprocity"),
    ],
    'random': [
      const _StatDefinition(label: "CHAOS LVL", color: Colors.greenAccent, jsonKey: "chaos"),
      const _StatDefinition(label: "LAUGH MTR", color: Colors.yellowAccent, jsonKey: "laugh"),
      const _StatDefinition(label: "WEIRDNESS", color: Color(0xFF9400D3), jsonKey: "weirdness"),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final activeConfig = _roomConfigs[roomType.toLowerCase()] ?? _roomConfigs['dating']!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TURN $turnCount/20", style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12)),
              Text("ROOM: ${roomType.toUpperCase()}", style: const TextStyle(color: Colors.cyan, fontSize: 10, fontFamily: 'Courier')),
            ],
          ),
          const SizedBox(height: 8),
          ...activeConfig.map((statDef) {
            final rawValue = currentStats[statDef.jsonKey];
            final double value = (rawValue is num) ? rawValue.toDouble() : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: _buildStatRow(statDef.label, value, statDef.color),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Courier'), overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), backgroundColor: Colors.grey[900], color: color, minHeight: 6),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 25,
          child: Text("${(value * 100).toInt()}", style: TextStyle(color: color, fontSize: 10, fontFamily: 'Courier', fontWeight: FontWeight.bold), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}


// import 'package:flutter/material.dart';

// class GameStatsBar extends StatelessWidget {
//   // Values from 0.0 to 1.0
//   final double vibe; 
//   final double trust;
//   final double tension;
//   final int turnCount; // "TURN 1/20" from your video
//   final Map<String, dynamic> currentStats; // <--- The missing parameter

//   const GameStatsBar({
//     super.key,
//     required this.vibe,
//     required this.trust,
//     required this.tension,
//     this.turnCount = 1, required this.currentStats,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.9), // Dark overlay
//         border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // TURN COUNTER
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 "TURN $turnCount/20",
//                 style: const TextStyle(
//                   color: Colors.greenAccent, 
//                   fontFamily: 'Courier', // Terminal font vibe
//                   fontWeight: FontWeight.bold,
//                   fontSize: 12
//                 ),
//               ),
//               const Text("LOCATION: COFFEE SHOP", style: TextStyle(color: Colors.cyan, fontSize: 10)),
//             ],
//           ),
//           const SizedBox(height: 8),

//           // STAT BARS
//           _buildStatRow("VIBE", vibe, Colors.cyanAccent),
//           const SizedBox(height: 4),
//           _buildStatRow("TRUST", trust, Colors.amberAccent),
//           const SizedBox(height: 4),
//           _buildStatRow("TENSION", tension, const Color(0xFFFF3366)), // Neon Pink/Red
//         ],
//       ),
//     );
//   }

//   Widget _buildStatRow(String label, double value, Color color) {
//     return Row(
//       children: [
//         SizedBox(
//           width: 60,
//           child: Text(
//             label,
//             style: TextStyle(
//               color: color,
//               fontSize: 10,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 1.5,
//             ),
//           ),
//         ),
//         Expanded(
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(2),
//             child: LinearProgressIndicator(
//               value: value.clamp(0.0, 1.0), // Safety clamp
//               backgroundColor: Colors.grey[900],
//               color: color,
//               minHeight: 6,
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//         Text(
//           "${(value * 100).toInt()}", // Raw number like "45"
//           style: TextStyle(color: color, fontSize: 10, fontFamily: 'Courier', fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }
// }