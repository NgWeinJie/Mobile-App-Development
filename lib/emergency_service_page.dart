import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyServicePage extends StatelessWidget {
  const EmergencyServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Service',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emergency Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.emergency,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "EMERGENCY CONTACT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "24/7 Available for urgent care",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Tap phone numbers to copy or navigation icon to get directions",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Hospital Emergency Contacts
              const Text(
                "Hospital Emergency Contacts",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Emergency Contact Cards
              Expanded(
                child: ListView(
                  children: [
                    _buildEmergencyCard(
                      context,
                      "Hospital Lam Wah Ee",
                      "Ambulance / Emergency",
                      "+604 118 5181",
                      "Penang, Malaysia",
                      Colors.blue,
                      "Hospital Lam Wah Ee, Penang, Malaysia",
                    ),
                    const SizedBox(height: 16),
                    _buildEmergencyCard(
                      context,
                      "Gleneagles Hospital Penang",
                      "Ambulance / Emergency",
                      "+604 188 1425",
                      "Penang, Malaysia",
                      Colors.green,
                      "Gleneagles Hospital Penang, Malaysia",
                    ),
                    const SizedBox(height: 16),
                    _buildEmergencyCard(
                      context,
                      "Island Hospital Penang",
                      "Ambulance / Emergency",
                      "+604 518 9111",
                      "Penang, Malaysia",
                      Colors.purple,
                      "Island Hospital Penang, Malaysia",
                    ),
                    const SizedBox(height: 16),
                    _buildEmergencyCard(
                      context,
                      "Pantai Hospital Penang",
                      "Ambulance / Emergency",
                      "+604 741 9421",
                      "Penang, Malaysia",
                      Colors.purple,
                      "Pantai Hospital Penang, Malaysia",
                    ),
                    const SizedBox(height: 16),
                    _buildEmergencyCard(
                      context,
                      "Penang Adventist Hospital",
                      "Ambulance / Emergency",
                      "+604 242 4252",
                      "Penang, Malaysia",
                      Colors.purple,
                      "Penang Adventist Hospital, Malaysia",
                    ),
                    const SizedBox(height: 16),

                    // General Emergency Numbers
                    _buildGeneralEmergencyCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Copy phone number to clipboard
  Future<void> _copyPhoneNumber(BuildContext context, String phoneNumber) async {
    await Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone number copied: $phoneNumber'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Emergency Contact Card Widget
  Widget _buildEmergencyCard(
      BuildContext context,
      String hospitalName,
      String serviceType,
      String phoneNumber,
      String location,
      Color accentColor,
      String navigationQuery,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Hospital Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_hospital,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Hospital Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospitalName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceType,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Phone Number and Action Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _copyPhoneNumber(context, phoneNumber),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          phoneNumber,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Icon(
                          Icons.copy,
                          color: Colors.red.shade400,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Navigation Button
              GestureDetector(
                onTap: () => _openNavigation(navigationQuery),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // General Emergency Numbers Card
  Widget _buildGeneralEmergencyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_in_talk,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "General Emergency Numbers",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Malaysia Emergency Numbers
          _buildEmergencyNumberRow(context, "Police", "999"),
          const SizedBox(height: 8),
          _buildEmergencyNumberRow(context, "Fire & Rescue", "994"),
          const SizedBox(height: 8),
          _buildEmergencyNumberRow(context, "General Emergency", "999"),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumberRow(BuildContext context, String service, String number) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          service,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () => _copyPhoneNumber(context, number),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.copy,
                  color: Colors.red.shade400,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Open Navigation Function
  Future<void> _openNavigation(String destination) async {
    final String encodedDestination = Uri.encodeComponent(destination);
    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedDestination');

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to generic maps URL
        final Uri fallbackUri = Uri.parse('geo:0,0?q=$encodedDestination');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          print('Could not launch navigation to $destination');
        }
      }
    } catch (e) {
      print('Error launching navigation: $e');
    }
  }
}