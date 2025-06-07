import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AppointmentHistoryPage extends StatefulWidget {
  const AppointmentHistoryPage({super.key});

  @override
  State<AppointmentHistoryPage> createState() => _AppointmentHistoryPageState();
}

class _AppointmentHistoryPageState extends State<AppointmentHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _historyAppointments = [];
  List<Map<String, dynamic>> _cancelledAppointments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final upcoming = <Map<String, dynamic>>[];
      final history = <Map<String, dynamic>>[];
      final cancelled = <Map<String, dynamic>>[];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        final appointmentDate = DateTime.parse(data['appointmentDate']);
        final status = data['status'] as String;

        if (status == 'cancelled') {
          cancelled.add(data);
        } else if (appointmentDate.isAfter(today) ||
            (appointmentDate.isAtSameMomentAs(today) && status == 'pending')) {
          upcoming.add(data);
        } else {
          history.add(data);
        }
      }

      setState(() {
        _upcomingAppointments = upcoming;
        _historyAppointments = history;
        _cancelledAppointments = cancelled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Use debugPrint instead of print for better debugging
      debugPrint('Error fetching appointments: $e');
    }
  }

  // Check if appointment can be cancelled (24 hours before appointment)
  bool _canCancelAppointment(String appointmentDateStr) {
    final appointmentDate = DateTime.parse(appointmentDateStr);
    final now = DateTime.now();
    final timeDifference = appointmentDate.difference(now);

    // Allow cancellation only if appointment is more than 24 hours away
    return timeDifference.inHours >= 24;
  }

  Future<void> _cancelAppointment(String appointmentId, String doctorName, String appointmentDate) async {
    // Check if appointment can be cancelled
    if (!_canCancelAppointment(appointmentDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot cancel within 24 hours of appointment'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final reason = await _showCancelConfirmationDialog(doctorName);
    if (reason == null || reason.isEmpty) return;

    try {
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the appointments
      _fetchAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error cancelling appointment'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error cancelling appointment: $e');
    }
  }

  Future<String?> _showCancelConfirmationDialog(String doctorName) async {
    final TextEditingController reasonController = TextEditingController();
    String? selectedReason;

    final predefinedReasons = [
      'Schedule conflict',
      'Feeling better',
      'Emergency came up',
      'Doctor unavailable',
      'Transportation issues',
      'Personal reasons',
      'Other',
    ];

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          size: 40,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Cancel Appointment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appointment with $doctorName will be cancelled',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Reason for cancellation:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Predefined reason dropdown
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedReason,
                            hint: const Text('Select a reason'),
                            isExpanded: true,
                            items: predefinedReasons.map((String reason) {
                              return DropdownMenuItem<String>(
                                value: reason,
                                child: Text(reason),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedReason = newValue;
                                if (newValue != 'Other') {
                                  reasonController.clear();
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      // Custom reason text field (shown when "Other" is selected)
                      if (selectedReason == 'Other') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Please specify your reason...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: const BorderSide(color: Colors.grey),
                              ),
                              child: const Text(
                                'Keep',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                String reason = '';
                                if (selectedReason == 'Other') {
                                  reason = reasonController.text.trim();
                                } else if (selectedReason != null) {
                                  reason = selectedReason!;
                                }

                                if (reason.isNotEmpty) {
                                  Navigator.of(context).pop(reason);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please select or enter a reason'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
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
      },
    );
  }

  Widget _buildDoctorAvatar(String? doctorImageUrl) {
    if (doctorImageUrl != null && doctorImageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          doctorImageUrl,
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
                Icons.person,
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
          Icons.person,
          color: Colors.blue.shade600,
          size: 25,
        ),
      );
    }
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, {bool showCancelButton = false}) {
    final appointmentDate = DateTime.parse(appointment['appointmentDate']);
    final formattedDate = DateFormat('EEE, dd MMM').format(appointmentDate);
    final timeSlot = appointment['timeSlot'] as String;
    final doctorImageUrl = appointment['doctorimg'] as String?;

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
              _buildDoctorAvatar(doctorImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['doctorName'] ?? 'Dr. Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment['doctorSpecialization'] ?? 'Specialist',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$formattedDate | $timeSlot',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to chat or message
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (showCancelButton) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelAppointment(
                  appointment['id'],
                  appointment['doctorName'] ?? 'Doctor',
                  appointment['appointmentDate'],
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: Colors.blue),
                ),
                child: const Text(
                  'Cancel Appointment',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(List<Map<String, dynamic>> appointments, {bool showCancelButton = false}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No appointments found',
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
      onRefresh: _fetchAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          return _buildAppointmentCard(
            appointments[index],
            showCancelButton: showCancelButton,
          );
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
          'My Appointment',
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
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentsList(_upcomingAppointments, showCancelButton: true),
          _buildAppointmentsList(_historyAppointments),
          _buildAppointmentsList(_cancelledAppointments),
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
          currentIndex: 1, // Set to appointments tab
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
            switch (index) {
              case 0:
                Navigator.popUntil(context, (route) => route.isFirst);
                break;
              case 1:
              // Already on appointments page
                break;
              case 2:
              // Navigate to Medical Records
                break;
              case 3:
              // Navigate to Profile
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
}