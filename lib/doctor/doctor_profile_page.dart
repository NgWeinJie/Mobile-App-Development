import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'doctor_workday_page.dart';

class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  Map<String, dynamic>? doctor;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDoctorData();
  }

  Future<void> fetchDoctorData() async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance.collection('doctors').doc(user!.uid).get();
    if (doc.exists) {
      setState(() {
        doctor = doc.data()!;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> showEditDialog() async {
    final nameController = TextEditingController(text: doctor?['name']);
    final emailController = TextEditingController(text: doctor?['email']);
    final phoneController = TextEditingController(text: doctor?['phone']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;

              try {
                await FirebaseFirestore.instance.collection('doctors').doc(user!.uid).update({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                });

                if (user.email != emailController.text.trim()) {
                  await user.updateEmail(emailController.text.trim());
                }

                Navigator.pop(context);
                await fetchDoctorData(); // refresh view
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
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
      backgroundColor: const Color(0xFFF5F9FF),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctor == null
          ? const Center(child: Text('Doctor data not found.'))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.black87),
                    onPressed: showEditDialog,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Profile picture
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: doctor!['imageUrl'] != null &&
                      doctor!['imageUrl'].toString().isNotEmpty
                      ? NetworkImage(doctor!['imageUrl'])
                      : const AssetImage('assets/default_profile.png') as ImageProvider,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),

              const SizedBox(height: 16),

              // Name
              Center(
                child: Column(
                  children: [
                    Text(
                      doctor!['name'] ?? 'Doctor Name',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor!['specialization'] ?? '',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Info tiles
              _buildInfoTile('Doctor ID', doctor!['doctorId'], Icons.badge),
              _buildInfoTile('Email', doctor!['email'], Icons.email),
              _buildInfoTile('Phone', doctor!['phone'], Icons.phone),
              _buildInfoTile('Hospital', doctor!['hospital'], Icons.local_hospital),
              _buildInfoTile('Specialization', doctor!['specialization'], Icons.medical_services),

              const SizedBox(height: 24),

              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final updatedDoc = await FirebaseFirestore.instance
                          .collection('doctors')
                          .doc(user.uid)
                          .get();
                      final updatedData = updatedDoc.data();
                      if (updatedData != null &&
                          updatedData.containsKey('weeklySessions')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DoctorWorkdayPage(
                              weeklySessions: Map<String, dynamic>.from(
                                  updatedData['weeklySessions']),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Workday'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
