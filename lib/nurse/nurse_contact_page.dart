import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NurseContactPage extends StatefulWidget {
  const NurseContactPage({super.key});

  @override
  State<NurseContactPage> createState() => _NurseContactPageState();
}

class _NurseContactPageState extends State<NurseContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      final email = user?.email;

      // Fetch nurse's phone from Firestore
      final doc = await FirebaseFirestore.instance.collection('nurses').doc(uid).get();
      final phone = doc.data()?['phone'] ?? '-';

      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': uid,
        'email': email,
        'phone': phone,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted!')),
        );
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need Help?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you have any questions or concerns, please feel free to contact us using the information below or send us a message.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                const ListTile(
                  leading: Icon(Icons.phone, color: Colors.blue),
                  title: Text('Phone'),
                  subtitle: Text('+60 12-345 6789'),
                ),
                const ListTile(
                  leading: Icon(Icons.email, color: Colors.blue),
                  title: Text('Email'),
                  subtitle: Text('support@healthconnect.my'),
                ),
                const ListTile(
                  leading: Icon(Icons.location_on, color: Colors.blue),
                  title: Text('Address'),
                  subtitle: Text('123 Jalan Medis, 11900 Bayan Lepas, Penang'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Send a Message:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a subject';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text('Submit'),
                    onPressed: _isSubmitting ? null : _submitFeedback,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
