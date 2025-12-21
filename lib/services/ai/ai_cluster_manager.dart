import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class WorkerNode {
  final String id;
  final String key;
  final String provider; 
  final int rpmLimit;
  final int priority; // FIX: Added this field

  WorkerNode({
    required this.id, 
    required this.key, 
    required this.provider, 
    required this.rpmLimit,
    required this.priority, // FIX: Required in constructor
  });
}

class AiClusterManager {
  static final AiClusterManager _instance = AiClusterManager._internal();
  factory AiClusterManager() => _instance;
  AiClusterManager._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;
  final _db = FirebaseDatabase.instance.ref("api_cluster_status");
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      print("🚀 Attempting AI Cluster Connection...");
      await _remoteConfig.fetchAndActivate();
      
      _isInitialized = true;
      print("AI Cluster Connected Successfully");
    } catch (e) {
      print("AI Cluster Connection Failed: $e");
      _isInitialized = true; 
    }
  }

  Future<WorkerNode> getBestWorker() async {
    if (!_isInitialized) await init();

    String jsonString = "";

    try {
      jsonString = _remoteConfig.getString("ai_cluster_config");
    } catch (e) {
      print("⚠️ Remote Config Broken (Using Fallback): $e");
      jsonString = ""; 
    }

    if (jsonString.isEmpty) {
      print("🚨 Using Local Groq Fallback.");
      jsonString = '''
      {
        "workers": [
          {
            "id": "groq_primary",
            "key": "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", 
            "provider": "groq", 
            "rpm": 30,
            "priority": 1
          }
        ]
      }
      ''';
    }
    
    final data = jsonDecode(jsonString);
    final List<dynamic> rawList = data['workers'];

    // 1. Convert JSON to WorkerNode Objects
    List<WorkerNode> allWorkers = rawList.map((w) {
      return WorkerNode(
        id: w['id'],
        key: w['key'],
        provider: w['provider'] ?? 'gemini',
        rpmLimit: w['rpm'] ?? w['rpmLimit'] ?? 30,
        priority: w['priority'] ?? 99, // Default to low priority if missing
      );
    }).toList();

    // 2. Fetch Usage Stats from Realtime DB
    DataSnapshot? snapshot;
    try {
      final event = await _db.once(); 
      snapshot = event.snapshot;
    } catch (e) {
      print("⚠️ DB Error (Ignoring): $e");
    }

    // 3. Filter & Sort Logic (The "Brain")
    // We create a list of "Candidates" (workers that are not rate limited)
    List<Map<String, dynamic>> candidates = [];

    for (var node in allWorkers) {
      int currentUsage = 0;
      int lastReset = 0;

      if (snapshot != null && snapshot.child(node.id).exists) {
        final stats = snapshot.child(node.id).value as Map;
        currentUsage = stats['usage'] ?? 0;
        lastReset = stats['reset_time'] ?? 0;

        // Reset local counter if >1 min has passed
        if (DateTime.now().millisecondsSinceEpoch - lastReset > 60000) {
          currentUsage = 0;
        }
      }

      // Only consider if below RPM limit
      if (currentUsage < node.rpmLimit) {
        candidates.add({
          'node': node,
          'usage': currentUsage,
        });
      }
    }

    if (candidates.isEmpty) {
      // Emergency: Return the first defined worker if everything is busy
      return allWorkers[0]; 
    }

    // 4. SORTING (The Priority Fix)
    // Sort logic:
    //  Primary: Priority (Lower is better, e.g. 1 before 2)
    //  Secondary: Usage (Lower is better, load balancing)
    candidates.sort((a, b) {
      final nodeA = a['node'] as WorkerNode;
      final nodeB = b['node'] as WorkerNode;
      final usageA = a['usage'] as int;
      final usageB = b['usage'] as int;

      if (nodeA.priority != nodeB.priority) {
        return nodeA.priority.compareTo(nodeB.priority); // 1 comes before 2
      }
      return usageA.compareTo(usageB); // Least used comes first
    });

    // Return the winner
    return candidates.first['node'] as WorkerNode;
  }

  Future<void> incrementUsage(String workerId) async {
    try {
      final ref = _db.child(workerId);
      await ref.runTransaction((Object? data) { 
        Map<String, dynamic> stats;
        
        if (data == null) {
          stats = {'usage': 0, 'reset_time': DateTime.now().millisecondsSinceEpoch};
        } else {
          final Map<dynamic, dynamic> rawMap = data as Map<dynamic, dynamic>;
          stats = Map<String, dynamic>.from(rawMap);
        }

        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - (stats['reset_time'] as int) > 60000) {
          stats['usage'] = 1;
          stats['reset_time'] = now;
        } else {
          stats['usage'] = (stats['usage'] as int) + 1;
        }
        return Transaction.success(stats);
      });
    } catch (e) {
      print("⚠️ Usage Update Failed: $e");
    }
  }
}

// import 'dart:async';
// import 'dart:convert';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_remote_config/firebase_remote_config.dart';

// class WorkerNode {
//   final String id;
//   final String key;
//   final String provider; 
//   final int rpmLimit;

