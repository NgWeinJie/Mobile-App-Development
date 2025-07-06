import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'favorites_page.dart';
import 'profile_page.dart';
import 'home_page.dart';
import 'appointment_history_page.dart';

class MedicalRecordsPage extends StatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  State<MedicalRecordsPage> createState() => _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends State<MedicalRecordsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _medicalRecords = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicalRecords();
  }

  Future<void> _fetchMedicalRecords() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('medical')
          .where('email', isEqualTo: user.email)
          .orderBy('createdAt', descending: true)
          .get();

      final records = <Map<String, dynamic>>[];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        records.add(data);
      }

      setState(() {
        _medicalRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error fetching medical records: $e');
    }
  }

  void _viewRecordDetails(Map<String, dynamic> record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordDetailPage(medicalRecord: record),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp.runtimeType.toString().contains('Timestamp')) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return timestamp.toString();
      }

      return DateFormat('EEE, dd MMM yyyy').format(dateTime);
    } catch (e) {
      return timestamp.toString();
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'UN';

    final nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0].substring(0, 1).toUpperCase();
    } else {
      return '${nameParts[0].substring(0, 1)}${nameParts[1].substring(0, 1)}'.toUpperCase();
    }
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> record) {
    final condition = record['condition'] ?? 'Unknown Condition';
    final specialization = record['specialization'] ?? 'General';
    final createdAt = _formatDate(record['createdAt']);
    final notes = record['notes'] ?? '';
    final initials = _getInitials(record['name']);

    return GestureDetector(
      onTap: () => _viewRecordDetails(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        condition,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        specialization,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  notes.length > 100 ? '${notes.substring(0, 100)}...' : notes,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_medicalRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No medical records found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMedicalRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _medicalRecords.length,
        itemBuilder: (context, index) {
          return _buildMedicalRecordCard(_medicalRecords[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF5FF),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Medical Records',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildMedicalRecordsList(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          currentIndex: 2, // Set to records tab
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Appointments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_information),
              label: 'Records',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserHomePage()),
                );
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppointmentHistoryPage()),
                );
                break;
              case 2:
              // already here
                break;
              case 3:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritesPage()),
                );
                break;
              case 4:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}

// Detail page for viewing individual medical record
class MedicalRecordDetailPage extends StatelessWidget {
  final Map<String, dynamic> medicalRecord;

  const MedicalRecordDetailPage({
    super.key,
    required this.medicalRecord,
  });

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp.runtimeType.toString().contains('Timestamp')) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return timestamp.toString();
      }

      return DateFormat('MMM dd, yyyy at hh:mm a').format(dateTime);
    } catch (e) {
      return timestamp.toString();
    }
  }

  Widget _buildInfoSection(String title, IconData icon, Color iconColor, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'UN';

    final nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0].substring(0, 1).toUpperCase();
    } else {
      return '${nameParts[0].substring(0, 1)}${nameParts[1].substring(0, 1)}'.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF5FF),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Medical Record Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Condition Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(medicalRecord['name']),
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    medicalRecord['condition'] ?? 'Unknown Condition',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(medicalRecord['createdAt']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Patient Information
            _buildInfoSection(
              'Patient Information',
              Icons.person,
              Colors.blue.shade600,
              [
                _buildInfoRow('Name', medicalRecord['name'] ?? 'N/A', Icons.badge),
                _buildInfoRow('Gender', medicalRecord['gender'] ?? 'N/A', Icons.wc),
                _buildInfoRow('Email', medicalRecord['email'] ?? 'N/A', Icons.email),
                _buildInfoRow('Phone', medicalRecord['phone'] ?? 'N/A', Icons.phone),
              ],
            ),

            // Medical Information
            _buildInfoSection(
              'Medical Information',
              Icons.local_hospital,
              Colors.green.shade600,
              [
                _buildInfoRow('Specialization', medicalRecord['specialization'] ?? 'N/A', Icons.medical_information),
              ],
            ),

            // Medical Notes
            if (medicalRecord['notes'] != null && medicalRecord['notes'].toString().isNotEmpty)
              _buildInfoSection(
                'Medical Notes',
                Icons.note_alt,
                Colors.orange.shade600,
                [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      medicalRecord['notes'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}