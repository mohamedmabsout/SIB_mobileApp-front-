import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // Use Dio
import 'dart:convert'; // Keep for potential error parsing
import 'package:intl/intl.dart'; // For date formatting
import 'package:sib_expense_app/config/dio_client.dart'; // Import the helper


enum LeaveType {
  PAID,
  VACATION,
  SICK_LEAVE,
  EXCEPTIONAL
}
class LeaveRequestScreen extends StatefulWidget {
  final String token;
  const LeaveRequestScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  DateTime? _endDate;
  String _reason = '';
  LeaveType? _selectedLeaveType; // Add state for selected leave type
  bool _isLoading = false;
  String? _errorMessage;

  // Use Dio instance with interceptor for automatic token attachment
  final Dio _dio = createDioClient(); // Get the configured Dio instance


  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Authorization'] = 'Bearer ${widget.token}';
        options.headers['Content-Type'] = 'application/json'; // Ensure content type
        return handler.next(options);
      },
    ));
  }


  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || _selectedLeaveType == null) {
      setState(() {
        _errorMessage = 'Please select dates and leave type.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Format dates as YYYY-MM-DD strings for the API
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String formattedStartDate = formatter.format(_startDate!);
    final String formattedEndDate = formatter.format(_endDate!);

    try {
      // **MODIFY:** Adjust endpoint if different
      // Your backend LeaveRequestController uses '/api/leave-requests/'
      final response = await _dio.post(
        // Use the endpoint confirmed working in Postman
        '/leave/request',
        // Send only the fields expected by the backend endpoint
        data: {
          'startDate': formattedStartDate,
          'endDate': formattedEndDate,
          'leaveType': _selectedLeaveType!.name, // Send enum name (e.g., "PAID", "SICK", "EXCEPTIONAL")
          // DO NOT send 'description' if the backend endpoint doesn't expect it for creation
        },
        // Dio handles JSON encoding automatically when data is a Map and Content-Type is json
        // options: Options(headers: {'Content-Type': 'application/json'}), // Usually handled by interceptor
      );

      // Backend returns 201 Created on success
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back after successful submission
      } else {
        String errorMsg = 'Failed to submit request.';
        if (response.data is Map && response.data.containsKey('error')) {
          errorMsg = response.data['error'];
        } else if (response.statusMessage != null && response.statusMessage!.isNotEmpty) {
          errorMsg = response.statusMessage!;
        }
        setState(() {
          _errorMessage = '$errorMsg (Status: ${response.statusCode})';
        });
        print('Failed to submit leave request: ${response.statusCode}');
      }
    } on DioError catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.message}';
        if (e.response != null && e.response?.data is Map) {
          _errorMessage = e.response?.data['error'] ?? 'An error occurred.';
          print('Error response data: ${e.response?.data}');
        } else if (e.response != null) {
          _errorMessage = 'Server Error: ${e.response?.statusCode}';
        }
        else {
          _errorMessage = 'Network Error: Could not connect.';
        }
      });
      print('Submit Leave DioError: $e');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('Submit Leave General Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to format dates for display
  String _formatDate(DateTime? date) {
    if (date == null) return "Select Dates";
    return DateFormat('dd/MM/yyyy').format(date); // Adjust format as needed
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Leave"),
        backgroundColor: Colors.blue[700], // Match dashboard style
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Use ListView to prevent overflow on smaller screens
            children: [
              // Leave Type Dropdown
              DropdownButtonFormField<LeaveType>(
                value: _selectedLeaveType,
                items: LeaveType.values.map((LeaveType type) {
                  return DropdownMenuItem<LeaveType>(
                    value: type,
                    child: Text(type.name), // Display enum name
                  );
                }).toList(),
                onChanged: (LeaveType? newValue) {
                  setState(() {
                    _selectedLeaveType = newValue;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Leave Type *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Please select leave type' : null,
              ),
              const SizedBox(height: 16),

              // Reason Input
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3, // Allow multi-line input for reason
                onChanged: (val) => _reason = val,
                validator: (val) => val == null || val.isEmpty ? 'Reason is required' : null,
              ),
              const SizedBox(height: 16),

              // Date Range Picker Button
              OutlinedButton.icon( // Use OutlinedButton for better styling
                icon: const Icon(Icons.calendar_today),
                label: Text(
                    _startDate == null
                        ? "Select Leave Dates *"
                        : "${_formatDate(_startDate)} - ${_formatDate(_endDate)}"),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 7)), // Allow selecting slightly in past?
                    lastDate: DateTime.now().add(const Duration(days: 365)), // One year in future
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null, // Pre-fill if dates already selected
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked.start;
                      _endDate = picked.end;
                    });
                  }
                },
              ),
              if (_startDate == null || _endDate == null) // Show validation hint if dates not picked
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Please select leave dates',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),

              // Error Message Display
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 16)
                ),
                onPressed: _isLoading ? null : _submitRequest,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}