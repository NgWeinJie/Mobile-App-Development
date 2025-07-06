import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_page.dart';
import 'favorites_page.dart';
import 'profile_page.dart';
import 'appointment_history_page.dart';
import 'medical_record_page.dart';

class HospitalsListPage extends StatefulWidget {
  const HospitalsListPage({super.key});

  @override
  State<HospitalsListPage> createState() => _HospitalsListPageState();
}

class _HospitalsListPageState extends State<HospitalsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Launch URL (website)
  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Copy phone number to clipboard
  Future<void> _copyPhoneNumber(String phoneNumber) async {
    await Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone number copied: $phoneNumber'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Show hospital details dialog
  void _showHospitalDetails(Map<String, dynamic> hospital) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hospital Image
                if (hospital['imageUrl'] != null && hospital['imageUrl'].isNotEmpty)
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade200,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        hospital['imageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.local_hospital,
                            size: 50,
                            color: Colors.grey.shade400,
                          );
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Hospital Name
                Text(
                  hospital['name'] ?? 'Unknown Hospital',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Hospital Type
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hospital['type'] ?? 'General Hospital',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Description
                if (hospital['description'] != null && hospital['description'].isNotEmpty)
                  Text(
                    hospital['description'],
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),

                const SizedBox(height: 16),

                // Website button only
                if (hospital['website'] != null && hospital['website'].isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl(hospital['website']),
                      icon: const Icon(Icons.web, size: 16),
                      label: const Text('Visit Website'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserHomePage()),
            );
          },
          child: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Hospitals',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search hospitals...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: Icon(Icons.close, color: Colors.grey.shade400),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Hospitals List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('hospitals').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Something went wrong'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final hospitals = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();

                  // Apply search filter only
                  return _searchQuery.isEmpty || name.contains(_searchQuery);
                }).toList();

                if (hospitals.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hospitals found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: hospitals.length,
                  itemBuilder: (context, index) {
                    final hospitalDoc = hospitals[index];
                    final hospital = hospitalDoc.data() as Map<String, dynamic>;
                    return _buildHospitalCard(hospitalDoc.id, hospital);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
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
          currentIndex: 0, // Home tab selected (adjust as needed)
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
            // Handle navigation based on index
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
                  MaterialPageRoute(
                      builder: (context) => const AppointmentHistoryPage()),
                );
                break;
              case 2:
              // Navigate to Medical Records
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MedicalRecordsPage()),
                );
                break;
              case 3:
              // Navigate to Favorites
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritesPage()),
                );
                break;
              case 4:
              // Navigate to Profile
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

  Widget _buildHospitalCard(String hospitalId, Map<String, dynamic> hospital) {
    final name = hospital['name'] ?? 'Unknown Hospital';
    final type = hospital['type'] ?? 'General Hospital';
    final address = hospital['address'] ?? 'Unknown Address';
    final phone = hospital['phone'] ?? '';
    final imageUrl = hospital['imageUrl'] ?? '';
    final rating = hospital['rating']?.toDouble() ?? 4.5;

    return GestureDetector(
      onTap: () => _showHospitalDetails(hospital),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hospital Image at top
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Colors.grey.shade200,
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.local_hospital,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade300,
                        ),
                      ),
                    );
                  },
                ),
              )
                  : Center(
                child: Icon(
                  Icons.local_hospital,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
              ),
            ),

            // Hospital Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hospital Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Hospital Type Badge
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade100, Colors.blue.shade50],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Address with location icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Phone number with copy functionality (only if phone exists)
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _copyPhoneNumber(phone),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.phone,
                              size: 16,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Rating with stars
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Tap to view more indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}