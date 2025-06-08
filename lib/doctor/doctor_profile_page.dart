import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'doctor_workday_page.dart';

class DoctorProfilePage extends StatelessWidget {
  const DoctorProfilePage({super.key});

  Future<DocumentSnapshot> _getDoctorInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance.collection('doctors').doc(user!.uid).get();
  }

  Widget _buildInfoTile(String label, String? value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value ?? 'Not available'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _getDoctorInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Doctor data not found.'));
          }

          final doctor = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 60,
                  backgroundImage: doctor['imageUrl'] != null && doctor['imageUrl'].toString().isNotEmpty
                      ? NetworkImage(doctor['imageUrl'])
                      : const AssetImage('assets/default_profile.png') as ImageProvider,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 16),

                // Name display (centered and bold)
                Text(
                  doctor['name'] ?? 'Doctor Name',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor['specialization'] ?? '',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Info cards
                _buildInfoTile('Doctor ID', doctor['doctorId'], Icons.badge),
                _buildInfoTile('Email', doctor['email'], Icons.email),
                _buildInfoTile('Phone', doctor['phone'], Icons.phone),
                _buildInfoTile('Hospital', doctor['hospital'], Icons.local_hospital),
                _buildInfoTile('Specialization', doctor['specialization'], Icons.medical_services),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorWorkdayPage(
                          weeklySessions: doctor['weeklySessions'],
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.calendar_today),
                  label: Text('Workday'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
