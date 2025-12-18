
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:virtual_dating/my_home_page.dart';
import 'package:virtual_dating/pages/profile_page.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final PersistentTabController _controller = PersistentTabController(initialIndex: 0);

  // Define Colors for Consistency
  final Color activeColor = Colors.white;
  final Color inactiveColor = Colors.grey.shade400;

  List<PersistentTabConfig> _tabs() => [
    // Tab 1: Home
    PersistentTabConfig(
      screen: const MyHomePage(),
      item: ItemConfig(
        icon: const Icon(Icons.heart_broken), // Rounded icons look more modern
        title: "Date",
        activeForegroundColor: activeColor,
        inactiveForegroundColor: inactiveColor,
      ),
    ),

    // Tab 2: Applied Jobs
    PersistentTabConfig(
      // screen: const Scaffold(body: Center(child: Text("Applied Jobs Screen"))), 
      screen:  const Placeholder(),
      item: ItemConfig(
        icon: const Icon(Icons.leaderboard),
        title: "Leaderboard",
        activeForegroundColor: Colors.blueAccent, // You can vary colors per tab!
        inactiveForegroundColor: inactiveColor,
      ),
    ),

    // Tab 3: leaderboard
    PersistentTabConfig(
      // screen: const Scaffold(body: Center(child: Text("Explore Screen"))), 
      // screen: ResultDetailPage(),
      screen: const Placeholder(),
      item: ItemConfig(
        icon: const Icon(Icons.inbox),
        title: "Inbox",
        activeForegroundColor: Colors.orange,
        inactiveForegroundColor: inactiveColor,
      ),
    ),

    // Tab 4: Profile
    PersistentTabConfig(
      screen: const ProfileScreen(),
      item: ItemConfig(
        icon: const Icon(Icons.person_rounded),
        title: "Profile",
        activeForegroundColor: Colors.teal,
        inactiveForegroundColor: inactiveColor,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      controller: _controller,
      tabs: _tabs(),
      backgroundColor: Colors.black, // Important for the floating look
      margin: const EdgeInsets.all(0), // Reset margins
      
      // 1. THE STYLE BUILDER
      navBarBuilder: (navBarConfig) => Style2BottomNavBar(
        navBarConfig: navBarConfig,
        
        // 2. THE DECORATION (The "Floating" Look)
        navBarDecoration: NavBarDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          // If you want a full "Floating Pill" look, use this instead:
          // borderRadius: BorderRadius.circular(50), 
          
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
          
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5), // Shadow pushes UP slightly
            ),
          ],
        ),
        
        // 3. SMOOTH ANIMATION
        itemAnimationProperties: const ItemAnimation(
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOutQuint,
        ),
      ),
      
      resizeToAvoidBottomInset: true,
      stateManagement: true,
    );
  }
}