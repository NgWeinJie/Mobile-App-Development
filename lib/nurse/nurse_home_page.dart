import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  void _goToContactUs(BuildContext context) {
    Navigator.pushNamed(context, '/nurse-contact');
  }

  void _goToTermsPage(BuildContext context) {
    Navigator.pushNamed(context, '/nurse-terms');
  }

  void _showBookingDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patientDetails'] ?? {};
    final List<dynamic> selectedDates = data['selectedDates'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nurse Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Name: ${data['nurseName'] ?? 'N/A'}'),
              Text('Hospital: ${data['nurseHospital'] ?? 'N/A'}'),
              Text('Specialization: ${data['nurseSpecialization'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Patient Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Name: ${patient['name'] ?? 'N/A'}'),
              Text('Email: ${patient['email'] ?? 'N/A'}'),
              Text('Mobile: ${patient['mobile'] ?? 'N/A'}'),
              Text('Gender: ${patient['gender'] ?? 'N/A'}'),
              Text('NRIC: ${patient['nric'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Appointment Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Dates: ${selectedDates.join(', ')}'),
              Text('Time Slot: ${data['timeSlot'] ?? 'N/A'}'),
              Text('Status: ${data['status'] ?? 'N/A'}'),
              if (data['createdAt'] != null)
                Text(
                  'Created At: ${data['createdAt'].toDate().toLocal()}',
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [

                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue[100],
                        child: IconButton(
                          icon: const Icon(Icons.verified_user, color: Colors.blue),
                          onPressed: () => _goToTermsPage(context),
                          tooltip: 'Terms & Conditions',
                        ),
                      ),
                      const SizedBox(width: 12),

                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue[100],
                        child: IconButton(
                          icon: const Icon(Icons.comment, color: Colors.blue),
                          onPressed: () => _goToContactUs(context),
                          tooltip: 'Contact Us',
                        ),
                      ),
                      const SizedBox(width: 12),

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

                  // Welcome
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

                  // Feature Cards
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

                  const SizedBox(height: 32),

                  // Appointments
                  const Text(
                    'Upcoming Appointments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 12),

                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('booking')
                        .where('nurseId', isEqualTo: user.uid)
                        .where('status', isEqualTo: 'confirmed')
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text(
                          'No upcoming appointments.',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        );
                      }

                      final now = DateTime.now();
                      final upcoming = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final List<dynamic> selectedDates = data['selectedDates'] ?? [];
                        return selectedDates.any((dateStr) {
                          try {
                            final parsed = DateTime.parse(dateStr);
                            return parsed.isAfter(now);
                          } catch (_) {
                            return false;
                          }
                        });
                      }).toList();

                      if (upcoming.isEmpty) {
                        return const Text(
                          'No upcoming appointments.',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        );
                      }

                      return Column(
                        children: upcoming.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final patient = data['patientDetails'] ?? {};
                          final List<dynamic> selectedDates = data['selectedDates'] ?? [];

                          final firstUpcomingDate = selectedDates.firstWhere((dateStr) {
                            try {
                              return DateTime.parse(dateStr).isAfter(now);
                            } catch (_) {
                              return false;
                            }
                          }, orElse: () => 'Unknown');

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today, color: Colors.blue),
                              title: Text(patient['name'] ?? 'Unknown'),
                              subtitle: Text('$firstUpcomingDate at ${data['timeSlot']}'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showBookingDetailsDialog(context, data),
                            ),
                          );
                        }).toList(),
                      );
                    },
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
