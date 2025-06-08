import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'appointment_history_page.dart';
import 'emergency_service_page.dart';
import 'select_datetime_page.dart';
import 'profile_page.dart';
import 'contact_feedback_page.dart';


class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String userLastName = '';
  List<Map<String, dynamic>> popularDoctors = [];
  bool isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPopularDoctors();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          setState(() {
            userLastName = userDoc.data()?['lastName'] ?? 'User';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          userLastName = 'User';
        });
      }
    }
  }

  Future<void> _loadPopularDoctors() async {
    try {
      // Get all appointments
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .get();

      // Count appointments per doctor
      Map<String, Map<String, dynamic>> doctorCounts = {};

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final doctorId = data['doctorId'] as String?;
        final doctorName = data['doctorName'] as String?;
        final doctorSpecialization = data['doctorSpecialization'] as String?;
        final doctorHospital = data['doctorHospital'] as String?;
        final doctorImg = data['doctorimg'] as String?;

        if (doctorId != null && doctorName != null) {
          if (doctorCounts.containsKey(doctorId)) {
            doctorCounts[doctorId]!['count']++;
          } else {
            doctorCounts[doctorId] = {
              'doctorId': doctorId,
              'name': doctorName,
              'specialization': doctorSpecialization ?? 'General',
              'hospital': doctorHospital ?? 'Hospital',
              'imageUrl': doctorImg ?? '',
              'count': 1,
            };
          }
        }
      }

      // Sort doctors by appointment count and get top 3
      final sortedDoctors = doctorCounts.values.toList()
        ..sort((a, b) => b['count'].compareTo(a['count']));

      if (mounted) {
        setState(() {
          popularDoctors = sortedDoctors.take(3).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading popular doctors: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }

  // Toggle favorite status
  Future<void> _toggleFavorite(String doctorId, String doctorName, Map<String, dynamic> doctorData) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to add favorites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed $doctorName from favorites'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added $doctorName to favorites'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Refresh the UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating favorites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Hi, ${userLastName.isNotEmpty ? userLastName : 'User'}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Navigate to Inbox/Notifications
                        },
                        child: const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.notifications_none, color: Colors.blue, size: 28),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          // Logout functionality
                        },
                        child: const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.logout, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Let's find\nyour top doctor!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                    hintText: 'Search doctors, hospitals...',
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Main Services
              const Text(
                "Services",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategory(context, Icons.calendar_month, "Booking\nAppointment", Colors.blue),
                  _buildCategory(context, Icons.history, "Appointment\nHistory", Colors.green),
                  _buildCategory(context, Icons.medical_information, "Medical\nRecord", Colors.purple),
                  _buildCategory(context, Icons.home_work, "HomeCare\nServices", Colors.orange),
                ],
              ),
              const SizedBox(height: 20),

              // Additional Services
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategory(context, Icons.person_search, "View Doctor\nProfile", Colors.teal),
                  _buildCategory(context, Icons.local_hospital, "List of\nHospitals", Colors.red),
                  _buildCategory(context, Icons.account_circle, "User\nProfile", Colors.indigo),
                  _buildCategory(context, Icons.feedback, "Feedback/\nContact Us", Colors.amber),
                ],
              ),
              const SizedBox(height: 25),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyServicePage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Emergency Service",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "24/7 Available for urgent care",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Popular Doctors
              const Text(
                "Popular Doctor",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Dynamic Popular Doctors List
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (popularDoctors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'No popular doctors found',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                ...popularDoctors.map((doctor) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDoctorCard(doctor['doctorId'], doctor),
                )),

              const SizedBox(height: 80), // Extra space for bottom navigation
            ],
          ),
        ),
      ),
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
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
          onTap: (index) {
            // Handle navigation based on index
            switch (index) {
              case 0:
              // Home - already here
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppointmentHistoryPage()),
                );
                break;
              case 2:
              // Navigate to Medical Records
                break;
              case 3:
              // Navigate to Profile
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
                break;
              case 4:
              // Navigate to More/Settings
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategory(BuildContext context, IconData icon, String title, Color color) {
    return GestureDetector(
      onTap: () {
        // Handle navigation based on title
        if (title.contains("Booking")) {
          Navigator.pushNamed(context, '/book-appointment');
        } else if (title.contains("History")) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AppointmentHistoryPage()),
          );
        } else if (title.contains("Medical")) {
          // Navigate to medical records
        } else if (title.contains("HomeCare")) {
          // Navigate to nurse services -> QR Payment
        } else if (title.contains("Doctor")) {
          // Navigate to doctor profiles
        } else if (title.contains("Hospital")) {
          // Navigate to hospital list
        } else if (title.contains("Profile")) {
          // Navigate to user profile
          Navigator.pushNamed(context, '/profile');
        } else if (title.contains("Feedback")) {
          // Navigate to feedback/contact us
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactFeedbackPage()),
          );
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(String doctorId, Map<String, dynamic> doctor) {
    final name = doctor['name'] ?? 'Unknown Doctor';
    final specialization = doctor['specialization'] ?? 'General';
    final hospital = doctor['hospital'] ?? 'Unknown Hospital';
    final imageUrl = doctor['imageUrl'] ?? '';

    return GestureDetector(
      onTap: () => _navigateToSelectDateTime(doctorId, doctor),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
        ),
      ),
    );
  }
}