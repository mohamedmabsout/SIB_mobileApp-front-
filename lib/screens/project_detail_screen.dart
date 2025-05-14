import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/screens/add_edit_project_screen.dart'; // For Edit navigation

// Define ProjectStatus if not imported from model
enum ProjectStatus { PLANNING, ACTIVE, ON_HOLD, COMPLETED }

class ProjectDetailScreen extends StatefulWidget {
  final String token;
  final int projectId;

  const ProjectDetailScreen({
    Key? key,
    required this.token,
    required this.projectId,
  }) : super(key: key);

  @override
  _ProjectDetailScreenState createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Map<String, dynamic>? _projectDetails;
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = ''; // Needed for conditional actions

  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy'); // Example format

  @override
  void initState() {
    super.initState();
    _fetchRoleAndData();
  }

  Future<void> _fetchRoleAndData() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    if (!mounted) return;
    if (_userRole.isEmpty) {
      setState(() { _isLoading = false; _errorMessage = "Role info missing."; });
      // Consider logging out or popping
      return;
    }
    await _fetchProjectDetails();
  }


  Future<void> _fetchProjectDetails() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // **VERIFY/MODIFY** Endpoint path
    final String endpoint = '/api/projects/${widget.projectId}';

    try {
      print('Fetching project details from: $endpoint');
      final response = await _dio.get(endpoint);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data is Map) {
        setState(() {
          _projectDetails = response.data as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        _handleApiError(response, 'Failed to load project details');
        setState(() { _isLoading = false; }); // Stop loading on error
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'fetching project details');
      setState(() { _isLoading = false; }); // Stop loading on error
    }
  }

  // --- Delete Project Logic ---
  Future<void> _deleteProject() async {
    bool confirmDelete = await  showDialog<bool>( // Add type argument <bool>
      context: context, // Pass context
      builder: (BuildContext dialogContext) { // Provide builder
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this project? Related tasks and assignments might be affected.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false), // Use dialogContext
            ),
            TextButton(
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true), // Use dialogContext
            ),
          ],
        );
      },
    ) ?? false;
    if (!confirmDelete || !mounted) return;

    setState(() { _isLoading = true; }); // Show loading during delete

    try {
      // **VERIFY/MODIFY** Endpoint path
      final response = await _dio.delete('/api/projects/${widget.projectId}');
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project Deleted'), backgroundColor: Colors.grey),
        );
        // Pop back to the list screen, potentially passing 'true' to signal refresh needed
        Navigator.pop(context, true);
      } else {
        _handleApiError(response, 'Failed to delete project');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'deleting project');
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
  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value ?? 'N/A', style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  // --- Get Status Color ---

  // Correct default case in _getStatusColor
  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE': return Colors.green;
      case 'PLANNING': return Colors.blue;
      case 'ON_HOLD': return Colors.orange;
      case 'COMPLETED': return Colors.grey;
      default: return Colors.grey.shade400; // Explicit default return
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEditDelete = (_userRole == 'ADMIN' || _userRole == 'MANAGER'); // Determine permissions

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : 'Project Details'),
        backgroundColor: Colors.indigo,
        actions: [
          if (canEditDelete && !_isLoading && _projectDetails != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: "Edit Project",
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => AddEditProjectScreen(
                      token: widget.token,
                      initialProjectData: _projectDetails, // Pass current data
                    )
                )).then((success) { // Refresh details after edit
                  if(success == true) _fetchProjectDetails();
                });
              },
            ),
          if (canEditDelete && !_isLoading && _projectDetails != null) // Typically only ADMIN?
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Delete Project",
              onPressed: _deleteProject,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProjectDetails,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center)))
            : _projectDetails == null
            ? const Center(child: Text('Project data not found.'))
            : ListView( // Use ListView for scrollability
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Project Header ---
            Text(
              _projectDetails!['projectName'] ?? 'Unknown Project',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Chip(
              label: Text(_projectDetails!['status'] ?? 'N/A', style: TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: _getStatusColor(_projectDetails!['status'] as String?),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            if (_projectDetails!['projectCode'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Code: ${_projectDetails!['projectCode']}', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 16),
            const Divider(),

            // --- Core Details Card ---
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.description_outlined, "Description", _projectDetails!['description'] as String?),
                    _buildDetailRow(Icons.calendar_today_outlined, "Start Date", _formatDateDisplay(_projectDetails!['startDate'] as String?)),
                    _buildDetailRow(Icons.event_available_outlined, "End Date", _formatDateDisplay(_projectDetails!['endDate'] as String?)),
                    _buildDetailRow(Icons.attach_money_outlined, "Budget", (_projectDetails!['budget'] as num?)?.toStringAsFixed(2) ?? 'N/A'),
                  ],
                ),
              ),
            ),

            // --- Client Details Card ---
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Client Information", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.business_outlined, "Company", _projectDetails!['clientCompanyName'] ?? 'N/A'),

                  ],
                ),
              ),
            ),

            // TODO: Add Sections for related Tasks / Assignments / Documents if needed
            // This might involve separate API calls or expanding the /api/projects/{id} response


          ],
        ),
      ),
    );
  }
}