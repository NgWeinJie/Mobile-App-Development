import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'appointment_history_page.dart';
import 'emergency_service_page.dart';
import 'select_datetime_page.dart';
import 'profile_page.dart';
import 'contact_feedback_page.dart';
import 'book_appointment_page.dart';
import 'favorites_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String userLastName = '';
  List<Map<String, dynamic>> popularDoctors = [];
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = true;
  bool isSearching = false;
  bool showSearchResults = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPopularDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      Map<String, int> doctorCounts = {};

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final doctorId = data['doctorId'] as String?;

        if (doctorId != null) {
          doctorCounts[doctorId] = (doctorCounts[doctorId] ?? 0) + 1;
        }
      }

      // Sort doctors by appointment count
      final sortedDoctorIds = doctorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get top 3 doctor IDs
      final topDoctorIds = sortedDoctorIds.take(3).map((e) => e.key).toList();

      // Fetch complete doctor data from doctors collection
      List<Map<String, dynamic>> doctorsData = [];

      for (String doctorId in topDoctorIds) {
        try {
          final doctorDoc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(doctorId)
              .get();

          if (doctorDoc.exists) {
            final doctorData = doctorDoc.data() as Map<String, dynamic>;
            doctorData['doctorId'] = doctorId;
            doctorsData.add(doctorData);
          }
        } catch (e) {
          debugPrint('Error fetching doctor $doctorId: $e');
        }
      }

      if (mounted) {
        setState(() {
          popularDoctors = doctorsData;
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

  // Search doctors function - Modified to search only by doctor name
  Future<void> _searchDoctors(String query) async {
    if (query.isEmpty) {
      setState(() {
        showSearchResults = false;
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      showSearchResults = true;
    });

    try {
      final doctorsSnapshot = await _firestore.collection('doctors').get();

      final results = doctorsSnapshot.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();

        // Only search by doctor name
        return name.contains(searchQuery);
      }).map((doc) {
        final data = doc.data();
        data['doctorId'] = doc.id;
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          searchResults = results;
          isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching doctors: $e');
      if (mounted) {
        setState(() {
          isSearching = false;
          searchResults = [];
        });
      }
    }
  }

  // Clear search
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      showSearchResults = false;
      searchResults = [];
      isSearching = false;
    });
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
  Future<void> _toggleFavorite(String doctorId, String doctorName,
      Map<String, dynamic> doctorData) async {
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
  void _navigateToSelectDateTime(String doctorId,
      Map<String, dynamic> doctorData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectDateTimePage(
              doctorId: doctorId,
              doctorData: doctorData,
            ),
      ),
    );
  }

  // Logout function
  Future<void> _logout() async {
    try {
      // Show confirmation dialog
      final bool? shouldLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      );

      // If user confirmed logout
      if (shouldLogout == true) {
        // Sign out from Firebase
        await _auth.signOut();

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to login page and clear all previous routes
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
                (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error occurred during logout'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w500),
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
                          child: Icon(Icons.notifications_none, color: Colors
                              .blue, size: 28),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _logout, // Call the logout function
                        child: const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.logout, color: Colors.white,
                              size: 20),
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

              // Search Bar - Updated with centered hint text
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
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchDoctors(value);
                  },
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                      onTap: _clearSearch,
                      child: const Icon(Icons.clear, color: Colors.grey),
                    )
                        : null,
                    hintText: 'Search doctors...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Search Results Section
              if (showSearchResults) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Search Results (${searchResults.length})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (searchResults.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BookAppointmentPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (isSearching)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (searchResults.isEmpty)
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
                        'No doctors found for your search',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else
                  ...searchResults.take(3).map((doctor) => // Show only first 3 results
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildDoctorCard(doctor['doctorId'], doctor),
                  )),

                const SizedBox(height: 25),
              ],

              // Main Services (only show when not searching)
              if (!showSearchResults) ...[
                const Text(
                  "Services",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCategory(
                        context, Icons.calendar_month, "Booking\nAppointment",
                        Colors.blue),
                    _buildCategory(context, Icons.history, "Appointment\nHistory",
                        Colors.green),
                    _buildCategory(
                        context, Icons.medical_information, "Medical\nRecord",
                        Colors.purple),
                    _buildCategory(context, Icons.home_work, "HomeCare\nServices",
                        Colors.orange),
                  ],
                ),
                const SizedBox(height: 20),

                // Additional Services
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCategory(
                        context, Icons.person_search, "HomeCare\nHistory",
                        Colors.teal),
                    _buildCategory(
                        context, Icons.local_hospital, "List of\nHospitals",
                        Colors.red),
                    _buildCategory(context, Icons.account_circle, "User\nProfile",
                        Colors.indigo),
                    _buildCategory(
                        context, Icons.feedback, "Feedback/\nContact Us",
                        Colors.amber),
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
                else
                  if (popularDoctors.isEmpty)
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
                    ...popularDoctors.map((doctor) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildDoctorCard(doctor['doctorId'], doctor),
                        )),
              ],

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
              // Home - already here
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

  Widget _buildCategory(BuildContext context, IconData icon, String title,
      Color color) {
    return GestureDetector(
      onTap: () {
        // Handle navigation based on title
        if (title.contains("Booking\nAppointment")) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookAppointmentPage()),
          );
        } else if (title.contains("Appointment\nHistory")) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AppointmentHistoryPage()),
          );
        } else if (title.contains("Medical")) {
          // Navigate to medical records
        } else if (title.contains("HomeCare\nServices")) {
          // Navigate to nurse services
          Navigator.pushNamed(context, '/home-care');
        } else if (title.contains("HomeCare\nHistory")) {
          // Navigate to booking history
          Navigator.pushNamed(context, '/booking-history');
        } else if (title.contains("Hospital")) {
          // Navigate to hospital list
          Navigator.pushNamed(context, '/hospitals');
        } else if (title.contains("Profile")) {
          // Navigate to user profile
          Navigator.pushNamed(context, '/profile');
        } else if (title.contains("Feedback")) {
          // Navigate to feedback/contact us
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ContactFeedbackPage()),
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
                        color: isFavorite ? Colors.red.shade50 : Colors.grey
                            .shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red.shade400 : Colors.grey
                            .shade400,
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