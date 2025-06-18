import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NurseHomePage extends StatelessWidget {
  const NurseHomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/nurse-login');
  }

  void _goToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/nurse-profile');
  }

  void _goToSchedule(BuildContext context) {
    Navigator.pushNamed(context, '/nurse-schedule');
  }

  void _goToMedicalRecord(BuildContext context) {
    Navigator.pushNamed(context, '/nurse-medical-records');
  }

  void _goToNews(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-news');
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[50],
                radius: 28,
                child: Icon(icon, size: 30, color: Colors.blue),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _fetchNurseName(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('nurses').doc(uid).get();
    return doc.data()?['name'] ?? 'Nurse';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: FutureBuilder<String>(
        future: _fetchNurseName(user!.uid),
        builder: (context, snapshot) {
          final nurseName = snapshot.data ?? 'Nurse';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Logout button top-right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue[100],
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.blue),
                          onPressed: () => _logout(context),
                          tooltip: 'Logout',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Welcome message
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.blue[100],
                        child: const Icon(Icons.waving_hand, size: 32, color: Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Welcome, $nurseName',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Feature cards
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildFeatureCard(
                        context: context,
                        icon: Icons.account_circle,
                        title: 'Profile',
                        onTap: () => _goToProfile(context),
                      ),
                      _buildFeatureCard(
                        context: context,
                        icon: Icons.calendar_today,
                        title: 'Schedule',
                        onTap: () => _goToSchedule(context),
                      ),
                      _buildFeatureCard(
                        context: context,
                        icon: Icons.folder_shared,
                        title: 'Medical Records',
                        onTap: () => _goToMedicalRecord(context),
                      ),
                      _buildFeatureCard(
                        context: context,
                        icon: Icons.newspaper,
                        title: 'News',
                        onTap: () => _goToNews(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
