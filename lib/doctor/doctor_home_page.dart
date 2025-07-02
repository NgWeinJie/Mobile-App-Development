import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorHomePage extends StatelessWidget {
  const DoctorHomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/doctor-login');
  }

  void _goToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-profile');
  }

  void _goToSchedule(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-schedule');
  }

  void _goToMedicalRecord(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-medical-records');
  }

  void _goToNews(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-news');
  }

  void _goToContactPage(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-contact');
  }

  void _goToTermsPage(BuildContext context) {
    Navigator.pushNamed(context, '/doctor-terms');
  }

  void _showAppointmentDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patientDetails'] ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Doctor Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Name: ${data['doctorName'] ?? 'N/A'}'),
              Text('Hospital: ${data['doctorHospital'] ?? 'N/A'}'),
              Text('Specialization: ${data['doctorSpecialization'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Patient Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Name: ${patient['name'] ?? 'N/A'}'),
              Text('Email: ${patient['email'] ?? 'N/A'}'),
              Text('Mobile: ${patient['mobile'] ?? 'N/A'}'),
              Text('Gender: ${patient['gender'] ?? 'N/A'}'),
              Text('NRIC: ${patient['nric'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Appointment Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Date: ${data['appointmentDate'] ?? 'N/A'}'),
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

  Future<String> _fetchDoctorName(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('doctors').doc(uid).get();
    return doc.data()?['name'] ?? 'Doctor';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: FutureBuilder<String>(
        future: _fetchDoctorName(user!.uid),
        builder: (context, snapshot) {
          final doctorName = snapshot.data ?? 'Doctor';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          onPressed: () => _goToContactPage(context),
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
                          'Welcome, $doctorName',
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

                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

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
                        .collection('appointments')
                        .where('doctorId', isEqualTo: user.uid)
                        .where('status', isEqualTo: 'pending')
                        .orderBy('appointmentDate')
                        .limit(3)
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

                      final appointments = snapshot.data!.docs;

                      return Column(
                        children: appointments.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final patient = data['patientDetails'] ?? {};

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today, color: Colors.blue),
                              title: Text(patient['name'] ?? 'Unknown'),
                              subtitle: Text(
                                '${data['appointmentDate']} at ${data['timeSlot']}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showAppointmentDetailsDialog(context, data),
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
