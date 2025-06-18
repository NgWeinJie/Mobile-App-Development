import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorNewsPage extends StatelessWidget {
  const DoctorNewsPage({super.key});

  final List<Map<String, String>> _newsList = const [
    {
      'title': 'New Treatment Guidelines Released',
      'date': 'June 15, 2025',
      'summary':
      'The Ministry of Health has released new treatment guidelines for chronic illness care. Doctors are advised to familiarize themselves with the updates.',
      'url': 'https://www.freemalaysiatoday.com/category/nation/2025/05/13/task-force-to-examine-vape-use-among-students-says-dzulkefly',
    },
    {
      'title': 'AI in Diagnostics: A Game Changer',
      'date': 'June 10, 2025',
      'summary':
      'Artificial intelligence is rapidly transforming diagnostic procedures. Learn how to leverage AI tools in your daily workflow.',
      'url': 'https://www.channelnewsasia.com/brandstudio/IMAGINEAIHealthcare',
    },
    {
      'title': 'Covid-19 Variant Alert in Southeast Asia',
      'date': 'June 5, 2025',
      'summary':
      'A new variant has been detected. Doctors should follow updated SOPs and patient screening protocols.',
      'url': 'https://www.ndtv.com/video/new-covid-19-variants-lf-7-and-nb-1-8-1-detected-in-india-over-1000-active-cases-944710?utm_source=chatgpt.com',
    },
  ];

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text('Medical News'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _newsList.length,
        itemBuilder: (context, index) {
          final news = _newsList[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    news['date'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    news['summary'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        final url = news['url'];
                        if (url != null) {
                          _launchURL(context, url);
                        }
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                      child: const Text('Read more'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
