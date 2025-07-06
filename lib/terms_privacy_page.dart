import 'package:flutter/material.dart';

class TermsPrivacyDialog extends StatelessWidget {
  const TermsPrivacyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terms of Service & Privacy Policy'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SectionTitle(title: 'Terms of Service'),
              BulletList(items: [
                'Acceptance of Terms: By using HealthConnect, you agree to comply with these terms.',
                'User Eligibility: Users must be at least 18 years old.',
                'Account Security: Maintain the security of your account credentials.',
                'Data Usage and Privacy: Review our Privacy Policy for information on data collection and usage.',
                'Prohibited Activities: Users must not engage in illegal activities.',
                'Termination: HealthConnect reserves the right to terminate accounts for violations.',
              ]),
              SizedBox(height: 16),
              SectionTitle(title: 'Privacy Policy'),
              BulletList(items: [
                'Information Collection: We collect data to provide and enhance services.',
                'Data Security: Industry-standard measures protect your information.',
                'Third-Party Services: Check third-party privacy policies for integrated services.',
                'Cookies: Manage cookie preferences in your browser settings.',
                'Updates: The Privacy Policy may be updated.',
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
      ),
    );
  }
}

class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((item) => Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• "),
            Expanded(child: Text(item)),
          ],
        ),
      ))
          .toList(),
    );
  }
}
