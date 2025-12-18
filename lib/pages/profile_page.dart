
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_dating/auth/user_profile_bloc.dart';
import 'package:virtual_dating/auth/user_profile_state.dart';
import 'package:virtual_dating/auth_service.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We still use this for Logout, which is fine.
    final FirebaseService authService = FirebaseService();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings screen
            },
          ),
        ],
      ),
      
      // 1. REPLACED StreamBuilder WITH BlocBuilder
      body: BlocBuilder<UserProfileBloc, UserProfileState>(
        builder: (context, state) {
          
          // STATE A: Loading
          if (state is UserProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // STATE B: Error
          if (state is UserProfileError) {
            return Center(child: Text("Error: ${state.message}", style: const TextStyle(color: Colors.red)));
          }

          // STATE C: Loaded (Success!)
          if (state is UserProfileLoaded) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              children: [
                 Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        
                        radius: 50,
                        // Use the Getter we defined in the State class
                        backgroundImage: NetworkImage(state.photoUrl.isNotEmpty 
                            ? state.photoUrl 
                            : 'https://via.placeholder.com/150'),
                      ),
                      
                      const SizedBox(height: 12),
                      Text(
                        state.fullName, // Using the Getter
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      // Example of accessing a raw field if you didn't make a getter
                      Text(
                        state.userData['role'] ?? "User",
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Using the specific data from the state
                _buildProfileOption(context, icon: Icons.person_outline, title: 'Edit Profile'),
                // _buildProfileOption(context, icon: Icons.golf_course, title: 'Current Courses'),
                _buildProfileOption(context, icon: Icons.email_outlined, title: state.email),
                // _buildProfileOption(context, icon: Icons.phone, title: state.userData['phoneNo'] ?? 'Add Phone Number'),
                
                const Divider(height: 40, thickness: 1, color: Color(0xFF2A2A2A)),
                
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w500)),
                  onTap: () async {
                    await authService.googleSignOut();
                  },
                ),
              ],
            );
          }

          // STATE D: Fallback (Initial state before loading)
          return const Center(child: Text("Initializing..."));
        },
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context, {required IconData icon, required String title}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[400]),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        // TODO: Implement navigation
      },
    );
  }
}