//   WorkerNode({
//     required this.id, 
//     required this.key, 
//     required this.provider, 
//     required this.rpmLimit
//   });
// }

// class AiClusterManager {
//   static final AiClusterManager _instance = AiClusterManager._internal();
//   factory AiClusterManager() => _instance;
//   AiClusterManager._internal();

//   final _remoteConfig = FirebaseRemoteConfig.instance;
//   final _db = FirebaseDatabase.instance.ref("api_cluster_status");
//   bool _isInitialized = false;

// Future<void> init() async {
//     if (_isInitialized) return;
//     try {
//       // Keep your preferred 10-second limit
//       await _remoteConfig.setConfigSettings(RemoteConfigSettings(
//         fetchTimeout: const Duration(seconds: 10),
//         minimumFetchInterval: const Duration(hours: 1),
//       ));
      
//       print("🚀 Attempting AI Cluster Connection...");
      
//       // Standard fetch without the 3-second force-stop
//       await _remoteConfig.fetchAndActivate();
      
//       _isInitialized = true;
//       print("AI Cluster Connected Successfully");
//     } catch (e) {
//       print("AI Cluster Connection Failed: $e");
//       // Mark as initialized so the app can at least move to Fallback (Groq)
//       _isInitialized = true; 
//     }
//   }

//   Future<WorkerNode> getBestWorker() async {
//     // 1. Ensure Init (with internal catch)
//     if (!_isInitialized) await init();

//     String jsonString = "";

//     // 2. SAFE CONFIG FETCH (The Fix)
//     // We wrap this in try/catch because if init() failed, this line WILL crash.
//     try {
//       jsonString = _remoteConfig.getString("ai_cluster_config");
//     } catch (e) {
//       print("⚠️ Remote Config Broken (Using Fallback): $e");
//       jsonString = ""; // Force empty so the fallback block below triggers
//     }

//     // 3. FALLBACK LOGIC (Groq)
//     if (jsonString.isEmpty) {
//       print("🚨 Using Local Groq Fallback.");
//       jsonString = '''
//       {
//         "workers": [
//           {
//             "id": "groq_primary",
//             "key": "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", 
//             "provider": "groq", 
//             "rpm": 30
//           }
//         ]
//       }
//       ''';
//     }
    
//     // 4. Parse Data
//     final data = jsonDecode(jsonString);
//     final List<dynamic> workerList = data['workers'];

//     // 5. FAIL-SAFE DB CHECK
//     DataSnapshot? snapshot;
//     try {
//       // If DB is misconfigured, this throws. We catch it and ignore.
//       final event = await _db.once(); 
//       snapshot = event.snapshot;
//     } catch (e) {
//       print("⚠️ DB Error (Ignoring): $e");
//     }

//     WorkerNode? bestWorker;
//     int lowestUsage = 9999;

//     for (var w in workerList) {
//       final workerId = w['id'];
//       // Handle both naming conventions just in case
//       final limit = w['rpm'] ?? w['rpmLimit'] ?? 30; 
//       final provider = w['provider'] ?? 'gemini'; 

//       int currentUsage = 0;
//       int lastReset = 0;

//       if (snapshot != null && snapshot.child(workerId).exists) {
//         final stats = snapshot.child(workerId).value as Map;
//         currentUsage = stats['usage'] ?? 0;
//         lastReset = stats['reset_time'] ?? 0;

//         if (DateTime.now().millisecondsSinceEpoch - lastReset > 60000) {
//           currentUsage = 0;
//         }
//       }

//       if (currentUsage < limit) {
//         if (currentUsage < lowestUsage) {
//           lowestUsage = currentUsage;
//           bestWorker = WorkerNode(
//             id: workerId,
//             key: w['key'],
//             provider: provider,
//             rpmLimit: limit,
//           );
//         }
//       }
//     }

//     return bestWorker ?? WorkerNode(
//       id: workerList[0]['id'],
//       key: workerList[0]['key'],
//       provider: workerList[0]['provider'] ?? 'groq',
//       rpmLimit: 30,
//     );
//   }

// Future<void> incrementUsage(String workerId) async {
//     try {
//       final ref = _db.child(workerId);
//       await ref.runTransaction((Object? data) { // Change to Object? for strict typing
//         Map<String, dynamic> stats;
        
//         if (data == null) {
//           stats = {'usage': 0, 'reset_time': DateTime.now().millisecondsSinceEpoch};
//         } else {
//           // Standardize the map conversion for Android/iOS
//           final Map<dynamic, dynamic> rawMap = data as Map<dynamic, dynamic>;
//           stats = Map<String, dynamic>.from(rawMap);
//         }

//         final now = DateTime.now().millisecondsSinceEpoch;

//         if (now - (stats['reset_time'] as int) > 60000) {
//           stats['usage'] = 1;
//           stats['reset_time'] = now;
//         } else {
//           stats['usage'] = (stats['usage'] as int) + 1;
//         }
//         return Transaction.success(stats);
//       });
//     } catch (e) {
//       print("⚠️ Usage Update Failed: $e");
//     }
//   }
// }
