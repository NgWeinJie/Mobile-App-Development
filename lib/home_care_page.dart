import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'home_care_booking_page.dart';
import 'appointment_history_page.dart';
import 'profile_page.dart';
import 'favorites_page.dart';
import 'medical_record_page.dart';

class HomeCarePage extends StatefulWidget {
  const HomeCarePage({super.key});

  @override
  State<HomeCarePage> createState() => _HomeCarePageState();
}

class _HomeCarePageState extends State<HomeCarePage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialization = 'All';
  String _selectedHospital = 'All';
  String _searchQuery = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _specializations = [
    'All',
    'Gerontology',
    'Psychiatric',
    'Dietician',
    'Pediatrics',
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

  // Check if nurse is in user's favorites
  Future<bool> _isFavorite(String nurseId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('nurses')
          .doc(nurseId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // Toggle favorite status
  Future<void> _toggleFavorite(String nurseId, String nurseName, Map<String, dynamic> nurseData) async {
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
          .collection('nurses')
          .doc(nurseId);

      final doc = await favoriteRef.get();

      if (doc.exists) {
        // Remove from favorites
        await favoriteRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $nurseName from favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Add to favorites
        await favoriteRef.set({
          'nurseId': nurseId,
          'name': nurseName,
          'specialization': nurseData['specialization'] ?? '',
          'hospital': nurseData['hospital'] ?? '',
          'imageUrl': nurseData['imageUrl'] ?? '',
          'price': nurseData['price'] ?? 0,
          'phone': nurseData['phone'] ?? '',
          'addedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $nurseName to favorites'),
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

  void _navigateToHomeCareBooking(String nurseId, Map<String, dynamic> nurseData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeCareBookingPage(
          nurseId: nurseId,
          nurseData: nurseData,
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
          'Homecare',
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
                  hintText: 'Search nurses...',
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

          // Nurses List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('nurses').snapshots(),
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

                final nurses = snapshot.data!.docs.where((doc) {
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

                if (nurses.isEmpty) {
                  return const Center(
                    child: Text(
                      'No nurses found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: nurses.length,
                  itemBuilder: (context, index) {
                    final nurseDoc = nurses[index];
                    final nurse = nurseDoc.data() as Map<String, dynamic>;
                    return _buildNurseCard(nurseDoc.id, nurse);
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

  Widget _buildNurseCard(String nurseId, Map<String, dynamic> nurse) {
    final name = nurse['name'] ?? 'Unknown Nurse';
    final specialization = nurse['specialization'] ?? 'General';
    final hospital = nurse['hospital'] ?? 'Unknown Hospital';
    final imageUrl = nurse['imageUrl'] ?? '';
    final price = nurse['price'] ?? 0;
    final phone = nurse['phone'] ?? '';

    return GestureDetector(
      onTap: () => _navigateToHomeCareBooking(nurseId, nurse),
      child: Container(
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
          child: Row(
            children: [
              // Nurse Image
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
                        Icons.local_hospital,
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
                  Icons.local_hospital,
                  size: 30,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 16),

              // Nurse Info
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
                    const SizedBox(height: 4),
                    // Price
                    Text(
                      'RM $price/day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
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
                    // Phone number
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.blue.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Dynamic Favorite Button
              FutureBuilder<bool>(
                future: _isFavorite(nurseId),
                builder: (context, snapshot) {
                  final isFavorite = snapshot.data ?? false;

                  return GestureDetector(
                    onTap: () => _toggleFavorite(nurseId, name, nurse),
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
        ),
      ),
    );
  }
}