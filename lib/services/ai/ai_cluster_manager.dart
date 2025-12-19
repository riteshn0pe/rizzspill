import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class WorkerNode {
  final String id;
  final String key;
  final String provider; 
  final int rpmLimit;

  WorkerNode({
    required this.id, 
    required this.key, 
    required this.provider, 
    required this.rpmLimit
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
      // Keep your preferred 10-second limit
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      print("🚀 Attempting AI Cluster Connection...");
      
      // Standard fetch without the 3-second force-stop
      await _remoteConfig.fetchAndActivate();
      
      _isInitialized = true;
      print("AI Cluster Connected Successfully");
    } catch (e) {
      print("AI Cluster Connection Failed: $e");
      // Mark as initialized so the app can at least move to Fallback (Groq)
      _isInitialized = true; 
    }
  }

  Future<WorkerNode> getBestWorker() async {
    // 1. Ensure Init (with internal catch)
    if (!_isInitialized) await init();

    String jsonString = "";

    // 2. SAFE CONFIG FETCH (The Fix)
    // We wrap this in try/catch because if init() failed, this line WILL crash.
    try {
      jsonString = _remoteConfig.getString("ai_cluster_config");
    } catch (e) {
      print("⚠️ Remote Config Broken (Using Fallback): $e");
      jsonString = ""; // Force empty so the fallback block below triggers
    }

    // 3. FALLBACK LOGIC (Groq)
    if (jsonString.isEmpty) {
      print("🚨 Using Local Groq Fallback.");
      jsonString = '''
      {
        "workers": [
          {
            "id": "groq_primary",
            "key": "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", 
            "provider": "groq", 
            "rpm": 30
          }
        ]
      }
      ''';
    }
    
    // 4. Parse Data
    final data = jsonDecode(jsonString);
    final List<dynamic> workerList = data['workers'];

    // 5. FAIL-SAFE DB CHECK
    DataSnapshot? snapshot;
    try {
      // If DB is misconfigured, this throws. We catch it and ignore.
      final event = await _db.once(); 
      snapshot = event.snapshot;
    } catch (e) {
      print("⚠️ DB Error (Ignoring): $e");
    }

    WorkerNode? bestWorker;
    int lowestUsage = 9999;

    for (var w in workerList) {
      final workerId = w['id'];
      // Handle both naming conventions just in case
      final limit = w['rpm'] ?? w['rpmLimit'] ?? 30; 
      final provider = w['provider'] ?? 'gemini'; 

      int currentUsage = 0;
      int lastReset = 0;

      if (snapshot != null && snapshot.child(workerId).exists) {
        final stats = snapshot.child(workerId).value as Map;
        currentUsage = stats['usage'] ?? 0;
        lastReset = stats['reset_time'] ?? 0;

        if (DateTime.now().millisecondsSinceEpoch - lastReset > 60000) {
          currentUsage = 0;
        }
      }

      if (currentUsage < limit) {
        if (currentUsage < lowestUsage) {
          lowestUsage = currentUsage;
          bestWorker = WorkerNode(
            id: workerId,
            key: w['key'],
            provider: provider,
            rpmLimit: limit,
          );
        }
      }
    }

    return bestWorker ?? WorkerNode(
      id: workerList[0]['id'],
      key: workerList[0]['key'],
      provider: workerList[0]['provider'] ?? 'groq',
      rpmLimit: 30,
    );
  }

  Future<void> incrementUsage(String workerId) async {
    // Wrap this too, just to be safe
    try {
      final ref = _db.child(workerId);
      await ref.runTransaction((data) {
        Map<String, dynamic> stats = (data as Map?) != null
            ? Map<String, dynamic>.from(data as Map)
            : {'usage': 0, 'reset_time': DateTime.now().millisecondsSinceEpoch};

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

// import 'dart:convert';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_remote_config/firebase_remote_config.dart';

// class WorkerNode {
//   final String id;
//   final String key;
//   final String provider; // NEW: Distinguishes between gemini, groq, etc.
//   final int rpmLimit;

//   WorkerNode({
//     required this.id, 
//     required this.key, 
//     required this.provider, 
//     required this.rpmLimit
//   });
// }

// class AiClusterManager {
//   // Singleton Pattern
//   static final AiClusterManager _instance = AiClusterManager._internal();
//   factory AiClusterManager() => _instance;
//   AiClusterManager._internal();

//   // Members
//   final _remoteConfig = FirebaseRemoteConfig.instance;
//   final _db = FirebaseDatabase.instance.ref("api_cluster_status");
//   bool _isInitialized = false;

//   Future<void> init() async {
//     if (_isInitialized) return;
//     try {
//       await _remoteConfig.setConfigSettings(RemoteConfigSettings(
//         fetchTimeout: const Duration(seconds: 30),
//         minimumFetchInterval: const Duration(hours: 1),
//       ));
//       await _remoteConfig.fetchAndActivate();
//       _isInitialized = true;
//     } catch (e) {
//       print("AI Cluster Init Error: $e");
//     }
//   }

//   // --- UPDATED: Healthiest Worker Logic with Provider Support ---
// Future<WorkerNode> getBestWorker() async {
//     // 1. Ensure Init
//     if (!_isInitialized) await init();

//     // 2. Get Config (with Safety Check)
//     var jsonString = _remoteConfig.getString("ai_cluster_config");

//     // --- SAFETY BLOCK: If Firebase is empty/0% rollout, use this! ---
//     if (jsonString.isEmpty) {
//       print("🚨 ALERT: Remote Config is empty! Using Hardcoded Fallback.");
//       jsonString = '''
//       {
//         "workers": [
//           {
//             id: "groq_primary",
//       key: "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", 
//       provider: "groq", 
//       rpmLimit: 30
//           }
//         ]
//       }
//       ''';
//     }
//     // -------------------------------------------------------------
    
//     final data = jsonDecode(jsonString);
//     final List<dynamic> workerList = data['workers'];

//     // 3. FAIL-SAFE DB CHECK
//     // We try to get traffic stats. If it fails (e.g. bad URL), we just skip it.
//     DataSnapshot? snapshot;
//     try {
//       final event = await _db.once(); // Using once() is often safer for single reads
//       snapshot = event.snapshot;
//     } catch (e) {
//       print("⚠️ Realtime DB Error (Ignoring): $e");
//       // Proceed with snapshot as null
//     }

//     WorkerNode? bestWorker;
//     int lowestUsage = 9999;

//     for (var w in workerList) {
//       final workerId = w['id'];
//       final limit = w['rpm'];
//       final provider = w['provider'] ?? 'gemini'; 

//       int currentUsage = 0;
//       int lastReset = 0;

//       // Only check usage if DB snapshot exists
//       if (snapshot != null && snapshot.child(workerId).exists) {
//         final stats = snapshot.child(workerId).value as Map;
//         currentUsage = stats['usage'] ?? 0;
//         lastReset = stats['reset_time'] ?? 0;

//         // Lazy Reset Logic: If >60s passed, usage is effectively 0
//         if (DateTime.now().millisecondsSinceEpoch - lastReset > 60000) {
//           currentUsage = 0;
//         }
//       }

//       // Selection: Pick the one with the lowest usage
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

//     // Failover: Default to the first worker if selection finds nothing
//     return bestWorker ?? WorkerNode(
//       id: workerList[0]['id'],
//       key: workerList[0]['key'],
//       provider: workerList[0]['provider'] ?? 'gemini',
//       rpmLimit: workerList[0]['rpm'] ?? 15,
//     );
//   }



//   // Future<WorkerNode> getBestWorker() async {
//   //   if (!_isInitialized) await init();

//   //   var jsonString = _remoteConfig.getString("ai_cluster_config");
//   //   // --- SAFETY BLOCK: If Firebase is empty/0% rollout, use this! ---
//   //   if (jsonString.isEmpty) {
//   //     print("🚨 ALERT: Remote Config is empty! Using Hardcoded Fallback.");
//   //     // PASTE YOUR REAL KEY HERE TO STOP THE CRASH
//   //     jsonString = '''
//   //     {
//   //       "workers": [
//   //         {
//   //           "id": "fallback_gemini",
//   //           "key": "AIzaSyCLTJz9E7--bupbGUemZlz3-3SiwauxE00", 
//   //           "provider": "gemini",
//   //           "rpm": 15
//   //         }
//   //       ]
//   //     }
//   //     ''';
//   //   }
//   //   // -------------------------------------------------------------
//   //   if (jsonString.isEmpty) throw Exception("AI Config not found in Remote Config.");
    
//   //   final data = jsonDecode(jsonString);
//   //   final List<dynamic> workerList = data['workers'];

//   //   // Fetch current global traffic status from Realtime DB
//   //   final snapshot = await _db.get();

//   //   WorkerNode? bestWorker;
//   //   int lowestUsage = 9999;

//   //   for (var w in workerList) {
//   //     final workerId = w['id'];
//   //     final limit = w['rpm'];
//   //     final provider = w['provider'] ?? 'gemini'; // Default to gemini if missing

//   //     int currentUsage = 0;
//   //     int lastReset = 0;

//   //     if (snapshot.child(workerId).exists) {
//   //       final stats = snapshot.child(workerId).value as Map;
//   //       currentUsage = stats['usage'] ?? 0;
//   //       lastReset = stats['reset_time'] ?? 0;

//   //       // Lazy Reset Logic: If >60s passed, usage is effectively 0
//   //       if (DateTime.now().millisecondsSinceEpoch - lastReset > 60000) {
//   //         currentUsage = 0;
//   //       }
//   //     }

//   //     // Selection: Pick the one with the lowest usage that is under the limit
//   //     if (currentUsage < limit) {
//   //       if (currentUsage < lowestUsage) {
//   //         lowestUsage = currentUsage;
//   //         bestWorker = WorkerNode(
//   //           id: workerId,
//   //           key: w['key'],
//   //           provider: provider,
//   //           rpmLimit: limit,
//   //         );
//   //       }
//   //     }
//   //   }

//   //   // Failover: Default to the first worker if selection finds nothing
//   //   return bestWorker ?? WorkerNode(
//   //     id: workerList[0]['id'],
//   //     key: workerList[0]['key'],
//   //     provider: workerList[0]['provider'] ?? 'gemini',
//   //     rpmLimit: workerList[0]['rpm'] ?? 15,
//   //   );
//   // }

//   // Transactional counter update
//   Future<void> incrementUsage(String workerId) async {
//     final ref = _db.child(workerId);
//     await ref.runTransaction((data) {
//       Map<String, dynamic> stats = (data as Map?) != null
//           ? Map<String, dynamic>.from(data as Map)
//           : {'usage': 0, 'reset_time': DateTime.now().millisecondsSinceEpoch};

//       final now = DateTime.now().millisecondsSinceEpoch;

//       if (now - (stats['reset_time'] as int) > 60000) {
//         stats['usage'] = 1;
//         stats['reset_time'] = now;
//       } else {
//         stats['usage'] = (stats['usage'] as int) + 1;
//       }
//       return Transaction.success(stats);
//     });
//   }
// }

// import 'dart:convert';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_remote_config/firebase_remote_config.dart';

// class WorkerNode {
//   final String id;
//   final String key;
//   final int rpmLimit;

//   WorkerNode({required this.id, required this.key, required this.rpmLimit});
// }

// class AiClusterManager {
//   // 1. Private static instance
//   static final AiClusterManager _instance = AiClusterManager._internal();

//   // 2. Public factory returning the same instance every time
//   factory AiClusterManager() => _instance;

//   // 3. Named constructor (Private)
//   AiClusterManager._internal();

//   // --- Members ---
//   final _remoteConfig = FirebaseRemoteConfig.instance;
//   final _db = FirebaseDatabase.instance.ref("api_cluster_status");
//   bool _isInitialized = false;

//   // 4. Smart Init Method (Merged and Cleaned)
//   Future<void> init() async {
//     if (_isInitialized) return;

//     try {
//       print("🚀 Initializing AI Cluster: Fetching Remote Config...");
//       await _remoteConfig.setConfigSettings(RemoteConfigSettings(
//         fetchTimeout: const Duration(seconds: 30),
//         minimumFetchInterval: const Duration(hours: 1),
//       ));
//       await _remoteConfig.fetchAndActivate();
//       _isInitialized = true;
//       print("✅ AI Cluster Initialized Successfully");
//     } catch (e) {
//       print("❌ AI Cluster Init Failed: $e");
//     }
//   }

//   // 5. Logic to find the healthiest worker
//   Future<WorkerNode> getBestWorker() async {
//     // Ensure we are initialized before proceeding
//     if (!_isInitialized) await init();

//     // A. Get Workers from Remote Config
//     final jsonString = _remoteConfig.getString("ai_cluster_config");
//     if (jsonString.isEmpty) {
//       throw Exception("Remote Config 'ai_cluster_config' is empty or not found.");
//     }
    
//     final data = jsonDecode(jsonString);
//     final List<dynamic> workerList = data['workers'];

//     // B. Check Usage Stats from Realtime DB
//     final snapshot = await _db.get();

//     WorkerNode? bestWorker;
//     int lowestUsage = 9999;

//     for (var w in workerList) {
//       final workerId = w['id'];
//       final limit = w['rpm'];

//       int currentUsage = 0;
//       int lastReset = 0;

//       if (snapshot.child(workerId).exists) {
//         final stats = snapshot.child(workerId).value as Map;
//         currentUsage = stats['usage'] ?? 0;
//         lastReset = stats['reset_time'] ?? 0;

//         // Lazy Reset: If >1 min has passed, usage is treated as 0 locally
//         if (DateTime.now().millisecondsSinceEpoch - lastReset > 60000) {
//           currentUsage = 0;
//         }
//       }

//       // C. Selection Logic: Pick worker with most capacity
//       if (currentUsage < limit) {
//         if (currentUsage < lowestUsage) {
//           lowestUsage = currentUsage;
//           bestWorker = WorkerNode(
//             id: workerId, 
//             key: w['key'], 
//             rpmLimit: limit
//           );
//         }
//       }
//     }

//     // Failover: If logic fails, pick the first configured worker
//     return bestWorker ?? WorkerNode(
//       id: workerList[0]['id'],
//       key: workerList[0]['key'],
//       rpmLimit: workerList[0]['rpm'] ?? 15,
//     );
//   }

//   // 6. Transactional increment to prevent race conditions
//   Future<void> incrementUsage(String workerId) async {
//     final ref = _db.child(workerId);

//     await ref.runTransaction((data) {
//       Map<String, dynamic> stats = (data as Map?) != null
//           ? Map<String, dynamic>.from(data as Map)
//           : {
//               'usage': 0,
//               'reset_time': DateTime.now().millisecondsSinceEpoch
//             };

//       final now = DateTime.now().millisecondsSinceEpoch;

//       // If a minute has passed since last reset, start fresh
//       if (now - (stats['reset_time'] as int) > 60000) {
//         stats['usage'] = 1;
//         stats['reset_time'] = now;
//       } else {
//         stats['usage'] = (stats['usage'] as int) + 1;
//       }

//       return Transaction.success(stats);
//     });
//   }
// }