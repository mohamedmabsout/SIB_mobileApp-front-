import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/screens/add_edit_assignment_screen.dart'; // For Edit

// Define enum or import
enum AssignmentStatus { PENDING, ACTIVE, BLOCKED, AWAITING_VALIDATION, COMPLETED }

class AssignmentDetailScreen extends StatefulWidget {
  final String token;
  final int assignmentId;

  const AssignmentDetailScreen({
    Key? key,
    required this.token,
    required this.assignmentId,
  }) : super(key: key);

  @override
  _AssignmentDetailScreenState createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  Map<String, dynamic>? _assignmentDetails;
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';
  int? _userId; // Store logged-in user ID for potential checks

  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fetchRoleAndData();
  }

  Future<void> _fetchRoleAndData() async {
    // ... (Fetch role and userId) ...
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userId = prefs.getInt('user_id');
    if (!mounted) return;
    if (_userRole.isEmpty || _userId == null) { setState(() { _isLoading = false; _errorMessage = "User info missing."; }); return; }
    await _fetchAssignmentDetails();
  }

  Future<void> _fetchAssignmentDetails() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    // **VERIFY/MODIFY** Endpoint
    final String endpoint = '/api/assignments/${widget.assignmentId}';
    try {
      print('Fetching assignment details from: $endpoint');
      final response = await _dio.get(endpoint);
      if (!mounted) return;
      if (response.statusCode == 200 && response.data is Map) {
        setState(() { _assignmentDetails = response.data as Map<String, dynamic>; });
      } else { _handleApiError(response, 'Failed to load assignment'); }
    } catch (e) { if (!mounted) return; _handleGenericError(e, 'fetching assignment');
    } finally { if (mounted) { setState(() { _isLoading = false; }); } }
  }

  // --- Delete Logic ---
  Future<void> _deleteAssignment() async {
    bool confirmDelete = await showDialog<bool>(
      context: context, // Pass context
      builder: (BuildContext dialogContext) { // Provide builder
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this assignement?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
    if (!confirmDelete || !mounted) return;
    setState(() { _isLoading = true; });
    try {
      // **VERIFY/MODIFY** Endpoint
      final response = await _dio.delete('/api/assignments/${widget.assignmentId}');
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment Deleted'), backgroundColor: Colors.grey),
        );
        Navigator.pop(context, true); // Go back, signal refresh
      } else { _handleApiError(response, 'Failed to delete'); }
    } catch (e) { if (!mounted) return; _handleGenericError(e, 'deleting');
    } finally { if (mounted) { setState(() { _isLoading = false; }); } }
  }

  // --- Error Handling & Helpers ---
  // --- Error Handling Helpers ---
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
    } else { errorMsg = 'An unexpected error occurred.'; print('Non-Dio Error type: ${e.runtimeType}'); }
    setState(() { _errorMessage = errorMsg; });
    print('Error during "$action": $e');
  }
  // --- End Error Handling ---

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
  String _formatDateDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      // Create a formatter that expects the backend format (YYYY-MM-DD)
      final backendFormat = DateFormat('yyyy-MM-dd');
      final dateTime = backendFormat.parse(dateString);
      // Format it for display
      return DateFormat('dd MMM yyyy').format(dateTime); // Example: 23 Apr 2025
    } catch (e) {
      print("Error parsing date '$dateString': $e");
      return "Invalid Date";
    }
  }
  Color _getAssignmentStatusColor(String? status) {
    // **MODIFY** based on your actual AssignmentStatus enum values
    switch (status?.toUpperCase()) {
      case 'ACTIVE': return Colors.blue;
      case 'COMPLETED': return Colors.green;
      case 'PENDING': return Colors.grey;
      case 'BLOCKED': return Colors.red;
      case 'AWAITING_VALIDATION': return Colors.orange;
      default: return Colors.grey.shade400;
    }
  }
  Widget _buildDetailRow(IconData icon, String label, String? value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // Reduced padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600), // Bolder label
          ),
          Expanded(
            child: Text(value ?? 'N/A', style: TextStyle(color: valueColor ?? Colors.grey[800])),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final bool canEditDelete = (_userRole == 'ADMIN' || _userRole == 'MANAGER');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : 'Assignment Details'),
        backgroundColor: Colors.purple,
        actions: [
          if (canEditDelete && !_isLoading && _assignmentDetails != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: "Edit Assignment",
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => AddEditAssignmentScreen(
                      token: widget.token,
                      initialAssignmentData: _assignmentDetails,
                    )
                )).then((success) { if(success == true) _fetchAssignmentDetails(); });
              },
            ),
          if (canEditDelete && !_isLoading && _assignmentDetails != null) // Restrict delete?
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Delete Assignment",
              onPressed: _deleteAssignment,
            ),
        ],
      ),
      body: Stack( // Add Stack for background
        children: [
          SafeArea( // Keep SafeArea
            child: RefreshIndicator(
              onRefresh: _fetchAssignmentDetails,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(/* Error Message */)
                  : _assignmentDetails == null
                  ? const Center(child: Text('Assignment data not found.'))
                  : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Assignment Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('Project: ${_assignmentDetails!['projectName'] ?? 'N/A'}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
                      Chip( label: Text(_assignmentDetails!['status'] ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: _getAssignmentStatusColor(_assignmentDetails!['status'] as String?)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 16.0),
                    child: Text('User: ${_assignmentDetails!['username'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                  ),
                  const Divider(),

                  // --- Details Card ---
                  Card(
                    elevation: 2, margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow(Icons.description_outlined, "Assignment Desc.", _assignmentDetails!['description'] as String?),
                          _buildDetailRow(Icons.calendar_today_outlined, "Start Date", _formatDateDisplay(_assignmentDetails!['startDate'] as String?)),
                          _buildDetailRow(Icons.event_available_outlined, "End Date", _formatDateDisplay(_assignmentDetails!['endDate'] as String?)),
                          // Display other relevant assignment details if available
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}