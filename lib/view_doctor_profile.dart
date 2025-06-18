import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_datetime_page.dart';

class ViewDoctorProfilePage extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;

  const ViewDoctorProfilePage({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  @override
  State<ViewDoctorProfilePage> createState() => _ViewDoctorProfilePageState();
}

class _ViewDoctorProfilePageState extends State<ViewDoctorProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  Future<void> _toggleFavorite() async {
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
          .doc(widget.doctorId);

      final doc = await favoriteRef.get();
      final doctorName = widget.doctorData['name'] ?? 'Unknown Doctor';

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
          'doctorId': widget.doctorId,
          'name': doctorName,
          'specialization': widget.doctorData['specialization'] ?? '',
          'hospital': widget.doctorData['hospital'] ?? '',
          'imageUrl': widget.doctorData['imageUrl'] ?? '',
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
  void _navigateToSelectDateTime() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectDateTimePage(
          doctorId: widget.doctorId,
          doctorData: widget.doctorData,
        ),
      ),
    );
  }

  // Format weekly sessions for better display with morning/afternoon separation
  Widget _buildWeeklySchedule() {
    final weeklySessions = widget.doctorData['weeklySessions'] as Map<String, dynamic>?;
    if (weeklySessions == null || weeklySessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No schedule available',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        // Table header
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Table(
            children: [
              TableRow(
                children: [
                  _buildTableHeader('Day'),
                  _buildTableHeader('Morning'),
                  _buildTableHeader('Afternoon'),
                ],
              ),
            ],
          ),
        ),
        // Table body
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Table(
            children: List.generate(dayOrder.length, (index) {
              final day = dayOrder[index];
              final dayShort = dayAbbr[index];
              final sessions = weeklySessions[day] as List<dynamic>?;

              String morningSlots = '-';
              String afternoonSlots = '-';

              if (sessions != null && sessions.isNotEmpty) {
                final List<String> morning = [];
                final List<String> afternoon = [];

                for (int i = 0; i < sessions.length; i++) {
                  final session = sessions[i];
                  final start = session['start'] ?? '';
                  final end = session['end'] ?? '';

                  if (start.isNotEmpty && end.isNotEmpty) {
                    final timeSlot = '$start - $end';
                    // Index 0 = morning, Index 1 = afternoon
                    if (i == 0) {
                      morning.add(timeSlot);
                    } else if (i == 1) {
                      afternoon.add(timeSlot);
                    }
                  }
                }

                morningSlots = morning.isEmpty ? '-' : morning.join('\n');
                afternoonSlots = afternoon.isEmpty ? '-' : afternoon.join('\n');
              }

              return TableRow(
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                ),
                children: [
                  _buildTableCell(dayShort, isDay: true),
                  _buildTableCell(morningSlots),
                  _buildTableCell(afternoonSlots),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isDay = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDay ? Colors.black87 : Colors.grey.shade700,
          fontWeight: isDay ? FontWeight.w600 : FontWeight.normal,
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.doctorData['name'] ?? 'Unknown Doctor';
    final specialization = widget.doctorData['specialization'] ?? 'General';
    final hospital = widget.doctorData['hospital'] ?? 'Unknown Hospital';
    final imageUrl = widget.doctorData['imageUrl'] ?? '';
    final email = widget.doctorData['email'] ?? 'Not available';
    final phone = widget.doctorData['phone'] ?? 'Not available';
    final doctorId = widget.doctorData['doctorId'] ?? 'Not available';

    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF5FF),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Doctor Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // Favorite button
          FutureBuilder<bool>(
            future: _isFavorite(widget.doctorId),
            builder: (context, snapshot) {
              final isFavorite = snapshot.data ?? false;
              return IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Doctor Info Card - Fixed width like other cards
            Container(
              width: double.infinity, // Fixed: Ensures consistent width
              margin: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Doctor Image
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        color: Colors.grey.shade200,
                      ),
                      child: imageUrl.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 60,
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
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Doctor Name - Fixed: Added proper text wrapping
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Specialization
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Specialist $specialization',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contact Information Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Doctor ID
                    _buildInfoRow(Icons.badge, 'Doctor ID', doctorId),
                    const SizedBox(height: 12),

                    // Hospital
                    _buildInfoRow(Icons.local_hospital, 'Hospital', hospital),
                    const SizedBox(height: 12),

                    // Phone
                    _buildInfoRow(Icons.phone, 'Phone', phone),
                    const SizedBox(height: 12),

                    // Email
                    _buildInfoRow(Icons.email, 'Email', email),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Schedule Card - Improved with table format
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Schedule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildWeeklySchedule(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
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
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _navigateToSelectDateTime,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Book Appointment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.blue.shade400,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}