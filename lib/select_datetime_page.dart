import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'patient_details_page.dart'; // Import the patient details page

class SelectDateTimePage extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;

  const SelectDateTimePage({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  @override
  State<SelectDateTimePage> createState() => _SelectDateTimePageState();
}

class _SelectDateTimePageState extends State<SelectDateTimePage> {
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1)); // Start with tomorrow
  String? selectedTimeSlot;
  List<String> morningSlots = [];
  List<String> afternoonSlots = [];
  Set<String> bookedSlots = {};
  bool isLoadingSlots = false;
  bool isFavorite = false; // Track favorite status
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadAvailableTimeSlots();
    _checkFavoriteStatus(); // Check favorite status on init
  }

  // Check if doctor is in user's favorites
  Future<void> _checkFavoriteStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('doctors')
          .doc(widget.doctorId)
          .get();

      if (mounted) {
        setState(() {
          isFavorite = doc.exists;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
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

      if (isFavorite) {
        // Remove from favorites
        await favoriteRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${widget.doctorData['name'] ?? 'Doctor'} from favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Add to favorites
        await favoriteRef.set({
          'doctorId': widget.doctorId,
          'name': widget.doctorData['name'] ?? '',
          'specialization': widget.doctorData['specialization'] ?? '',
          'hospital': widget.doctorData['hospital'] ?? '',
          'imageUrl': widget.doctorData['imageUrl'] ?? '',
          'addedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${widget.doctorData['name'] ?? 'Doctor'} to favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Update the UI
      setState(() {
        isFavorite = !isFavorite;
      });
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

  Future<void> _loadAvailableTimeSlots() async {
    setState(() {
      isLoadingSlots = true;
    });

    final weeklySessions = widget.doctorData['weeklySessions'] as Map<String, dynamic>?;
    if (weeklySessions == null) {
      setState(() {
        morningSlots = [];
        afternoonSlots = [];
        bookedSlots = {};
        isLoadingSlots = false;
      });
      return;
    }

    // Get day name from selected date
    final dayName = DateFormat('EEEE').format(selectedDate);
    final sessions = weeklySessions[dayName] as List<dynamic>?;

    if (sessions == null || sessions.isEmpty) {
      setState(() {
        morningSlots = [];
        afternoonSlots = [];
        bookedSlots = {};
        isLoadingSlots = false;
      });
      return;
    }

    // Generate time slots for all sessions in the day
    List<String> allSlots = [];

    // Process sessions based on index (0 = morning, 1 = afternoon)
    for (int i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      if (session is Map<String, dynamic>) {
        final startTime = session['start'] as String?;
        final endTime = session['end'] as String?;

        if (startTime != null && endTime != null) {
          final slots = _generateTimeSlots(startTime, endTime);
          allSlots.addAll(slots);
        }
      }
    }

    // Get booked slots (excluding cancelled ones)
    final bookedSlotsSet = await _getBookedSlots(selectedDate);

    // Separate into morning and afternoon slots
    _separateTimeSlots(allSlots, sessions, bookedSlotsSet);
  }

  void _separateTimeSlots(List<String> allSlots, List<dynamic> sessions, Set<String> bookedSlotsSet) {
    List<String> morning = [];
    List<String> afternoon = [];

    // Process each session with its index
    for (int sessionIndex = 0; sessionIndex < sessions.length; sessionIndex++) {
      final session = sessions[sessionIndex];
      if (session is Map<String, dynamic>) {
        final startTime = session['start'] as String?;
        final endTime = session['end'] as String?;

        if (startTime != null && endTime != null) {
          final sessionSlots = _generateTimeSlots(startTime, endTime);

          // sessionIndex 0 = morning, sessionIndex 1 = afternoon
          if (sessionIndex == 0) {
            morning.addAll(sessionSlots);
          } else if (sessionIndex == 1) {
            afternoon.addAll(sessionSlots);
          }
        }
      }
    }

    // Sort slots
    morning.sort();
    afternoon.sort();

    setState(() {
      morningSlots = morning;
      afternoonSlots = afternoon;
      bookedSlots = bookedSlotsSet;
      selectedTimeSlot = null;
      isLoadingSlots = false;
    });
  }

  List<String> _generateTimeSlots(String startTime, String endTime) {
    final slots = <String>[];

    // Parse start and end times
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    int startHour = int.parse(startParts[0]);
    int endHour = int.parse(endParts[0]);

    // Generate hourly slots
    for (int hour = startHour; hour < endHour; hour++) {
      final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
      slots.add(timeSlot);
    }

    return slots;
  }

  // Updated method to exclude cancelled appointments
  Future<Set<String>> _getBookedSlots(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .where('appointmentDate', isEqualTo: dateStr)
          .get();

      // Only include slots that are not cancelled
      return querySnapshot.docs
          .where((doc) {
        final data = doc.data();
        final status = data['status'] as String?;
        // Only consider it booked if status is not 'cancelled'
        return status != 'cancelled';
      })
          .map((doc) => doc.data()['timeSlot'] as String)
          .toSet();
    } catch (e) {
      print('Error fetching booked slots: $e');
      return <String>{};
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)), // Start from tomorrow
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      await _loadAvailableTimeSlots();
    }
  }

  List<DateTime> _getNextSevenDays() {
    final days = <DateTime>[];
    final tomorrow = DateTime.now().add(const Duration(days: 1)); // Start from tomorrow

    for (int i = 0; i < 7; i++) {
      days.add(DateTime(tomorrow.year, tomorrow.month, tomorrow.day + i));
    }

    return days;
  }

  // Updated function to navigate to patient details instead of directly saving
  void _proceedToPatientDetails() {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to make an appointment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if the selected slot is booked (extra safety check)
    if (bookedSlots.contains(selectedTimeSlot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This time slot is already booked'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to patient details page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailsPage(
          doctorId: widget.doctorId,
          doctorData: widget.doctorData,
          selectedDate: selectedDate,
          selectedTimeSlot: selectedTimeSlot!,
        ),
      ),
    );
  }

  Widget _buildTimeSlotSection(String title, List<String> slots, IconData icon) {
    if (slots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final timeSlot = slots[index];
            final isSelected = selectedTimeSlot == timeSlot;
            final isBooked = bookedSlots.contains(timeSlot);

            return GestureDetector(
              onTap: isBooked ? null : () {
                setState(() {
                  selectedTimeSlot = timeSlot;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isBooked
                      ? Colors.grey.shade200
                      : isSelected
                      ? Colors.blue
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBooked
                        ? Colors.grey.shade300
                        : isSelected
                        ? Colors.blue
                        : Colors.blue.shade200,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        timeSlot,
                        style: TextStyle(
                          color: isBooked
                              ? Colors.grey.shade500
                              : isSelected
                              ? Colors.white
                              : Colors.blue.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isBooked)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
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
          'Select Date And Time',
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
          // Doctor Info Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                  ),
                  child: widget.doctorData['imageUrl'] != null &&
                      widget.doctorData['imageUrl'].isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.doctorData['imageUrl'],
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.grey.shade400,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doctorData['name'] ?? 'Unknown Doctor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.doctorData['specialization'] ?? 'General',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.doctorData['hospital'] ?? 'Unknown Hospital',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dynamic Favorite Button
                GestureDetector(
                  onTap: _toggleFavorite,
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
                ),
              ],
            ),
          ),

          // Date Selection
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM yyyy').format(selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Booking restriction notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Same-day booking not allowed. Minimum 1-day advance booking required.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _getNextSevenDays().length,
                    itemBuilder: (context, index) {
                      final date = _getNextSevenDays()[index];
                      final isSelected = DateFormat('yyyy-MM-dd').format(date) ==
                          DateFormat('yyyy-MM-dd').format(selectedDate);
                      final isTomorrow = DateFormat('yyyy-MM-dd').format(date) ==
                          DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDate = date;
                          });
                          _loadAvailableTimeSlots();
                        },
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: isTomorrow
                                ? Border.all(color: Colors.green, width: 2)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('d').format(date),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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

          // Available Time Slots
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Time Slots',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingSlots)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (morningSlots.isEmpty && afternoonSlots.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No available slots for this date',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimeSlotSection(
                                'Morning',
                                morningSlots,
                                Icons.wb_sunny_outlined
                            ),
                            _buildTimeSlotSection(
                                'Afternoon',
                                afternoonSlots,
                                Icons.wb_sunny
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Make Appointment Button - Updated to navigate to patient details
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: selectedTimeSlot != null ? _proceedToPatientDetails : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Make Appointment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}