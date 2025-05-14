import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:sib_expense_app/config/dio_client.dart';

class AddEditClientScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? initialClientData; // Null for Add

  const AddEditClientScreen({
    Key? key,
    required this.token,
    this.initialClientData,
  }) : super(key: key);

  bool get isEditing => initialClientData != null;

  @override
  _AddEditClientScreenState createState() => _AddEditClientScreenState();
}

class _AddEditClientScreenState extends State<AddEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final _companyNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  final Dio _dio = createDioClient();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialClientData != null) {
      _populateForm(widget.initialClientData!);
    }
  }

  void _populateForm(Map<String, dynamic> data) {
    _companyNameController.text = data['companyName'] ?? '';
    _contactPersonController.text = data['contactPerson'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    // Populate other fields if they exist (like 'active')
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitClient() async {
    if (!_formKey.currentState!.validate()) return;
    final String actionVerb = widget.isEditing ? 'updating' : 'adding';
    final String successVerb = widget.isEditing ? 'updated' : 'added';
    setState(() { _isLoading = true; _errorMessage = null; });

    // Prepare data map matching backend DTO (ClientCreateUpdateDTO)
    Map<String, dynamic> clientData = {
      'companyName': _companyNameController.text.trim(),
      'contactPerson': _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      // Add other fields as needed
    };

    try {
      Response response;
      String actionVerb = widget.isEditing ? 'updating' : 'adding';
      String successVerb = widget.isEditing ? 'updated' : 'added';

      if (widget.isEditing) {
        final clientId = widget.initialClientData!['id'];
        print('Updating client ID: $clientId with data: $clientData');
        // **VERIFY/MODIFY** PUT endpoint for clients
        response = await _dio.put('/api/clients/$clientId', data: clientData);
      } else {
        print('Adding new client with data: $clientData');
        // **VERIFY/MODIFY** POST endpoint for clients (maybe /api/admin/add-client or /api/clients)
        response = await _dio.post('/api/admin/add-client', data: clientData);
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Client $successVerb successfully!'), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true); // Signal success
      } else {
        _handleApiError(response, 'Failed to $actionVerb client');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, '$actionVerb client');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  void _handleApiError(Response? response, String defaultMessage) {
    if (!mounted) return;
    String errorMsg = defaultMessage;
    if (response?.data is Map && response!.data.containsKey('error')) { errorMsg = response.data['error']; }
    else if (response?.statusMessage != null && response!.statusMessage!.isNotEmpty) { errorMsg = response.statusMessage!; }
    else if (response?.data != null){ errorMsg = response!.data.toString();}
    setState(() { _errorMessage = '$errorMsg (Status: ${response?.statusCode ?? 'N/A'})'; });
    print('$defaultMessage: ${response?.statusCode}, Response: ${response?.data}');
  }

  void _handleGenericError(Object e, String action) {
    if (!mounted) return;
    String errorMsg = 'Error $action';
    if (e is DioException) {
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) { errorMsg = e.response?.data['error'];}
      else if (e.response != null && e.response?.data != null) { errorMsg = "Server Error (${e.response?.statusCode}): ${e.response?.data.toString().substring(0, (e.response!.data.toString().length > 100 ? 100 : e.response!.data.toString().length)) }..."; }
      else if (e.response != null) { errorMsg = 'Server Error: ${e.response?.statusCode}'; }
      else { errorMsg = 'Network Error. Please check connection.'; }
    } else { errorMsg = 'An unexpected error occurred: ${e.toString()}'; print('Non-Dio Error type: ${e.runtimeType}'); }
    setState(() { _errorMessage = errorMsg; });
    print('Error during "$action": $e');
  }
  // --- End Error Handling ---



  // --- Status Color Helper ---
  Color _getStatusColor(String? status) {
    // **MODIFY** based on your actual EquipmentStatus enum values
    switch (status?.toUpperCase()) {
      case 'ASSIGNED': return Colors.blue;
      case 'IN_STORAGE': return Colors.grey;
      case 'UNDER_MAINTENANCE': return Colors.orange;
      case 'BROKEN': return Colors.red;
      case 'DISPOSED': return Colors.black54;
      case 'NEW':
      default: return Colors.green; // Default for NEW or unknown
    }
  }
  String _formatDioExceptionMessage(DioException e) {
    switch(e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout. Please check connection.';
      case DioExceptionType.connectionError:
        var originalError = e.error;
        if (originalError is SocketException) {
          return 'Network Error: Could not connect (${originalError.osError?.message ?? 'No details'}). Check server address and network.';
        }
        return 'Network Error: Could not connect to server.';
      case DioExceptionType.cancel: return 'Request cancelled.';
      case DioExceptionType.badCertificate: return 'Invalid server certificate.';
      case DioExceptionType.badResponse: return 'Invalid response from server (${e.response?.statusCode}).';
      case DioExceptionType.unknown: default: return 'Network Error: An unknown network issue occurred.';
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.isEditing ? 'Edit Client' : 'Add New Client';
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), backgroundColor: Colors.cyan[700]),
      body: Stack(
        children: [
          Image.asset('assets/dashboard_background2.jpg', /*...*/),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _companyNameController,
                      decoration: InputDecoration(labelText: 'Company Name *', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: InputDecoration(labelText: 'Contact Person (Optional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: 'Email (Optional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70),
                      validator: (v) => v != null && v.isNotEmpty && !RegExp(r'^.+@.+\..+$').hasMatch(v) ? 'Enter a valid email' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: 'Phone (Optional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white70),
                    ),
                    // Add other fields like 'active' toggle if needed
                    SizedBox(height: 24),
                    if (_errorMessage != null) Padding(padding: const EdgeInsets.all(16.0)),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitClient,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.cyan[700], foregroundColor: Colors.white),
                      child: _isLoading ? SizedBox(/*...loading...*/) : Text(widget.isEditing ? 'Save Changes' : 'Add Client'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}