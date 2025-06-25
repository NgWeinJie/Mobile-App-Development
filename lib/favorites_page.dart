import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'select_datetime_page.dart';
import 'view_doctor_profile.dart';
import 'home_care_booking_page.dart';
import 'appointment_history_page.dart';
import 'profile_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Remove doctor from favorites
  Future<void> _removeDoctorFromFavorites(String doctorId, String doctorName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('doctors')
          .doc(doctorId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $doctorName from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error removing doctor from favorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error removing from favorites'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Remove nurse from favorites
  Future<void> _removeNurseFromFavorites(String nurseId, String nurseName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('nurses')
          .doc(nurseId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $nurseName from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error removing nurse from favorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error removing from favorites'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Navigate to doctor profile page
  Future<void> _navigateToViewProfile(String doctorId, Map<String, dynamic> favoriteData) async {
    try {
      // Fetch complete doctor data from the main doctors collection
      final doctorDoc = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .get();

      if (doctorDoc.exists) {
        final completeDoctorData = doctorDoc.data() as Map<String, dynamic>;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewDoctorProfilePage(
              doctorId: doctorId,
              doctorData: completeDoctorData, // Use complete data with schedule
            ),
          ),
        );
      } else {
        // Doctor not found in main collection
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor information not available'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error fetching doctor data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading doctor profile'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Navigate to home care booking page
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
    final user = _auth.currentUser;

    if (user == null) {
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
            'Favorites',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Please login to view your favorites',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

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
          'Favorites',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Doctors'),
            Tab(text: 'Nurses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Doctors Tab
          _buildDoctorsTab(user.uid),
          // Nurses Tab
          _buildNursesTab(user.uid),
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
          currentIndex: 3, // Favorites tab selected
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
                  MaterialPageRoute(
                      builder: (context) => const AppointmentHistoryPage()),
                );
                break;
              case 2:
              // Navigate to Medical Records
                break;
              case 3:
              // Current Page
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

  Widget _buildDoctorsTab(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('favorites')
          .doc(userId)
          .collection('doctors')
          .orderBy('addedAt', descending: true)
          .snapshots(),
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

        final favoriteDoctors = snapshot.data!.docs;

        if (favoriteDoctors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No favorite doctors yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add doctors to your favorites to see them here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favoriteDoctors.length,
          itemBuilder: (context, index) {
            final favoriteDoc = favoriteDoctors[index];
            final favoriteData = favoriteDoc.data() as Map<String, dynamic>;
            return _buildDoctorCard(favoriteDoc.id, favoriteData);
          },
        );
      },
    );
  }

  Widget _buildNursesTab(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('favorites')
          .doc(userId)
          .collection('nurses')
          .orderBy('addedAt', descending: true)
          .snapshots(),
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

        final favoriteNurses = snapshot.data!.docs;

        if (favoriteNurses.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No favorite nurses yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add nurses to your favorites to see them here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favoriteNurses.length,
          itemBuilder: (context, index) {
            final favoriteDoc = favoriteNurses[index];
            final favoriteData = favoriteDoc.data() as Map<String, dynamic>;
            return _buildNurseCard(favoriteDoc.id, favoriteData);
          },
        );
      },
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

                // Remove from favorites button
                GestureDetector(
                  onTap: () => _removeDoctorFromFavorites(doctorId, name),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // View Profile Button (now takes full width)
            SizedBox(
              width: double.infinity,
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
          ],
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

              // Remove from favorites button
              GestureDetector(
                onTap: () => _removeNurseFromFavorites(nurseId, name),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.shade400,
                    size: 20,
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