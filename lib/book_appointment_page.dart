import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'select_datetime_page.dart';
import 'view_doctor_profile.dart';
import 'favorites_page.dart';
import 'profile_page.dart';
import 'appointment_history_page.dart';
import 'medical_record_page.dart';

class BookAppointmentPage extends StatefulWidget {
  const BookAppointmentPage({super.key});

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialization = 'All';
  String _selectedHospital = 'All';
  String _searchQuery = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _specializations = [
    'All',
    'Cardiology',
    'Paediatrics',
    'Dermatology',
    'Otorhinolaryngology',
    'General Surgery',
  ];

  final List<String> _hospitals = [
    'All',
    'Hospital Lam Wah Ee',
    'Gleneagles Hospital Penang',
    'Island Hospital Penang',
    'Pantai Hospital Penang',
    'Penang Adventist Hospital'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Check if doctor is in user's favorites
  Future<bool> _isFavorite(String doctorId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('doctors')
          .doc(doctorId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // Toggle favorite status
  Future<void> _toggleFavorite(String doctorId, String doctorName, Map<String, dynamic> doctorData) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add favorites'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final favoriteRef = _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('doctors')
          .doc(doctorId);

      final doc = await favoriteRef.get();

      if (doc.exists) {
        // Remove from favorites
        await favoriteRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $doctorName from favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Add to favorites
        await favoriteRef.set({
          'doctorId': doctorId,
          'name': doctorName,
          'specialization': doctorData['specialization'] ?? '',
          'hospital': doctorData['hospital'] ?? '',
          'imageUrl': doctorData['imageUrl'] ?? '',
          'addedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $doctorName to favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Refresh the UI
      setState(() {});
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating favorites'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Navigate to select date time page
  void _navigateToSelectDateTime(String doctorId, Map<String, dynamic> doctorData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectDateTimePage(
          doctorId: doctorId,
          doctorData: doctorData,
        ),
      ),
    );
  }

  // Navigate to doctor profile page
  void _navigateToViewProfile(String doctorId, Map<String, dynamic> doctorData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewDoctorProfilePage(
          doctorId: doctorId,
          doctorData: doctorData,
        ),
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
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserHomePage()),
            );
          },
          child: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Appointment',
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
                  hintText: 'Search',
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

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Specialization filters
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _specializations.length,
                    itemBuilder: (context, index) {
                      final specialization = _specializations[index];
                      final isSelected = _selectedSpecialization == specialization;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(
                            specialization,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedSpecialization = specialization;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.blue : Colors.blue.shade200,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Hospital filters
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _hospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = _hospitals[index];
                      final isSelected = _selectedHospital == hospital;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(
                            hospital,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedHospital = hospital;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.blue : Colors.blue.shade200,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Doctors List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('doctors').snapshots(),
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

                final doctors = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final specialization = (data['specialization'] ?? '').toString();
                  final hospital = (data['hospital'] ?? '').toString();

                  // Apply search filter
                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery);

                  // Apply specialization filter
                  final matchesSpecialization = _selectedSpecialization == 'All' ||
                      specialization == _selectedSpecialization;

                  // Apply hospital filter (exact matching)
                  final matchesHospital = _selectedHospital == 'All' ||
                      hospital == _selectedHospital;

                  return matchesSearch && matchesSpecialization && matchesHospital;
                }).toList();

                if (doctors.isEmpty) {
                  return const Center(
                    child: Text(
                      'No doctors found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctorDoc = doctors[index];
                    final doctor = doctorDoc.data() as Map<String, dynamic>;
                    return _buildDoctorCard(doctorDoc.id, doctor);
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
          currentIndex: 0,
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

  Widget _buildDoctorCard(String doctorId, Map<String, dynamic> doctor) {
    final name = doctor['name'] ?? 'Unknown Doctor';
    final specialization = doctor['specialization'] ?? 'General';
    final hospital = doctor['hospital'] ?? 'Unknown Hospital';
    final imageUrl = doctor['imageUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Doctor Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                  ),
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.grey.shade400,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade300,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                      : Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 16),

                // Doctor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Specialist $specialization',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Hospital name with location icon
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.blue.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hospital,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Dynamic Favorite Button
                FutureBuilder<bool>(
                  future: _isFavorite(doctorId),
                  builder: (context, snapshot) {
                    final isFavorite = snapshot.data ?? false;

                    return GestureDetector(
                      onTap: () => _toggleFavorite(doctorId, name, doctor),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFavorite ? Colors.red.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red.shade400 : Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // View Profile Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _navigateToViewProfile(doctorId, doctor),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Book Appointment Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToSelectDateTime(doctorId, doctor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Book Appointment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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