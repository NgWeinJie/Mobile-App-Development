import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NurseProfilePage extends StatefulWidget {
  const NurseProfilePage({super.key});

  @override
  State<NurseProfilePage> createState() => _NurseProfilePageState();
}

class _NurseProfilePageState extends State<NurseProfilePage> {
  Map<String, dynamic>? nurse;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNurseData();
  }

  Future<void> fetchNurseData() async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance.collection('nurses').doc(user!.uid).get();
    if (doc.exists) {
      setState(() {
        nurse = doc.data()!;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> showEditDialog() async {
    final nameController = TextEditingController(text: nurse?['name']);
    final emailController = TextEditingController(text: nurse?['email']);
    final phoneController = TextEditingController(text: nurse?['phone']);

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
                await FirebaseFirestore.instance.collection('nurses').doc(user!.uid).update({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                });

                if (user.email != emailController.text.trim()) {
                  await user.updateEmail(emailController.text.trim());
                }

                Navigator.pop(context);
                await fetchNurseData();
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
          : nurse == null
          ? const Center(child: Text('Nurse data not found.'))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row with back and edit buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () {
                      Navigator.pop(context); // Back to Nurse Home Page
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: nurse == null ? null : showEditDialog,
                    tooltip: 'Edit Profile',
                  ),
                ],
              ),

              // Profile picture
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: nurse!['imageUrl'] != null && nurse!['imageUrl'].toString().isNotEmpty
                      ? NetworkImage(nurse!['imageUrl'])
                      : const AssetImage('assets/default_profile.png') as ImageProvider,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 16),

              // Name & specialization
              Center(
                child: Column(
                  children: [
                    Text(
                      nurse!['name'] ?? 'Nurse Name',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nurse!['specialization'] ?? '',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Info tiles
              _buildInfoTile('Nurse ID', nurse!['nurseId'], Icons.badge),
              _buildInfoTile('Email', nurse!['email'], Icons.email),
              _buildInfoTile('Phone', nurse!['phone'], Icons.phone),
              _buildInfoTile('Specialization', nurse!['specialization'], Icons.medical_services),
            ],
          ),
        ),
      ),
    );
  }
}
