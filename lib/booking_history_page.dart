import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'favorites_page.dart';
import 'appointment_history_page.dart';
import 'medical_record_page.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _historyBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('booking')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final upcoming = <Map<String, dynamic>>[];
      final history = <Map<String, dynamic>>[];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // Get the earliest date from selectedDates array
        final selectedDates = data['selectedDates'] as List<dynamic>?;
        DateTime? earliestDate;

        if (selectedDates != null && selectedDates.isNotEmpty) {
          // Parse all dates and find the earliest one
          final dates = selectedDates
              .map((dateStr) => DateTime.parse(dateStr as String))
              .toList();
          dates.sort();
          earliestDate = dates.first;
        } else {
          // Skip this booking if no selectedDates available
          continue;
        }

        if (earliestDate.isAfter(today) || earliestDate.isAtSameMomentAs(today)) {
          upcoming.add(data);
        } else {
          history.add(data);
        }
      }

      setState(() {
        _upcomingBookings = upcoming;
        _historyBookings = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error fetching bookings: $e');
    }
  }

  Widget _buildNurseAvatar(String? nurseImageUrl) {
    if (nurseImageUrl != null && nurseImageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          nurseImageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.local_hospital,
                color: Colors.blue.shade600,
                size: 25,
              ),
            );
          },
        ),
      );
    } else {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.blue.shade100,
        child: Icon(
          Icons.local_hospital,
          color: Colors.blue.shade600,
          size: 25,
        ),
      );
    }
  }

  String _getServiceTypeDisplay(String serviceType) {
    switch (serviceType) {
      case 'home_care':
        return 'Home Care';
      case 'clinic':
        return 'Clinic Visit';
      default:
        return 'Service';
    }
  }

  String _getFormattedDates(Map<String, dynamic> booking) {
    final selectedDates = booking['selectedDates'] as List<dynamic>?;

    if (selectedDates == null || selectedDates.isEmpty) {
      return 'Date not available';
    }

    final dates = selectedDates
        .map((dateStr) => DateTime.parse(dateStr as String))
        .toList();
    dates.sort();

    // Single date
    if (dates.length == 1) {
      return DateFormat('EEE, dd MMM yyyy').format(dates.first);
    }

    // Multiple dates - check if consecutive
    bool isConsecutive = true;
    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays != 1) {
        isConsecutive = false;
        break;
      }
    }

    if (isConsecutive) {
      // Consecutive dates: "02 Jul - 04 Jul 2025"
      if (dates.first.year == dates.last.year) {
        final firstDate = DateFormat('dd MMM').format(dates.first);
        final lastDate = DateFormat('dd MMM yyyy').format(dates.last);
        return '$firstDate - $lastDate';
      } else {
        // Different years
        final firstDate = DateFormat('dd MMM yyyy').format(dates.first);
        final lastDate = DateFormat('dd MMM yyyy').format(dates.last);
        return '$firstDate - $lastDate';
      }
    } else {
      // Non-consecutive dates: "02 Jul 2025 (+2 more)"
      final firstDate = DateFormat('dd MMM yyyy').format(dates.first);
      final additionalCount = dates.length - 1;
      return '$firstDate (+$additionalCount more)';
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final formattedDate = _getFormattedDates(booking);
    final timeSlot = booking['timeSlot'] as String;
    final nurseImageUrl = booking['nurseImg'] as String?;
    final serviceType = booking['serviceType'] as String? ?? 'home_care';
    final status = booking['status'] as String? ?? 'confirmed';
    final totalDays = booking['totalDays'] as int? ?? 1;
    final totalAmount = booking['totalAmount'] as num? ?? 0;

    return Container(
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
              _buildNurseAvatar(nurseImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking['nurseName'] ?? 'Nurse Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking['nurseSpecialization'] ?? 'Healthcare Specialist',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking['nurseHospital'] ?? 'Healthcare Center',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedDate | $timeSlot',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status aligned to far right
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      serviceType == 'home_care' ? Icons.home : Icons.local_hospital,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getServiceTypeDisplay(serviceType),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const Spacer(),
                    if (totalDays > 1)
                      Text(
                        '$totalDays days',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'RM ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                // Show payment status if available
                if (booking['paymentDetails'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PAID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Show booking details
                _showBookingDetails(booking);
              },
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final selectedDates = booking['selectedDates'] as List<dynamic>?;
        final patientDetails = booking['patientDetails'] as Map<String, dynamic>?;
        final paymentDetails = booking['paymentDetails'] as Map<String, dynamic>?;
        final status = booking['status'] as String? ?? 'confirmed';

        String formattedDateDisplay = '';
        if (selectedDates != null && selectedDates.isNotEmpty) {
          if (selectedDates.length == 1) {
            final date = DateTime.parse(selectedDates[0] as String);
            formattedDateDisplay = DateFormat('EEEE, dd MMMM yyyy').format(date);
          } else {
            final dates = selectedDates
                .map((dateStr) => DateTime.parse(dateStr as String))
                .toList();
            dates.sort();
            formattedDateDisplay = 'Multiple dates (${dates.length} days)';
          }
        } else {
          formattedDateDisplay = 'Date not available';
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Booking Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nurse Information
                  Row(
                    children: [
                      _buildNurseAvatar(booking['nurseImg']),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['nurseName'] ?? 'Nurse Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              booking['nurseSpecialization'] ?? 'Healthcare Specialist',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              booking['nurseHospital'] ?? 'Healthcare Center',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Booking Information
                  _buildDetailRow('Service Type', _getServiceTypeDisplay(booking['serviceType'] ?? 'home_care')),
                  _buildDetailRow('Date', formattedDateDisplay),
                  _buildDetailRow('Time', booking['timeSlot'] ?? 'Not specified'),

                  if (booking['totalDays'] != null && booking['totalDays'] > 1)
                    _buildDetailRow('Duration', '${booking['totalDays']} days'),

                  if (selectedDates != null && selectedDates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Service Dates:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...selectedDates.map((date) => Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 2),
                      child: Text(
                        '• ${DateFormat('EEEE, dd MMM yyyy').format(DateTime.parse(date))}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Patient Details
                  if (patientDetails != null) ...[
                    const Text(
                      'Patient Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name', patientDetails['name'] ?? 'Not provided'),
                    _buildDetailRow('Gender', patientDetails['gender'] ?? 'Not provided'),
                    if (patientDetails['problem'] != null)
                      _buildDetailRow('Health Issue', patientDetails['problem']),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  // Payment Information
                  if (paymentDetails != null) ...[
                    const Text(
                      'Payment Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Amount', 'RM ${booking['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
                    _buildDetailRow('Payment Method', paymentDetails['paymentMethod'] ?? 'Not specified'),
                    _buildDetailRow('Transaction ID', paymentDetails['transactionId'] ?? 'Not available'),
                    _buildDetailRow('Status', paymentDetails['status']?.toUpperCase() ?? 'UNKNOWN'),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  // Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Booking Status:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No bookings found',
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
      onRefresh: _fetchBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(bookings[index]);
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
          'My Bookings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(_upcomingBookings),
          _buildBookingsList(_historyBookings),
        ],
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
}