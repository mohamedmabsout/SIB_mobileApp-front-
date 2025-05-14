import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/screens/add_task_screen.dart'; // For Edit

// Define enums if not imported
enum TaskStatus { OPEN, IN_PROGRESS, COMPLETED, BLOCKED }
enum Priority { LOW, MEDIUM, HIGH }

class TaskDetailScreen extends StatefulWidget {
  final String token;
  final int taskId;

  const TaskDetailScreen({
    Key? key,
    required this.token,
    required this.taskId,
  }) : super(key: key);

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _taskDetails;
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';
  int? _userId;

  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fetchRoleAndData();
  }

  Future<void> _fetchRoleAndData() async {
    // ... (Same implementation as in ProjectDetailScreen) ...
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userId = prefs.getInt('user_id');
    if (!mounted) return;
    if (_userRole.isEmpty || _userId == null) {
      setState(() { _isLoading = false; _errorMessage = "User info missing."; }); return;
    }
    await _fetchTaskDetails();
  }

  Future<void> _fetchTaskDetails() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // **VERIFY/MODIFY** Endpoint path
    final String endpoint = '/api/tasks/${widget.taskId}';

    try {
      print('Fetching task details from: $endpoint');
      final response = await _dio.get(endpoint);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is Map) {
        setState(() {
          _taskDetails = response.data as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        _handleApiError(response, 'Failed to load task details');
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching task details');
      setState(() { _isLoading = false; });
    }
  }

  // --- Delete Task Logic ---
  Future<void> _deleteTask() async {
    bool confirmDelete = await showDialog(
      context: context, // Pass context
      builder: (BuildContext dialogContext) { // Provide builder
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this task?'),
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
    if (!confirmDelete || !mounted) return;

    setState(() { _isLoading = true; });

    try {
      // **VERIFY/MODIFY** Endpoint path
      final response = await _dio.delete('/api/tasks/${widget.taskId}');
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task Deleted'), backgroundColor: Colors.grey),
        );
        Navigator.pop(context, true); // Pop back and signal refresh
      } else {
        _handleApiError(response, 'Failed to delete task');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'deleting task');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Date Formatter ---
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

  // --- Error Handling Helpers (Ensure these are present) ---
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
    if (e is DioException) { // USE DioException
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) { errorMsg = e.response?.data['error'];}
      else if (e.response != null && e.response?.data != null) { errorMsg = "Server Error (${e.response?.statusCode}): ${e.response?.data.toString().substring(0, (e.response!.data.toString().length > 100 ? 100 : e.response!.data.toString().length)) }..."; }
      else if (e.response != null) { errorMsg = 'Server Error: ${e.response?.statusCode}'; }
      else { // Network errors, timeouts, etc.
        errorMsg = _formatDioExceptionMessage(e); // Use helper below
      }
    } else { errorMsg = 'An unexpected error occurred: ${e.toString()}'; print('Non-Dio Error type: ${e.runtimeType}'); }
    setState(() { _errorMessage = errorMsg; });
    print('Error during "$action": $e');
  }

  // Helper to format DioException network/timeout errors
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
  // --- Helper to build detail rows ---
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

  // --- Get Status/Priority Color/Icon Helpers ---
  Color _getTaskStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'OPEN': return Colors.blue;
      case 'IN_PROGRESS': return Colors.orange;
      case 'COMPLETED': return Colors.green;
      case 'BLOCKED': return Colors.red;
      default: return Colors.grey; // Explicit default return
    }
  }
  IconData _getPriorityIcon(String? priority) {
    switch (priority?.toUpperCase()) {
      case 'HIGH': return Icons.priority_high_rounded;
      case 'MEDIUM': return Icons.remove_rounded;
      case 'LOW': return Icons.low_priority_rounded;
      default: return Icons.horizontal_rule_rounded; // Explicit default return
    }
  }
  Color _getPriorityColor(String? priority) {
    switch (priority?.toUpperCase()) {
      case 'HIGH': return Colors.red.shade700;
      case 'MEDIUM': return Colors.orange.shade800;
      case 'LOW': return Colors.green.shade700;
      default: return Colors.grey.shade600;
    }
  }


  @override
  Widget build(BuildContext context) {
    // Determine permissions based on role and potentially if user is assignee
    bool canEdit = (_userRole == 'ADMIN' || _userRole == 'MANAGER'); // Simplistic - adjust if assignee can edit status etc.
    bool canDelete = (_userRole == 'ADMIN'); // Example: only admin can delete

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading Task...' : 'Task Details'),
        backgroundColor: Colors.orange,
        actions: [
          if (canEdit && !_isLoading && _taskDetails != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: "Edit Task",
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => AddEditTaskScreen(
                      token: widget.token,
                      initialTaskData: _taskDetails, // Pass current data
                    )
                )).then((success) { if(success == true) _fetchTaskDetails(); }); // Refresh on return
              },
            ),
          if (canDelete && !_isLoading && _taskDetails != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Delete Task",
              onPressed: _deleteTask,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTaskDetails,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(/* Error Message */)
            : _taskDetails == null
            ? const Center(child: Text('Task data not found.'))
            : ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Task Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _taskDetails!['taskName'] ?? 'Unnamed Task',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(_taskDetails!['status'] ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: _getTaskStatusColor(_taskDetails!['status'] as String?),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // --- Task Details Card ---
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.description_outlined, "Description", _taskDetails!['description'] as String?),
                    _buildDetailRow(Icons.calendar_today_outlined, "Due Date", _formatDateDisplay(_taskDetails!['dueDate'] as String?)),
                    _buildDetailRow(
                      _getPriorityIcon(_taskDetails!['priority'] as String?),
                      "Priority",
                      _taskDetails!['priority'] as String?,
                      valueColor: _getPriorityColor(_taskDetails!['priority'] as String?),
                    ),
                    const Divider(height: 15),
                    _buildDetailRow(Icons.assignment_ind_outlined, "Assigned To", _taskDetails!['assignedUsername'] ?? 'N/A'), // Use assignedUsername
                    _buildDetailRow(Icons.folder_outlined, "Project", _taskDetails!['projectName'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            // Potentially add related comments or subtasks section here
          ],
        ),
      ),
    );
  }
}