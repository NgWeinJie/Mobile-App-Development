import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PaymentPage extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;
  final Map<String, dynamic> patientDetails;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final bool isHomeCare;

  const PaymentPage({
    Key? key,
    required this.doctorId,
    required this.doctorData,
    required this.patientDetails,
    required this.selectedDate,
    required this.selectedTimeSlot,
    this.isHomeCare = false,
  }) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedPaymentMethod = 'card';
  bool _isProcessingPayment = false;

  // Card payment controllers
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();

  // Online banking controllers
  final TextEditingController _bankAccountController = TextEditingController();

  // E-wallet controllers
  final TextEditingController _ewalletController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    _bankAccountController.dispose();
    _ewalletController.dispose();
    super.dispose();
  }

  // Calculate totals
  double get servicePrice {
    if (widget.isHomeCare && widget.doctorData['selectedDates'] != null) {
      final selectedDates = widget.doctorData['selectedDates'] as List;
      final pricePerDay = (widget.doctorData['price'] ?? 0).toDouble();
      return pricePerDay * selectedDates.length;
    }
    return (widget.doctorData['price'] ?? 0).toDouble();
  }

  double get serviceFee => 5.0; // Fixed service fee
  double get totalAmount => servicePrice + serviceFee;

  int get totalDays {
    if (widget.isHomeCare && widget.doctorData['selectedDates'] != null) {
      final selectedDates = widget.doctorData['selectedDates'] as List;
      return selectedDates.length;
    }
    return 1;
  }

  Future<void> _processPayment() async {
    if (!_validatePaymentForm()) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // In a real app, you would integrate with payment gateways like:
      // - Stripe, PayPal, Razorpay for international
      // - iPay88, MOLPay, Senangpay for Malaysia
      // - Touch 'n Go eWallet, Boost, GrabPay for e-wallets

      final paymentResult = await _mockPaymentProcess();

      if (paymentResult['success']) {
        await _saveBookingWithPayment(paymentResult['transactionId']);
        _showSuccessDialog();
      } else {
        _showPaymentFailedDialog(paymentResult['error']);
      }
    } catch (e) {
      _showPaymentFailedDialog('Payment processing failed. Please try again.');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  Future<Map<String, dynamic>> _mockPaymentProcess() async {
    // Mock payment processing - replace with actual payment gateway integration
    // This simulates different payment scenarios

    // 90% success rate for demo purposes
    final isSuccess = DateTime.now().millisecond % 10 != 0;

    if (isSuccess) {
      return {
        'success': true,
        'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
        'paymentMethod': _selectedPaymentMethod,
        'amount': totalAmount,
      };
    } else {
      return {
        'success': false,
        'error': 'Insufficient funds or invalid payment details',
      };
    }
  }

  bool _validatePaymentForm() {
    switch (_selectedPaymentMethod) {
      case 'card':
        if (_cardNumberController.text.isEmpty ||
            _expiryController.text.isEmpty ||
            _cvvController.text.isEmpty ||
            _cardHolderController.text.isEmpty) {
          _showErrorSnackBar('Please fill in all card details');
          return false;
        }
        // Add more card validation (Luhn algorithm, expiry date format, etc.)
        break;
      case 'online_banking':
        if (_bankAccountController.text.isEmpty) {
          _showErrorSnackBar('Please enter your bank account details');
          return false;
        }
        break;
      case 'ewallet':
        if (_ewalletController.text.isEmpty) {
          _showErrorSnackBar('Please enter your e-wallet details');
          return false;
        }
        break;
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveBookingWithPayment(String transactionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Prepare booking data with payment info
    final bookingData = {
      'userId': user.uid,
      'nurseId': widget.doctorId,
      'nurseName': widget.doctorData['name'],
      'nurseSpecialization': widget.doctorData['specialization'],
      'nurseHospital': widget.doctorData['hospital'],
      'nurseImg': widget.doctorData['imageUrl'],
      'nursePhone': widget.doctorData['phone'],
      'bookingDate': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      'timeSlot': widget.selectedTimeSlot,
      'price': servicePrice,
      'serviceFee': serviceFee,
      'totalAmount': totalAmount,
      'status': 'confirmed', // Changed from 'pending' since payment is completed
      'serviceType': widget.isHomeCare ? 'home_care' : 'clinic',
      'patientDetails': widget.patientDetails,
      'paymentDetails': {
        'transactionId': transactionId,
        'paymentMethod': _selectedPaymentMethod,
        'amount': totalAmount,
        'paidAt': FieldValue.serverTimestamp(),
        'status': 'paid',
      },
      'createdAt': FieldValue.serverTimestamp(),
    };

    // For multi-day home care, add selected dates info
    if (widget.isHomeCare && widget.doctorData['selectedDates'] != null) {
      bookingData['selectedDates'] = widget.doctorData['selectedDates'];
      bookingData['totalDays'] = totalDays;
    }

    await _firestore.collection('booking').add(bookingData);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 40,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isHomeCare
                      ? 'Your Home Care Booking is Confirmed'
                      : 'Your Appointment is Confirmed',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid:'),
                          Text(
                            'RM ${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (widget.isHomeCare && totalDays > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Duration:'),
                            Text('$totalDays days'),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to previous screen
                      Navigator.of(context).pop(); // Go back to booking page
                      Navigator.of(context).pop(); // Go back to home care list
                    },
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
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentFailedDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Failed'),
          content: Text(error),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.blue.shade700 : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    switch (_selectedPaymentMethod) {
      case 'card':
        return Column(
          children: [
            TextField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                hintText: '1234 5678 9012 3456',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryController,
                    decoration: const InputDecoration(
                      labelText: 'Expiry',
                      hintText: 'MM/YY',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cardHolderController,
              decoration: const InputDecoration(
                labelText: 'Cardholder Name',
                hintText: 'John Doe',
              ),
            ),
          ],
        );
      case 'online_banking':
        return Column(
          children: [
            TextField(
              controller: _bankAccountController,
              decoration: const InputDecoration(
                labelText: 'Bank Account Number',
                hintText: 'Enter your account number',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'You will be redirected to your bank\'s secure login page.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        );
      case 'ewallet':
        return Column(
          children: [
            TextField(
              controller: _ewalletController,
              decoration: const InputDecoration(
                labelText: 'E-Wallet Phone Number',
                hintText: '+60123456789',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'A payment request will be sent to your e-wallet app.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
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
          'Payment',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
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
                          'Booking Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
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
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.local_hospital,
                                      color: Colors.grey.shade400,
                                    );
                                  },
                                ),
                              )
                                  : Icon(
                                Icons.local_hospital,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.doctorData['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    widget.doctorData['specialization'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (widget.isHomeCare && totalDays > 1)
                                    Text(
                                      '$totalDays days service',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Price Breakdown
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.isHomeCare && totalDays > 1
                                        ? 'Service (${totalDays} days)'
                                        : 'Service Fee',
                                  ),
                                  Text('RM ${servicePrice.toStringAsFixed(2)}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Platform Fee'),
                                  Text('RM ${serviceFee.toStringAsFixed(2)}'),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'RM ${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
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

                  const SizedBox(height: 24),

                  // Payment Methods
                  Container(
                    padding: const EdgeInsets.all(20),
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
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildPaymentMethodCard(
                          value: 'card',
                          title: 'Credit/Debit Card',
                          subtitle: 'Visa, Mastercard, American Express',
                          icon: Icons.credit_card,
                        ),

                        _buildPaymentMethodCard(
                          value: 'online_banking',
                          title: 'Online Banking',
                          subtitle: 'Maybank, CIMB, Public Bank, etc.',
                          icon: Icons.account_balance,
                        ),

                        _buildPaymentMethodCard(
                          value: 'ewallet',
                          title: 'E-Wallet',
                          subtitle: 'Touch \'n Go, Boost, GrabPay',
                          icon: Icons.wallet,
                        ),

                        const SizedBox(height: 24),

                        // Payment Form
                        _buildPaymentForm(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pay Now Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                'Pay Now - RM ${totalAmount.toStringAsFixed(2)}',
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