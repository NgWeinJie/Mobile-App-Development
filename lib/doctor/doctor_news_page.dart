import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DoctorNewsPage extends StatefulWidget {
  const DoctorNewsPage({super.key});

  @override
  _DoctorNewsPageState createState() => _DoctorNewsPageState();
}

class _DoctorNewsPageState extends State<DoctorNewsPage> {
  List<Map<String, dynamic>> _newsList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final String _apiUrl =
      'https://newsdata.io/api/1/latest?apikey=pub_0b4c15f4b64e49ba9a4dc626e29df0d9&q=health%20Malaysia&country=my';

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> fetchNews() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;

        setState(() {
          _newsList = results.map((item) {
            return {
              'title': item['title'] ?? 'No Title',
              'date': item['pubDate'] ?? '',
              'summary': item['description'] ?? 'No Summary',
              'url': item['link'] ?? '',
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load news');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch news. Please try again.';
        _isLoading = false;
      });
    }
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _newsList.length,
        itemBuilder: (context, index) {
          final news = _newsList[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.blue),
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
