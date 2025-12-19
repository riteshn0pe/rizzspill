
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:virtual_dating/auth/auth_bloc.dart';
import 'package:virtual_dating/auth/auth_event.dart';
import 'package:virtual_dating/auth/auth_state.dart';
import 'package:virtual_dating/auth/user_profile_bloc.dart';
import 'package:virtual_dating/auth/user_profile_event.dart';
import 'package:virtual_dating/auth_service.dart';
import 'package:virtual_dating/matching/bloc/match_bloc.dart';
import 'package:virtual_dating/matching/repository/match_repository.dart';
import 'package:virtual_dating/matching/screens/finding_match_screen.dart';
import 'package:virtual_dating/my_home_page.dart';
import 'package:virtual_dating/pages/login_page.dart';
import 'package:virtual_dating/pages/navigation_page.dart';
import 'package:virtual_dating/repositories/user_repository.dart';
import 'package:virtual_dating/theme.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

// --- BLOC IMPORTS ---

// User Profile Bloc


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize if there are no existing apps
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    Firebase.app(); // Use the existing initialized app
  }

  runApp(const MyApp());
}

// Kept your inline ThemeProvider as requested
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark theme

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Initialize Repositories
    final userRepository = UserRepository();
    final authService = FirebaseService();

    // light theme
    final ThemeData lightTheme = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.light));

    // Dark theme (Your custom logic preserved)
    final ThemeData darkTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: const Color(0xFF121212), // Darker background
        textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData.dark().textTheme.apply(bodyColor: Colors.white)),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
          primary: Colors.orange, // Orange for primary elements
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white.withOpacity(0.1),
          labelStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide.none,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
        ));

    // 2. Wrap everything in MultiBlocProvider
    return MultiBlocProvider(
      providers: [
        // A. AUTH BLOC: Handles Login/Logout logic
        // We start it immediately with '..add(AuthStarted())'
        BlocProvider<AuthBloc>(
          create: (context) => 
              AuthBloc(authService: authService)..add(AuthStarted()),
        ),

        // B. USER PROFILE BLOC: Handles Database logic
        BlocProvider<UserProfileBloc>(
          create: (context) => UserProfileBloc(userRepository: userRepository),
        ),

        // C - This is required for the Homepage cards to work!
        BlocProvider<MatchBloc>(
          create: (context) => MatchBloc(MatchRepository()),
        ),
      ],
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ],
        child: Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'virtual dating',
            debugShowCheckedModeBanner: false,
            darkTheme: AppTheme.darkTheme, // Or use your 'darkTheme' variable
            theme: lightTheme,
            themeMode: themeProvider.themeMode, 

            // 1. Define the screen the app starts on
      initialRoute: '/', 
      
      // 2. The Route Map: This is where you identify '/matching'
      routes: {
        '/': (context) => const AuthGate(), // Or Splash Screen
        '/home': (context) => const MyHomePage(),
        '/matching': (context) => const FindingMatchScreen(), // Now identified!
      },
            
            // 3. The Professional Auth Gate
            // No more StreamBuilder spamming the database!
            // home: const AuthGate(),---commented after routun gthings
          );
        }),
      ),
    );
  }
}

// --- NEW WIDGET: AuthGate ---
// This handles the switch between Login and Navigation cleanly.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. LISTENER: Only triggers ONCE when state changes
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // User Logged In -> Load their Profile Data safely
          context.read<UserProfileBloc>().add(LoadUserProfile(state.uid));
        }
      },
      // 2. BUILDER: Only handles showing the UI
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            // return const FindingMatchScreen();
            // return const MyHomePage();
            return const NavigationPage();

            // return const NavigationPage();
          } else if (state is AuthUnauthenticated) {
            return const LoginPage();
          }
          
          // State is AuthLoading or AuthInitial (Splash Screen)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}