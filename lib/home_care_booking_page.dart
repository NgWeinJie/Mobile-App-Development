import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'booking_details_page.dart';

class HomeCareBookingPage extends StatefulWidget {
  final String nurseId;
  final Map<String, dynamic> nurseData;

  const HomeCareBookingPage({
    super.key,
    required this.nurseId,
    required this.nurseData,
  });

  @override
  State<HomeCareBookingPage> createState() => _HomeCareBookingPageState();
}

class _HomeCareBookingPageState extends State<HomeCareBookingPage> {
  Set<DateTime> selectedDates = {}; // Changed to Set for multiple dates
  Set<String> bookedDates = {};
  bool isLoadingDates = false;
  bool isFavorite = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
    _checkFavoriteStatus();
  }

  // Check if nurse is in user's favorites
  Future<void> _checkFavoriteStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('nurses')
          .doc(widget.nurseId)
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
          .collection('nurses')
          .doc(widget.nurseId);

      if (isFavorite) {
        // Remove from favorites
        await favoriteRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${widget.nurseData['name'] ?? 'Nurse'} from favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Add to favorites
        await favoriteRef.set({
          'nurseId': widget.nurseId,
          'name': widget.nurseData['name'] ?? '',
          'specialization': widget.nurseData['specialization'] ?? '',
          'hospital': widget.nurseData['hospital'] ?? '',
          'imageUrl': widget.nurseData['imageUrl'] ?? '',
          'price': widget.nurseData['price'] ?? 0,
          'phone': widget.nurseData['phone'] ?? '',
          'addedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${widget.nurseData['name'] ?? 'Nurse'} to favorites'),
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

  // Load booked dates for this nurse
  Future<void> _loadBookedDates() async {
    setState(() {
      isLoadingDates = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('booking')
          .where('nurseId', isEqualTo: widget.nurseId)
          .get();

      // Only include dates that are not cancelled
      final bookedDatesSet = <String>{};

      for (final doc in querySnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String?;
        return status != 'cancelled';
      })) {
        final data = doc.data();
        final selectedDates = data['selectedDates'] as List?;

        if (selectedDates != null) {
          // Add all dates from the selectedDates array
          for (final date in selectedDates) {
            if (date is String) {
              bookedDatesSet.add(date);
            }
          }
        }
      }

      setState(() {
        bookedDates = bookedDatesSet;
        isLoadingDates = false;
      });
    } catch (e) {
      print('Error loading booked dates: $e');
      setState(() {
        bookedDates = {};
        isLoadingDates = false;
      });
    }
  }

  // Clear all selected dates
  void _clearSelectedDates() {
    setState(() {
      selectedDates.clear();
    });
  }

  // Select date range
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
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

    if (picked != null) {
      // Generate all dates in the range
      final rangeDates = <DateTime>{};
      DateTime current = picked.start;
      while (current.isBefore(picked.end) || current.isAtSameMomentAs(picked.end)) {
        // Check if date is not already booked
        final dateStr = DateFormat('yyyy-MM-dd').format(current);
        if (!bookedDates.contains(dateStr)) {
          rangeDates.add(DateTime(current.year, current.month, current.day));
        }
        current = current.add(const Duration(days: 1));
      }

      setState(() {
        selectedDates = rangeDates;
      });

      // Show message if some dates were skipped
      final totalDaysInRange = picked.end.difference(picked.start).inDays + 1;
      if (rangeDates.length < totalDaysInRange) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some dates were skipped as they are already booked'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<DateTime> _getNextSevenDays() {
    final days = <DateTime>[];
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    for (int i = 0; i < 7; i++) {
      days.add(DateTime(tomorrow.year, tomorrow.month, tomorrow.day + i));
    }

    return days;
  }

  // Toggle individual date selection
  void _toggleDateSelection(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (bookedDates.contains(dateStr)) {
      return; // Can't select booked dates
    }

    setState(() {
      if (selectedDates.contains(date)) {
        selectedDates.remove(date);
      } else {
        selectedDates.add(date);
      }
    });
  }

  // Calculate total price
  double get totalPrice {
    final pricePerDay = (widget.nurseData['price'] ?? 0).toDouble();
    return pricePerDay * selectedDates.length;
  }

  // Navigate to patient details page
  void _proceedToPatientDetails() {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to make a booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create a modified nurseData with selected dates info
    final modifiedNurseData = Map<String, dynamic>.from(widget.nurseData);
    modifiedNurseData['selectedDates'] = selectedDates.map((date) => DateFormat('yyyy-MM-dd').format(date)).toList();
    modifiedNurseData['totalDays'] = selectedDates.length;
    modifiedNurseData['totalPrice'] = totalPrice;

    // Navigate to patient details page with booking data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsPage(
          nurseId: widget.nurseId,
          nurseData: modifiedNurseData,
          selectedDate: selectedDates.first, // Pass first date for compatibility
          selectedTimeSlot: 'Full Day',
          isHomeCare: true,
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
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Book Home Care Service',
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
          // Nurse Info Card
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
                  child: widget.nurseData['imageUrl'] != null &&
                      widget.nurseData['imageUrl'].isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.nurseData['imageUrl'],
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.local_hospital,
                          size: 30,
                          color: Colors.grey.shade400,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nurseData['name'] ?? 'Unknown Nurse',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Specialist ${widget.nurseData['specialization'] ?? 'General'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${widget.nurseData['price'] ?? 0}/day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.nurseData['hospital'] ?? 'Unknown Hospital',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Favorite Button
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

          // Service Information Card
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
                  children: [
                    Icon(
                      Icons.home_work,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Multi-Day Home Care Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Full Day Service (8AM - 6PM)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select multiple days for continuous care',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
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

          const SizedBox(height: 16),

          // Date Selection Controls
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
                    const Text(
                      'Select Dates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _selectDateRange(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.date_range,
                                  color: Colors.green.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Range',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (selectedDates.isNotEmpty)
                          GestureDetector(
                            onTap: _clearSelectedDates,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.clear,
                                    color: Colors.red.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
                          'Tap individual dates or use "Range" to select multiple days. Same-day booking not allowed.',
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
                if (isLoadingDates)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _getNextSevenDays().length,
                      itemBuilder: (context, index) {
                        final date = _getNextSevenDays()[index];
                        final isSelected = selectedDates.contains(date);
                        final isTomorrow = DateFormat('yyyy-MM-dd').format(date) ==
                            DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
                        final dateStr = DateFormat('yyyy-MM-dd').format(date);
                        final isBooked = bookedDates.contains(dateStr);

                        return GestureDetector(
                          onTap: () => _toggleDateSelection(date),
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? Colors.grey.shade200
                                  : isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: isTomorrow && !isBooked
                                  ? Border.all(color: Colors.green, width: 2)
                                  : isSelected
                                  ? Border.all(color: Colors.blue.shade700, width: 2)
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        DateFormat('E').format(date),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isBooked
                                              ? Colors.grey.shade500
                                              : isSelected
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateFormat('d').format(date),
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: isBooked
                                              ? Colors.grey.shade500
                                              : isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
                                if (isSelected)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.blue.shade700,
                                      ),
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

          const Spacer(),

          // Selected Dates Summary
          if (selectedDates.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Dates (${selectedDates.length} day${selectedDates.length > 1 ? 's' : ''})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedDates.length == 1
                                  ? DateFormat('EEEE, MMMM d, yyyy').format(selectedDates.first)
                                  : '${DateFormat('MMM d').format(selectedDates.reduce((a, b) => a.isBefore(b) ? a : b))} - ${DateFormat('MMM d, yyyy').format(selectedDates.reduce((a, b) => a.isAfter(b) ? a : b))}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'RM ${totalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedDates.length > 1) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Total: ${selectedDates.length} days × RM ${widget.nurseData['price'] ?? 0} = RM ${totalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Book Service Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: selectedDates.isNotEmpty ? _proceedToPatientDetails : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedDates.isNotEmpty ? Colors.blue : Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                selectedDates.isEmpty
                    ? 'Select Dates to Continue'
                    : 'Book ${selectedDates.length} Day${selectedDates.length > 1 ? 's' : ''} Service',
                style: const TextStyle(
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