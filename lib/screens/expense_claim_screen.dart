import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:sib_expense_app/config/dio_client.dart'; // Assuming you use the centralized client
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

class ExpenseClaimScreen extends StatefulWidget {
  final String token;

  ExpenseClaimScreen({required this.token});

  @override
  _ExpenseClaimScreenState createState() => _ExpenseClaimScreenState();
}

class _ExpenseClaimScreenState extends State<ExpenseClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _montantController = TextEditingController();
  File? _selectedFile;
  bool _isSubmitting = false;
  String? _selectedCategory;
  String? _errorMessage;
  final List<String> _categories = ['FOOD', 'OTHER', 'SUPPLIES', 'TRAVEL'];
  final String _defaultExpenseType = 'SUBMITTED';
  final String _submissionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Use Dio instance with interceptor for automatic token attachment
  final Dio _dio = createDioClient(); // Get the configured Dio instance

  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Authorization'] = 'Bearer ${widget.token}';
        options.headers['Content-Type'] = 'multipart/form-data'; // Ensure content type
        return handler.next(options);
      },
    ));
  }

  Future<void> pickFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'any',
      extensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() {
        _selectedFile = File(file.path);
      });
    }
  }

  Future<void> _submitExpenseClaim() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null || _selectedCategory == null) {
      setState(() {
        _errorMessage = 'Please fill all fields, select a file, and choose a category.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      String fileName = _selectedFile!.path.split('/').last;
      FormData formData = FormData.fromMap({
        'description': _descriptionController.text.trim(),
        'amount': _montantController.text.trim(),
        'category': _selectedCategory!,
        'date': _submissionDate,
        'justificatif': await MultipartFile.fromFile(
          _selectedFile!.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/claims', // Use the endpoint confirmed working in Postman
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense submitted successfully!'), backgroundColor: Colors.green),
        );
        _formKey.currentState?.reset();
        _descriptionController.clear();
        _montantController.clear();
        setState(() {
          _selectedFile = null;
          _selectedCategory = null;
        });
      } else {
        String errorMsg = 'Failed to submit expense claim.';
        if (response.data is Map && response.data.containsKey('error')) {
          errorMsg = response.data['error'];
        } else if (response.statusMessage != null && response.statusMessage!.isNotEmpty) {
          errorMsg = response.statusMessage!;
        }
        setState(() {
          _errorMessage = '$errorMsg (Status: ${response.statusCode})';
        });
        print('Failed to submit expense claim: ${response.statusCode}');
      }
    } on DioError catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.message}';
        if (e.response != null && e.response?.data is Map) {
          _errorMessage = e.response?.data['error'] ?? 'An error occurred.';
          print('Error response data: ${e.response?.data}');
        } else if (e.response != null) {
          _errorMessage = 'Server Error: ${e.response?.statusCode}';
        } else {
          _errorMessage = 'Network Error: Could not connect.';
        }
      });
      print('Submit Expense DioError: $e');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('Submit Expense General Error: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Claim'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montantController,
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? 'Amount is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCategory,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  validator: (value) => value == null ? 'Category is required' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choose File'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 8),
                  Text('Selected: ${_selectedFile!.path.split('/').last}'),
                ],
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isSubmitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _submitExpenseClaim,
                  child: const Text('Submit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
