import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentPage extends StatefulWidget {
  final String nurseId;
  final Map<String, dynamic> nurseData;
  final Map<String, dynamic> patientDetails;
  final DateTime selectedDate;
  final String selectedTimeSlot;

  const PaymentPage({
    Key? key,
    required this.nurseId,
    required this.nurseData,
    required this.patientDetails,
    required this.selectedDate,
    required this.selectedTimeSlot,
  }) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stripe Configuration
  final stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
  final stripeSecretKey = dotenv.env['STRIPE_SECRET_KEY'];

  // EmailJS Configuration
  static const String emailJsServiceId = 'service_l113wb3';
  static const String emailJsTemplateId = 'template_9w5ecvf';
  static const String emailJsUserId = 'pNemZGNH8hqchwaCK';

  String _selectedPaymentMethod = 'card';
  bool _isProcessingPayment = false;
  bool _showOtpField = false;
  String _generatedOtp = '';

  @override
  void initState() {
    super.initState();
    _initializeStripe();
  }

  void _initializeStripe() {
    if (!kIsWeb) {
      Stripe.publishableKey = stripePublishableKey;
    }
  }

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();

  // OTP controller
  final TextEditingController _otpController = TextEditingController();

  // Online banking controllers
  final TextEditingController _bankAccountController = TextEditingController();

  // E-wallet controllers
  final TextEditingController _ewalletController = TextEditingController();

  @override
  void dispose() {
    _bankAccountController.dispose();
    _ewalletController.dispose();
    _otpController.dispose();
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  // Calculate totals
  double get servicePrice {
    if (widget.nurseData['selectedDates'] != null) {
      final selectedDates = widget.nurseData['selectedDates'] as List;
      final pricePerDay = (widget.nurseData['price'] ?? 0).toDouble();
      return pricePerDay * selectedDates.length;
    }
    return (widget.nurseData['price'] ?? 0).toDouble();
  }

  double get transportationFee => 20.0;
  double get totalAmount => servicePrice + transportationFee;

  int get totalDays {
    if (widget.nurseData['selectedDates'] != null) {
      final selectedDates = widget.nurseData['selectedDates'] as List;
      return selectedDates.length;
    }
    return 1;
  }

  // Generate random OTP
  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Format card number with spaces
  String _formatCardNumber(String value) {
    value = value.replaceAll(' ', '');
    String formatted = '';
    for (int i = 0; i < value.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += value[i];
    }
    return formatted;
  }

  // Format expiry date
  String _formatExpiryDate(String value) {
    value = value.replaceAll('/', '');
    if (value.length >= 2) {
      return '${value.substring(0, 2)}/${value.substring(2)}';
    }
    return value;
  }

  bool _isValidCardNumber(String cardNumber) {
    cardNumber = cardNumber.replaceAll(' ', '');
    if (cardNumber.length < 13 || cardNumber.length > 19) return false;

    // Luhn algorithm
    int sum = 0;
    bool alternate = false;
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  bool _isValidExpiryDate(String expiry) {
    if (expiry.length != 5) return false;
    final parts = expiry.split('/');
    if (parts.length != 2) return false;

    final month = int.tryParse(parts[0]);
    final year = int.tryParse('20${parts[1]}');

    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;

    final now = DateTime.now();
    final expiryDate = DateTime(year, month);
    return expiryDate.isAfter(DateTime(now.year, now.month));
  }

  bool _isValidCVV(String cvv) {
    return cvv.length >= 3 && cvv.length <= 4 && int.tryParse(cvv) != null;
  }

  String _getCardType(String cardNumber) {
    cardNumber = cardNumber.replaceAll(' ', '');
    if (cardNumber.startsWith('4')) return 'Visa';
    if (cardNumber.startsWith(RegExp(r'^5[1-5]')) || cardNumber.startsWith(RegExp(r'^2[2-7]'))) return 'Mastercard';
    if (cardNumber.startsWith(RegExp(r'^3[47]'))) return 'American Express';
    return 'Unknown';
  }

  // Send OTP via EmailJS
  Future<bool> _sendOtpViaEmail() async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        _showErrorSnackBar('User email not found');
        return false;
      }

      _generatedOtp = _generateOtp();

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': emailJsServiceId,
          'template_id': emailJsTemplateId,
          'user_id': emailJsUserId,
          'template_params': {
            'to_email': user!.email,
            'to_name': widget.patientDetails['name'] ?? 'Patient',
            'otp_code': _generatedOtp,
            'amount': totalAmount.toStringAsFixed(2),
            'nurse_name': widget.nurseData['name'] ?? 'nurse',
          },
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('EmailJS Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  // Create Stripe Payment Intent (Mock implementation)
  Future<Map<String, dynamic>> _createStripePaymentIntent() async {
    try {
      final url = Uri.parse('https://api.stripe.com/v1/payment_intents');
      final amount = (totalAmount * 100).round(); // Convert to cents

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount.toString(),
          'currency': 'myr',
          'payment_method_types[]': 'card',
          'metadata[nurse_id]': widget.nurseId,
          'metadata[patient_name]': widget.patientDetails['name'] ?? '',
        },
      );

      print('Stripe API Response Status: ${response.statusCode}');
      print('Stripe API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'client_secret': responseData['client_secret'],
          'payment_intent_id': responseData['id'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error']?['message'] ?? 'Failed to create payment intent',
        };
      }
    } catch (e) {
      print('Create payment intent error: $e');
      return {
        'success': false,
        'error': 'Network error: Unable to connect to payment service',
      };
    }
  }

  // Process card payment with Stripe
  Future<Map<String, dynamic>> _processStripePayment() async {
    try {
      if (kIsWeb) {
        // For web, use a test payment method token
        final paymentIntentResult = await _createStripePaymentIntent();
        if (!paymentIntentResult['success']) {
          return paymentIntentResult;
        }

        // Use test payment method instead of raw card data
        final confirmResult = await _confirmPaymentIntentWithTestToken(
            paymentIntentResult['payment_intent_id'],
            paymentIntentResult['client_secret']
        );

        if (confirmResult['success']) {
          return {
            'success': true,
            'transactionId': paymentIntentResult['payment_intent_id'],
            'paymentMethod': 'card',
            'amount': totalAmount,
          };
        } else {
          return confirmResult;
        }
      } else {
        // Mobile implementation remains the same
        final paymentIntentResult = await _createStripePaymentIntent();
        if (!paymentIntentResult['success']) {
          return paymentIntentResult;
        }

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentResult['client_secret'],
            style: ThemeMode.light,
            merchantDisplayName: 'Healthcare App',
            appearance: const PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: Colors.blue,
              ),
            ),
          ),
        );

        await Stripe.instance.presentPaymentSheet();

        return {
          'success': true,
          'transactionId': paymentIntentResult['payment_intent_id'],
          'paymentMethod': 'card',
          'amount': totalAmount,
        };
      }

    } on StripeException catch (e) {
      String errorMessage;
      switch (e.error.code) {
        case FailureCode.Canceled:
          errorMessage = 'Payment was cancelled';
          break;
        case FailureCode.Failed:
          errorMessage = 'Payment failed. Please try again.';
          break;
        case FailureCode.Timeout:
          errorMessage = 'Payment timed out. Please try again.';
          break;
        default:
          errorMessage = e.error.message ?? 'Payment failed. Please try again.';
      }

      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      print('Payment processing error: $e');
      return {
        'success': false,
        'error': 'Unable to process payment. Please check your card details and try again.',
      };
    }
  }

  Future<Map<String, dynamic>> _confirmPaymentIntentWithTestToken(String paymentIntentId, String clientSecret) async {
    try {
      final url = Uri.parse('https://api.stripe.com/v1/payment_intents/$paymentIntentId/confirm');

      // Use test payment method tokens instead of raw card data
      String testPaymentMethod;

      // Determine test payment method based on card number
      final cardNumber = _cardNumberController.text.replaceAll(' ', '');
      if (cardNumber.startsWith('4242')) {
        testPaymentMethod = 'pm_card_visa'; // Visa test token
      } else if (cardNumber.startsWith('5555')) {
        testPaymentMethod = 'pm_card_mastercard';
      } else if (cardNumber.startsWith('3782')) {
        testPaymentMethod = 'pm_card_amex';
      } else {
        testPaymentMethod = 'pm_card_visa';
      }

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'payment_method': testPaymentMethod,
        },
      );

      print('Confirm Payment Response Status: ${response.statusCode}');
      print('Confirm Payment Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'succeeded') {
          return {
            'success': true,
            'payment_intent_id': responseData['id'],
            'status': responseData['status'],
          };
        } else {
          return {
            'success': false,
            'error': 'Payment not completed. Status: ${responseData['status']}',
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error']?['message'] ?? 'Failed to confirm payment',
        };
      }
    } catch (e) {
      print('Confirm payment error: $e');
      return {
        'success': false,
        'error': 'Error confirming payment: $e',
      };
    }
  }


  Future<void> _processPayment() async {
    if (!_validatePaymentForm()) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      if (_selectedPaymentMethod == 'card') {
        if (!_showOtpField) {
          // Step 1: Send OTP for card payments
          print('Sending OTP...');
          final otpSent = await _sendOtpViaEmail();
          if (otpSent) {
            setState(() {
              _showOtpField = true;
              _isProcessingPayment = false;
            });
            _showSuccessSnackBar('OTP sent to your email. Please check and enter it.');
            return;
          } else {
            setState(() {
              _isProcessingPayment = false;
            });
            _showPaymentFailedDialog('Failed to send OTP. Please try again.');
            return;
          }
        } else {
          // Step 2: Process Stripe payment after OTP verification
          print('Processing Stripe payment...');
          final paymentResult = await _processStripePayment();

          if (paymentResult['success']) {
            print('Payment successful, saving booking...');
            await _saveBookingWithPayment(paymentResult['transactionId']);
            _showSuccessDialog();
          } else {
            _showPaymentFailedDialog(paymentResult['error']);
          }
        }
      } else {
        // Process other payment methods
        print('Processing ${_selectedPaymentMethod} payment...');
        final paymentResult = await _mockPaymentProcess();

        if (paymentResult['success']) {
          print('Payment successful, saving booking...');
          await _saveBookingWithPayment(paymentResult['transactionId']);
          _showSuccessDialog();
        } else {
          _showPaymentFailedDialog(paymentResult['error']);
        }
      }
    } catch (e) {
      print('Payment processing exception: $e');
      _showPaymentFailedDialog('Payment processing failed. Please try again.');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  Future<Map<String, dynamic>> _mockPaymentProcess() async {
    // Mock payment processing for non-card methods
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
        'error': 'Payment failed. Please try again.',
      };
    }
  }

  bool _validatePaymentForm() {
    switch (_selectedPaymentMethod) {
      case 'card':
        if (_showOtpField) {
          // Validate OTP
          if (_otpController.text.isEmpty || _otpController.text.length != 6) {
            _showErrorSnackBar('Please enter the 6-digit OTP');
            return false;
          }
          if (_otpController.text != _generatedOtp) {
            _showErrorSnackBar('Invalid OTP. Please try again.');
            return false;
          }
          return true;
        } else {
          // Initial card validation before sending OTP
          if (!_isValidCardNumber(_cardNumberController.text)) {
            _showErrorSnackBar('Please enter a valid card number');
            return false;
          }
          if (!_isValidExpiryDate(_expiryDateController.text)) {
            _showErrorSnackBar('Please enter a valid expiry date');
            return false;
          }
          if (!_isValidCVV(_cvvController.text)) {
            _showErrorSnackBar('Please enter a valid CVV');
            return false;
          }
          if (_cardHolderController.text.isEmpty) {
            _showErrorSnackBar('Please enter card holder name');
            return false;
          }
          return true;
        }

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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveBookingWithPayment(String transactionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final bookingData = {
      'userId': user.uid,
      'nurseId': widget.nurseId,
      'nurseName': widget.nurseData['name'],
      'nurseSpecialization': widget.nurseData['specialization'],
      'nurseHospital': widget.nurseData['hospital'],
      'nurseImg': widget.nurseData['imageUrl'],
      'nursePhone': widget.nurseData['phone'],
      'timeSlot': widget.selectedTimeSlot,
      'price': servicePrice,
      'transportationFee': transportationFee,
      'totalAmount': totalAmount,
      'status': 'confirmed',
      'serviceType': 'home_care',
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

    if (widget.nurseData['selectedDates'] != null) {
      bookingData['selectedDates'] = widget.nurseData['selectedDates'];
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
                const Text(
                  'Your Home Care Booking is Confirmed',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // nurse/Nurse Details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Healthcare Provider:'),
                          Text(
                            widget.nurseData['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Specialization
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Specialization:'),
                          Text(
                            widget.nurseData['specialization'] ?? 'General',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Start Date:'),
                          Text(
                            '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Duration for home care
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Duration:'),
                            Text(
                              '$totalDays days',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 12),
                      const Divider(thickness: 1),
                      const SizedBox(height: 8),

                      // Total Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Paid:',
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

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/userHome',
                            (route) => false,
                      );
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
          _showOtpField = false; // Reset OTP field when changing payment method
          _otpController.clear();
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
            // Card Number
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Card Number',
                hintText: '1234 1234 1234 1234',
                suffixIcon: _cardNumberController.text.isNotEmpty
                    ? Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getCardType(_cardNumberController.text),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _cardNumberController.text = _formatCardNumber(value);
                  _cardNumberController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _cardNumberController.text.length),
                  );
                });
              },
            ),
            const SizedBox(height: 16),

            // Expiry Date and CVV Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryDateController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Expiry',
                      hintText: 'MM/YY',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _expiryDateController.text = _formatExpiryDate(value);
                        _expiryDateController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _expiryDateController.text.length),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Holder Name
            TextField(
              controller: _cardHolderController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                labelText: 'Cardholder Name',
                hintText: 'John Doe',
              ),
              textCapitalization: TextCapitalization.words,
            ),

            // OTP Field (conditional)
            if (_showOtpField) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blue.shade200,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.08),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.security,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'OTP Verification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A 6-digit verification code has been sent to your email. Please enter it below to complete your payment.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        labelText: 'Enter OTP',
                        hintText: '123456',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.blue.shade600,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                        ),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Didn\'t receive the code?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            // Show loading state
                            setState(() {
                              _isProcessingPayment = true;
                            });

                            try {
                              final otpSent = await _sendOtpViaEmail();
                              if (otpSent) {
                                _showSuccessSnackBar('OTP has been resent to your email successfully!');
                                // Generate new OTP for the resend
                                _generatedOtp = _generateOtp();
                              } else {
                                _showErrorSnackBar('Failed to resend OTP. Please try again.');
                              }
                            } catch (e) {
                              _showErrorSnackBar('Error occurred while resending OTP. Please try again.');
                            } finally {
                              setState(() {
                                _isProcessingPayment = false;
                              });
                            }
                          },
                          child: Text(
                            'Resend',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
                              child: widget.nurseData['imageUrl'] != null &&
                                  widget.nurseData['imageUrl'].isNotEmpty
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  widget.nurseData['imageUrl'],
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
                                    widget.nurseData['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    widget.nurseData['specialization'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (totalDays > 1)
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
                                    totalDays > 1
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
                                  const Text('Transportation Fee'),
                                  Text('RM ${transportationFee.toStringAsFixed(2)}'),
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
                          subtitle: 'Visa, Mastercard, American Express (Stripe)',
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
                _showOtpField && _selectedPaymentMethod == 'card'
                    ? 'Verify & Pay - RM ${totalAmount.toStringAsFixed(2)}'
                    : _selectedPaymentMethod == 'card'
                    ? 'Send OTP - RM ${totalAmount.toStringAsFixed(2)}'
                    : 'Pay Now - RM ${totalAmount.toStringAsFixed(2)}',
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