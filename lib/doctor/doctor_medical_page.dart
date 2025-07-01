import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorMedicalPage extends StatefulWidget {
  const DoctorMedicalPage({super.key});

  @override
  State<DoctorMedicalPage> createState() => _DoctorMedicalPageState();
}

class _DoctorMedicalPageState extends State<DoctorMedicalPage> {
  final TextEditingController _searchController = TextEditingController();
  final int _limit = 5;

  List<DocumentSnapshot> _allRecords = [];
  List<DocumentSnapshot> _displayedRecords = [];
  List<DocumentSnapshot> _pageStarts = [];
  int _currentPage = 0;
  int _totalPages = 1;
  bool _isLoading = false;
  String _searchTerm = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTotalPages();
    _loadPage(0);

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        final term = _searchController.text.trim().toLowerCase();
        if (term != _searchTerm) {
          setState(() => _searchTerm = term);
          if (term.isNotEmpty) {
            _loadAllRecordsForSearch();
          } else {
            _loadPage(_currentPage);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTotalPages() async {
    final snapshot = await FirebaseFirestore.instance.collection('medical').get();
    final totalDocs = snapshot.docs.length;
    setState(() {
      _totalPages = (totalDocs / _limit).ceil();
    });
  }

  Future<void> _loadPage(int pageIndex) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance
        .collection('medical')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (pageIndex > 0 && _pageStarts.length > pageIndex - 1) {
      query = query.startAfterDocument(_pageStarts[pageIndex - 1]);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      if (_pageStarts.length <= pageIndex) {
        _pageStarts.add(snapshot.docs.last);
      }

      setState(() {
        _displayedRecords = snapshot.docs;
        _currentPage = pageIndex;
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadAllRecordsForSearch() async {
    setState(() => _isLoading = true);
    final snapshot = await FirebaseFirestore.instance
        .collection('medical')
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _allRecords = snapshot.docs;
      _displayedRecords = _filteredRecords;
      _isLoading = false;
    });
  }

  List<DocumentSnapshot> get _filteredRecords {
    return _allRecords.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final condition = (data['condition'] ?? '').toString().toLowerCase();

      return name.contains(_searchTerm) ||
          email.contains(_searchTerm) ||
          condition.contains(_searchTerm);
    }).toList();
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? '-')),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_searchTerm.isNotEmpty) return const SizedBox.shrink();

    const double buttonWidth = 130;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: buttonWidth,
            child: ElevatedButton(
              onPressed: _currentPage > 0 ? () => _loadPage(_currentPage - 1) : null,
              child: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 16),
          Text('Page ${_currentPage + 1} of $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          SizedBox(
            width: buttonWidth,
            child: ElevatedButton(
              onPressed: (_currentPage < _totalPages - 1) ? () => _loadPage(_currentPage + 1) : null,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecord(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this medical record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('medical').doc(docId).delete();
              Navigator.pop(context);
              _pageStarts.clear();
              await _loadTotalPages();
              _loadPage(_currentPage);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Medical record deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditMedicalDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final nameController = TextEditingController(text: data['name']);
    final genderController = TextEditingController(text: data['gender']);
    final emailController = TextEditingController(text: data['email']);
    final phoneController = TextEditingController(text: data['phone']);
    final specializationController = TextEditingController(text: data['specialization']);
    final notesController = TextEditingController(text: data['notes']);
    final conditionController = TextEditingController(text: data['condition']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Medical Record'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(nameController, 'Name'),
              _buildTextField(genderController, 'Gender'),
              _buildTextField(emailController, 'Email'),
              _buildTextField(phoneController, 'Phone'),
              _buildTextField(specializationController, 'Specialization'),
              _buildTextField(notesController, 'Notes'),
              _buildTextField(conditionController, 'Condition'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('medical').doc(doc.id).update({
                'name': nameController.text,
                'gender': genderController.text,
                'email': emailController.text,
                'phone': phoneController.text,
                'specialization': specializationController.text,
                'notes': notesController.text,
                'condition': conditionController.text,
              });
              Navigator.pop(context);
              _loadPage(_currentPage);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Medical record updated.')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAddMedicalDialog(BuildContext context) {
    final nameController = TextEditingController();
    final genderController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final specializationController = TextEditingController();
    final notesController = TextEditingController();
    final conditionController = TextEditingController();

    nameController.addListener(() async {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final fullName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}';
        if (fullName.toLowerCase() == name.toLowerCase()) {
          emailController.text = data['email'] ?? '';
          phoneController.text = data['phone'] ?? '';
          break;
        }
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medical Record'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(nameController, 'Name'),
              _buildTextField(genderController, 'Gender'),
              _buildTextField(emailController, 'Email'),
              _buildTextField(phoneController, 'Phone'),
              _buildTextField(specializationController, 'Specialization'),
              _buildTextField(notesController, 'Notes'),
              _buildTextField(conditionController, 'Condition'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('medical').add({
                'name': nameController.text,
                'gender': genderController.text,
                'email': emailController.text,
                'phone': phoneController.text,
                'specialization': specializationController.text,
                'notes': notesController.text,
                'condition': conditionController.text,
                'createdAt': Timestamp.now(),
              });
              Navigator.pop(context);
              _pageStarts.clear();
              await _loadTotalPages();
              _loadPage(0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Medical record added.')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: const Text(
          'Medical Records',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMedicalDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by name, email, or condition...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ..._displayedRecords.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Name', data['name']),
                    _buildInfoRow('Gender', data['gender']),
                    _buildInfoRow('Email', data['email']),
                    _buildInfoRow('Phone', data['phone']),
                    _buildInfoRow('Specialization', data['specialization']),
                    _buildInfoRow('Notes', data['notes']),
                    _buildInfoRow('Condition', data['condition']),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          label: const Text('Edit'),
                          onPressed: () => _showEditMedicalDialog(context, doc),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Delete'),
                          onPressed: () => _confirmDeleteRecord(doc.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          _buildPaginationControls(),
        ],
      ),
    );
  }
}
